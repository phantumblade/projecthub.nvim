-- Sorveglianza in tempo reale delle stelle ricevute dai tuoi repository GitHub.
--
-- GitHub non offre un canale push per le stelle senza webhook e un server in
-- ascolto, quindi qui si fa polling: una sola chiamata `gh api` per account
-- restituisce tutti i repo con il rispettivo conteggio, che viene confrontato
-- con l'istantanea salvata su disco. Quando un conteggio sale, una seconda
-- chiamata recupera l'ultima pagina degli stargazer per sapere *chi* è stato.
--
-- Tutto passa da jobstart: nessuna chiamata blocca l'interfaccia, mai.

local config = require("projecthub.config")
local i18n = require("projecthub.i18n")
local sound = require("projecthub.sound")

local M = {}

local uv = vim.uv or vim.loop
local DATA_DIR = vim.fn.stdpath("data") .. "/projecthub"
local SNAPSHOT_FILE = DATA_DIR .. "/stars.json"

local ICON_STAR = "\u{f005}" -- nf-fa-star
local ICON_TROPHY = "\u{f091}" -- nf-fa-trophy

local ns = vim.api.nvim_create_namespace("projecthub_stars")

local timer = nil
local polling = false -- una sola interrogazione in volo per volta
local snapshot = nil -- { ["owner/repo"] = numero_stelle }
local snapshot_loaded = false -- l'istantanea su disco è già stata letta?
local last_check = nil -- timestamp dell'ultimo controllo riuscito
local toasts = {} -- toast a schermo, dal più vecchio al più recente

--------------------------------------------------------------------------- dati

local function opts()
  return (config.options and config.options.stars) or {}
end

local function load_snapshot()
  if vim.fn.filereadable(SNAPSHOT_FILE) == 0 then return nil end
  local ok, lines = pcall(vim.fn.readfile, SNAPSHOT_FILE)
  if not ok or not lines or #lines == 0 then return nil end
  local ok_json, data = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok_json or type(data) ~= "table" then return nil end
  return data
end

local function save_snapshot()
  if type(snapshot) ~= "table" then return end
  pcall(vim.fn.mkdir, DATA_DIR, "p")
  pcall(vim.fn.writefile, { vim.json.encode(snapshot) }, SNAPSHOT_FILE)
  snapshot_loaded = true
end

--- Carica l'istantanea da disco una sola volta per sessione. Serve a
--- distinguere il vero primo avvio (nessun file su disco) da una semplice
--- chiamata isolata a :PHStarsCheck, che altrimenti riscriverebbe la linea
--- di base e non notificherebbe mai nulla.
local function ensure_snapshot()
  if not snapshot_loaded then
    snapshot = load_snapshot()
    snapshot_loaded = true
  end
  return snapshot
end

--------------------------------------------------------------------------- toast

local function set_toast_hl()
  local accent = opts().color or "#E3B341"
  vim.api.nvim_set_hl(0, "ProjectsStarBorder", { fg = accent })
  vim.api.nvim_set_hl(0, "ProjectsStarTitle", { fg = accent, bold = true })
  vim.api.nvim_set_hl(0, "ProjectsStarRepo", { fg = "#C8D3F5", bold = true })
  vim.api.nvim_set_hl(0, "ProjectsStarCount", { fg = accent, bold = true })
  vim.api.nvim_set_hl(0, "ProjectsStarWho", { fg = "#7DCFFF" })
  vim.api.nvim_set_hl(0, "ProjectsStarMeta", { fg = "#545C7E" })
end

--- Ridispone verticalmente i toast rimasti, così la pila non lascia buchi
--- quando quello in mezzo scade prima degli altri.
local function reflow()
  -- Tutti i riquadri visibili adottano la larghezza del più largo, così una
  -- pila di notifiche resta una colonna ordinata invece di una scaletta.
  local w = 0
  for _, t in ipairs(toasts) do
    if vim.api.nvim_win_is_valid(t.win) then w = math.max(w, t.width) end
  end

  local row = 1
  for _, t in ipairs(toasts) do
    if vim.api.nvim_win_is_valid(t.win) then
      pcall(vim.api.nvim_win_set_config, t.win, {
        relative = "editor",
        row = row,
        col = math.max(0, vim.o.columns - w - 3),
        width = w,
      })
      row = row + t.height + 2
    end
  end
