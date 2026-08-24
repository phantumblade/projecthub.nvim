-- Sorveglianza delle stelle ricevute dai tuoi repository GitHub.
--
-- GitHub non offre un canale push per le stelle senza webhook e un server in
-- ascolto, quindi qui si fa polling: una sola chiamata `gh api` per account
-- restituisce tutti i repo con il rispettivo conteggio, che viene confrontato
-- con l'istantanea salvata su disco. Quando un conteggio sale, una seconda
-- chiamata recupera l'ultima pagina degli stargazer per sapere *chi* è stato.
--
-- Le notifiche passano dal modulo condiviso projecthub.notify, lo stesso di
-- tutto il resto del plugin, col tema "achievement".
--
-- Tutto passa da jobstart: nessuna chiamata blocca l'interfaccia, mai.

local config = require("projecthub.config")
local i18n = require("projecthub.i18n")
local notify = require("projecthub.notify")

local M = {}

local uv = vim.uv or vim.loop
local DATA_DIR = vim.fn.stdpath("data") .. "/projecthub"
local SNAPSHOT_FILE = DATA_DIR .. "/stars.json"
local ELIGIBLE_FILE = DATA_DIR .. "/stars_scope.json"
local ELIGIBLE_TTL = 24 * 60 * 60 -- quanto resta valida l'idoneità di un repo

local timer = nil
local polling = false -- una sola interrogazione in volo per volta
local snapshot = nil -- { ["owner/repo"] = numero_stelle }
local snapshot_loaded = false
local eligible = nil -- { ["owner/repo"] = { ok = bool, at = timestamp } }
local last_check = nil
local me_login = nil -- account con cui `gh` è autenticato

--------------------------------------------------------------------------- dati

local function opts()
  return (config.options and config.options.stars) or {}
end

local function read_json(file)
  if vim.fn.filereadable(file) == 0 then return nil end
  local ok, lines = pcall(vim.fn.readfile, file)
  if not ok or not lines or #lines == 0 then return nil end
  local ok_json, data = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok_json or type(data) ~= "table" then return nil end
  return data
end

local function write_json(file, data)
  pcall(vim.fn.mkdir, DATA_DIR, "p")
  pcall(vim.fn.writefile, { vim.json.encode(data) }, file)
end

--- Carica l'istantanea da disco una sola volta per sessione. Serve a
--- distinguere il vero primo avvio (nessun file su disco) da una semplice
--- chiamata isolata a :PHStarsCheck, che altrimenti riscriverebbe la linea
--- di base e non notificherebbe mai nulla.
local function ensure_snapshot()
  if not snapshot_loaded then
    snapshot = read_json(SNAPSHOT_FILE)
    eligible = read_json(ELIGIBLE_FILE) or {}
    snapshot_loaded = true
  end
  return snapshot
end

local function save_snapshot()
  if type(snapshot) ~= "table" then return end
  write_json(SNAPSHOT_FILE, snapshot)
  snapshot_loaded = true
end

--------------------------------------------------------------------- notifiche

--- Annuncia una stella appena ricevuta, con lo stesso aspetto di ogni altra
--- notifica del plugin: titolo "ProjectHub", tema achievement, suono incluso.
--- @param info table { repo, total, who, delta }
function M.announce(info)
  local o = opts()
  notify.set_accent(o.color)

  local short = tostring(info.repo or "?"):match("([^/]+)$") or tostring(info.repo)
  local total = tonumber(info.total) or 0
  local delta = tonumber(info.delta) or 1

  local body
  if delta > 1 then
    body = string.format(i18n.t("star_notify_body_many"), short, delta, total)
  elseif info.who then
    body = string.format(i18n.t("star_notify_body"), short, info.who, total)
  else
    body = string.format(i18n.t("star_notify_body_anon"), short, total)
  end

  notify.notify(
    o.title or i18n.t("star_notify_title"),
    body,
    "achievement",
    (o.sound ~= false) and (o.sound or "achievement") or nil
  )
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