end

local function dismiss(t)
  if t.timer then
    pcall(function()
      t.timer:stop()
      t.timer:close()
    end)
    t.timer = nil
  end
  if t.win and vim.api.nvim_win_is_valid(t.win) then
    pcall(vim.api.nvim_win_close, t.win, true)
  end
  if t.buf and vim.api.nvim_buf_is_valid(t.buf) then
    pcall(vim.api.nvim_buf_delete, t.buf, { force = true })
  end
  for i, other in ipairs(toasts) do
    if other == t then
      table.remove(toasts, i)
      break
    end
  end
  reflow()
end

--- Chiude tutti i toast attualmente a schermo.
function M.dismiss_all()
  for i = #toasts, 1, -1 do
    dismiss(toasts[i])
  end
end

--- Mostra il riquadro di notifica per una stella appena ricevuta.
--- @param info table { repo = "owner/nome", total = numero, who = login|nil, delta = numero }
function M.toast(info)
  set_toast_hl()

  local o = opts()
  local short = tostring(info.repo or "?"):match("([^/]+)$") or tostring(info.repo)
  local title = o.title or i18n.t("star_toast_title")
  local delta = info.delta or 1
  if delta > 1 then
    title = string.format("%s  +%d", title, delta)
  end

  -- Riga meta: "★ 12 · yutkat", oppure il solo totale se l'autore è ignoto.
  local count_txt = ICON_STAR .. " " .. tostring(info.total or "?")
  local who_txt = info.who and ("  ·  " .. info.who) or ""

  local rows = {
    { { ICON_TROPHY .. "  ", "ProjectsStarTitle" }, { title, "ProjectsStarTitle" } },
    { { short, "ProjectsStarRepo" } },
    { { count_txt, "ProjectsStarCount" }, { who_txt, "ProjectsStarWho" } },
  }

  local dw = vim.fn.strdisplaywidth
  local inner = 0
  for _, chunks in ipairs(rows) do
    local w = 0
    for _, c in ipairs(chunks) do w = w + dw(c[1]) end
    inner = math.max(inner, w)
  end
  local width = math.min(math.max(inner + 6, 30), math.max(20, vim.o.columns - 6))

  -- Le righe vengono composte per intero *prima* della scrittura: un secondo
  -- nvim_buf_set_lines dopo gli extmark li cancellerebbe tutti.
  -- Una riga vuota sopra e sotto: il riquadro respira e il titolo non
  -- resta incollato al bordo arrotondato.
  local lines, marks = { "" }, {}
  for _, chunks in ipairs(rows) do
    local text = "   "
    local row_marks = {}
    for _, c in ipairs(chunks) do
      local from = #text
      text = text .. c[1]
      row_marks[#row_marks + 1] = { from, #text, c[2] }
    end
    lines[#lines + 1] = text
    marks[#lines] = row_marks
  end
  lines[#lines + 1] = ""

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  for lnum, row_marks in pairs(marks) do
    for _, m in ipairs(row_marks) do
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, lnum - 1, m[1], {
        end_col = m[2],
        hl_group = m[3],
      })
    end
  end
  vim.bo[buf].modifiable = false

  local height = #lines
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    row = 1,
    col = math.max(0, vim.o.columns - width - 3),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    focusable = false,
    noautocmd = true,
    zindex = 200, -- sopra la dashboard, che si ferma a 70
  })
  vim.wo[win].winhighlight = "Normal:NormalFloat,FloatBorder:ProjectsStarBorder"
  vim.wo[win].wrap = false

  local t = { win = win, buf = buf, width = width, height = height }
  toasts[#toasts + 1] = t
  reflow()

  local duration = tonumber(o.duration) or 8000
  t.timer = uv.new_timer()
  t.timer:start(duration, 0, vim.schedule_wrap(function() dismiss(t) end))

  if o.sound ~= false then
    sound.play(o.sound or "achievement")
  end

  return t
end

------------------------------------------------------------------------ polling

--- Esegue `gh` in background e consegna le righe di stdout alla callback.
local function gh(args, cb)
  local out = {}
  local cmd = { "gh" }
  vim.list_extend(cmd, args)
  local ok, job = pcall(vim.fn.jobstart, cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then out = data end
    end,
    on_stderr = function() end,
    on_exit = function(_, code)
      vim.schedule(function() cb(code == 0 and out or nil, code) end)
    end,
  })
  if not ok or not job or job <= 0 then
    vim.schedule(function() cb(nil, -1) end)
  end
end

--- Recupera il login di chi ha messo la stella più di recente su un repo.
--- Gli stargazer arrivano in ordine cronologico crescente, quindi il più
--- recente è l'ultimo elemento dell'ultima pagina.
local function newest_stargazer(full_name, total, cb)
  local page = math.max(1, math.ceil((tonumber(total) or 1) / 100))
  gh({
    "api",
    string.format("repos/%s/stargazers?per_page=100&page=%d", full_name, page),
    "-H", "Accept: application/vnd.github.star+json",
    "--jq", ".[] | .user.login",
  }, function(lines)
    if not lines then return cb(nil) end
    local last = nil
    for _, l in ipairs(lines) do
      l = vim.trim(l)
      if l ~= "" then last = l end
    end
    cb(last)
  end)
end

--- Elenco degli account da sorvegliare: `me.owners` se configurato,
--- altrimenti l'account con cui `gh` è autenticato.
local function resolve_owners(cb)
  local o = opts()
  if type(o.owners) == "table" and #o.owners > 0 then
    return cb(o.owners)
  end
  local me = config.options.me
  if me and type(me.owners) == "table" and #me.owners > 0 then
    return cb(me.owners)
  end
  gh({ "api", "user", "--jq", ".login" }, function(lines)
    local login = lines and lines[1] and vim.trim(lines[1]) or ""
    cb(login ~= "" and { login } or {})
  end)
end

--- Interroga GitHub, confronta con l'istantanea e notifica le differenze.
--- @param on_done? fun(gained: table, first_run: boolean)
function M.check(on_done)
  if polling then
    if on_done then on_done({}, false) end
    return
  end
  polling = true

  local function finish(gained, first_run)
    polling = false
    if on_done then on_done(gained or {}, first_run == true) end
  end

  ensure_snapshot()

  resolve_owners(function(owners)
    if #owners == 0 then
      return finish({}, false)
    end

    local pending = #owners
    local counts = {}

    for _, owner in ipairs(owners) do
      gh({
        "api", "--paginate",
        string.format("users/%s/repos?per_page=100&type=owner", owner),
        "--jq", '.[] | "\\(.full_name)\t\\(.stargazers_count)"',
      }, function(lines)
        if lines then
          for _, l in ipairs(lines) do
            local name, n = l:match("^(%S+)\t(%d+)$")
            if name then counts[name] = tonumber(n) end
          end
        end

        pending = pending - 1
        if pending > 0 then return end

        if next(counts) == nil then
          return finish({}, false)
        end

        -- Primo avvio: si registra solo la linea di base, senza notificare
        -- le stelle già ricevute in passato.
        local first_run = (snapshot == nil)
        if first_run then
          snapshot = counts
          last_check = os.time()
          save_snapshot()
          return finish({}, true)
        end

        local gained = {}
        for name, n in pairs(counts) do
          local before = snapshot[name]
          if before ~= nil and n > before then
            gained[#gained + 1] = { repo = name, total = n, delta = n - before }
          end
        end

        snapshot = counts
        last_check = os.time()
        save_snapshot()

        if #gained == 0 then
          return finish({}, false)
        end

        -- Un toast per repo, distanziati così la pila non appare di colpo
        -- e il suono non si sovrappone a se stesso.
        local shown = 0
        for i, g in ipairs(gained) do
          newest_stargazer(g.repo, g.total, function(who)
            g.who = who
            vim.defer_fn(function()
              M.toast(g)
              shown = shown + 1
              if shown == #gained then finish(gained, false) end
            end, (i - 1) * 700)
          end)
        end
      end)
    end
  end)
end

------------------------------------------------------------------------- ciclo

function M.is_running()
  return timer ~= nil
end

--- Avvia la sorveglianza periodica.
function M.start(silent)
  if timer then return true end
  if vim.fn.executable("gh") ~= 1 then
    if not silent then
      vim.notify(i18n.t("star_no_gh"), vim.log.levels.WARN, { title = "ProjectHub" })
    end
    return false
  end

  ensure_snapshot()

  local interval = math.max(30, tonumber(opts().interval) or 120) * 1000
  timer = uv.new_timer()
  timer:start(2000, interval, vim.schedule_wrap(function()
    M.check()
  end))

  if not silent then
    vim.notify(
      string.format(i18n.t("star_watch_started"), math.floor(interval / 1000)),
      vim.log.levels.INFO,
      { title = "ProjectHub", icon = ICON_STAR .. " " }
    )
  end
  return true
end

--- Ferma la sorveglianza periodica.
function M.stop(silent)
  if timer then
    pcall(function()
      timer:stop()
      timer:close()
    end)
    timer = nil
  end
  if not silent then
    vim.notify(i18n.t("star_watch_stopped"), vim.log.levels.WARN, { title = "ProjectHub" })
  end
  return false
end

function M.toggle()
  if timer then
    M.stop()
    return false
  end
  return M.start()
end

--- Riepilogo leggibile dello stato corrente della sorveglianza.
function M.status()
  ensure_snapshot()
  local tracked, total = 0, 0
  for _, n in pairs(snapshot or {}) do
    tracked = tracked + 1
    total = total + n
  end
  return {
    running = timer ~= nil,
    interval = math.max(30, tonumber(opts().interval) or 120),
    tracked = tracked,
    total = total,
    last_check = last_check,
    snapshot = snapshot,
  }
end

--------------------------------------------------------------------------- test

--- Toast finto: verifica colori, testo e suono senza toccare la rete.
function M.demo()
  set_toast_hl()
  M.toast({
    repo = "phantumblade/projecthub.nvim",
    total = math.random(2, 42),
    who = "yutkat",
    delta = 1,
  })
end

--- Prova dal vivo *reale*: arretra di uno il conteggio salvato per un repo,
--- così il controllo successivo vede un incremento autentico e percorre
--- l'intera catena — chiamata API, confronto, ricerca dello stargazer,
--- notifica, suono — usando dati veri, senza bisogno di un secondo account.
--- @param repo? string "owner/nome"; se omesso sceglie il repo con più stelle
function M.rehearse(repo)
  local function run()
    local target, best = repo, -1
    if not target then
      for name, n in pairs(snapshot or {}) do
        if n > best then target, best = name, n end
      end
    end
    if not target or snapshot == nil or snapshot[target] == nil then
      vim.notify(i18n.t("star_rehearse_no_repo"), vim.log.levels.WARN, { title = "ProjectHub" })
      return
    end
    if (snapshot[target] or 0) < 1 then
      vim.notify(
        string.format(i18n.t("star_rehearse_no_stars"), target),
        vim.log.levels.WARN,
        { title = "ProjectHub" }
      )
      return
    end

    snapshot[target] = snapshot[target] - 1
    save_snapshot()
    vim.notify(
      string.format(i18n.t("star_rehearse_armed"), target),
      vim.log.levels.INFO,
      { title = "ProjectHub", icon = ICON_STAR .. " " }
    )
    M.check(function(gained)
      if #gained == 0 then
        vim.notify(i18n.t("star_rehearse_failed"), vim.log.levels.ERROR, { title = "ProjectHub" })
      end
    end)
  end

  ensure_snapshot()
  if snapshot == nil then
    -- Nessuna linea di base ancora: la si costruisce e poi si prova.
    M.check(function() vim.schedule(run) end)
  else
    run()
  end
end

return M