--- Login dell'account con cui `gh` è autenticato, memorizzato per sessione.
local function whoami(cb)
  if me_login ~= nil then return cb(me_login) end
  gh({ "api", "user", "--jq", ".login" }, function(lines)
    me_login = (lines and lines[1]) and vim.trim(lines[1]) or ""
    cb(me_login)
  end)
end

--- Elenco degli account da sorvegliare: `stars.owners`, altrimenti
--- `me.owners`, altrimenti l'account autenticato con gh.
local function resolve_owners(cb)
  local o = opts()
  if type(o.owners) == "table" and #o.owners > 0 then return cb(o.owners) end
  local me = config.options.me
  if me and type(me.owners) == "table" and #me.owners > 0 then return cb(me.owners) end
  whoami(function(login) cb(login ~= "" and { login } or {}) end)
end

--- Affiliazioni da chiedere a GitHub per l'ambito scelto.
local function affiliation_for(scope)
  if scope == "all" or scope == "contributor" then
    return "owner,collaborator,organization_member"
  end
  return "owner"
end

--- Verifica se `login` ha almeno un commit in un repo che non possiede.
--- La risposta cambia di rado, quindi viene messa in cache su disco: senza,
--- l'ambito "contributor" costerebbe una chiamata per repo ad ogni giro.
local function has_pushed(full_name, login, cb)
  local now = os.time()
  local hit = eligible[full_name]
  if hit and type(hit) == "table" and hit.at and (now - hit.at) < ELIGIBLE_TTL then
    return cb(hit.ok == true)
  end
  gh({
    "api",
    string.format("repos/%s/commits?author=%s&per_page=1", full_name, login),
    "--jq", "length",
  }, function(lines)
    local n = tonumber(lines and lines[1] and vim.trim(lines[1])) or 0
    eligible[full_name] = { ok = n > 0, at = now }
    cb(n > 0)
  end)
end

--- Raccoglie i repo di un account, già filtrati secondo l'ambito.
--- @param owner string
--- @param scope string "owner" | "contributor" | "all"
--- @param cb fun(repos: table)  -- { { name, stars } }
local function fetch_repos(owner, scope, cb)
  whoami(function(me)
    -- Per l'account autenticato si usa `user/repos`, che vede anche i privati
    -- e conosce le affiliazioni; per gli altri account solo i repo pubblici,
    -- perché senza le loro credenziali GitHub non mostra altro.
    local is_me = (me ~= "" and owner:lower() == me:lower())
    local endpoint = is_me
        and string.format("user/repos?per_page=100&affiliation=%s", affiliation_for(scope))
        or string.format("users/%s/repos?per_page=100&type=owner", owner)

    gh({ "api", "--paginate", endpoint, "--jq",
      '.[] | "\\(.full_name)\t\\(.stargazers_count)\t\\(.owner.login)"' }, function(lines)
      local rows = {}
      for _, l in ipairs(lines or {}) do
        local name, n, own = l:match("^(%S+)\t(%d+)\t(%S+)$")
        if name then
          rows[#rows + 1] = { name = name, stars = tonumber(n), owner = own }
        end
      end

      -- "owner": tiene solo ciò che l'account possiede davvero.
      -- "all": tiene tutto ciò a cui ha accesso.
      -- "contributor": i propri, più quelli altrui in cui ha almeno un commit.
      if scope ~= "contributor" then
        local out = {}
        for _, r in ipairs(rows) do
          if scope == "all" or r.owner:lower() == owner:lower() then
            out[#out + 1] = r
          end
        end
        return cb(out)
      end

      local out, foreign = {}, {}
      for _, r in ipairs(rows) do
        if r.owner:lower() == owner:lower() then
          out[#out + 1] = r
        else
          foreign[#foreign + 1] = r
        end
      end
      if #foreign == 0 then return cb(out) end

      local pending = #foreign
      for _, r in ipairs(foreign) do
        has_pushed(r.name, owner, function(ok)
          if ok then out[#out + 1] = r end
          pending = pending - 1
          if pending == 0 then
            write_json(ELIGIBLE_FILE, eligible)
            cb(out)
          end
        end)
      end
    end)
  end)
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

--- Interroga GitHub, confronta con l'istantanea e notifica le differenze.
--- @param on_done? fun(gained: table, first_run: boolean)
function M.check(on_done)
  if polling then
    if on_done then on_done({}, false) end
    return
  end
  polling = true
  ensure_snapshot()

  local function finish(gained, first_run)
    polling = false
    if on_done then on_done(gained or {}, first_run == true) end
  end

  local scope = tostring(opts().scope or "owner"):lower()
  if scope ~= "owner" and scope ~= "contributor" and scope ~= "all" then
    scope = "owner"
  end

  resolve_owners(function(owners)
    if #owners == 0 then return finish({}, false) end

    local pending = #owners
    local counts = {}

    for _, owner in ipairs(owners) do
      fetch_repos(owner, scope, function(rows)
        for _, r in ipairs(rows) do counts[r.name] = r.stars end

        pending = pending - 1
        if pending > 0 then return end
        if next(counts) == nil then return finish({}, false) end

        -- Primo avvio: si registra solo la linea di base, senza notificare
        -- le stelle già ricevute in passato.
        if snapshot == nil then
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

        if #gained == 0 then return finish({}, false) end

        -- Una notifica per repo, distanziate così il suono non si sovrappone
        -- a se stesso quando arrivano più stelle nello stesso giro.
        local shown = 0
        for i, g in ipairs(gained) do
          newest_stargazer(g.repo, g.total, function(who)
            g.who = who
            vim.defer_fn(function()
              M.announce(g)
              shown = shown + 1
              if shown == #gained then finish(gained, false) end
            end, (i - 1) * 1200)
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
      notify.notify(i18n.t("star_no_gh"), nil, "warn", "error")
    end
    return false
  end

  ensure_snapshot()

  local interval = math.max(30, tonumber(opts().interval) or 120) * 1000
  timer = uv.new_timer()
  timer:start(2000, interval, vim.schedule_wrap(function() M.check() end))

  if not silent then
    notify.notify(
      string.format(i18n.t("star_watch_started"), math.floor(interval / 1000)),
      string.format(i18n.t("star_watch_scope"), tostring(opts().scope or "owner")),
      "toggle",
      "toggle"
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
    notify.notify(i18n.t("star_watch_stopped"), nil, "toggle", "toggle")
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
    scope = tostring(opts().scope or "owner"),
    tracked = tracked,
    total = total,
    last_check = last_check,
    snapshot = snapshot,
  }
end

--- Dimentica quali repo altrui sono idonei, così l'ambito "contributor"
--- li riverifica al giro successivo.
function M.reset_scope_cache()
  eligible = {}
  write_json(ELIGIBLE_FILE, eligible)
end

--------------------------------------------------------------------------- test

--- Notifica finta: verifica aspetto, testo e suono senza toccare la rete.
function M.demo()
  M.announce({
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
      notify.notify(i18n.t("star_rehearse_no_repo"), nil, "warn", "error")
      return
    end
    if (snapshot[target] or 0) < 1 then
      notify.notify(string.format(i18n.t("star_rehearse_no_stars"), target), nil, "warn", "error")
      return
    end

    snapshot[target] = snapshot[target] - 1
    save_snapshot()
    notify.notify(string.format(i18n.t("star_rehearse_armed"), target), nil, "snap", "snap")
    M.check(function(gained)
      if #gained == 0 then
        notify.notify(i18n.t("star_rehearse_failed"), nil, "error", "error")
      end
    end)
  end

  ensure_snapshot()
  if snapshot == nil then
    M.check(function() vim.schedule(run) end)
  else
    run()
  end
end

return M
