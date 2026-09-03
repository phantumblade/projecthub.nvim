-- Rilevamento progetti per POSIZIONE e STRUTTURA.
local config = require("projecthub.config")

local M = {}

-- Radici, extra e proprietario "mio" arrivano dalla configurazione utente
-- (require("projecthub").setup({...})), non sono piu' hardcoded qui.
setmetatable(M, {
  __index = function(_, key)
    if key == "roots" then return config.options.roots end
    if key == "extra" then return config.options.extra end
    if key == "me" then return config.options.me end
  end,
})

local DATA_DIR = vim.fn.stdpath("data") .. "/projecthub"
vim.fn.mkdir(DATA_DIR, "p")

local RECENTS_FILE = DATA_DIR .. "/recents.json"
local CUSTOM_PROJECTS_FILE = DATA_DIR .. "/custom_projects.json"
local PROJECTS_CACHE_FILE = DATA_DIR .. "/projects_cache.json"

--- Forma canonica di un percorso, da usare ogni volta che serve come identita'.
--- Le barre ripetute non cambiano il file a cui si punta - "//Volumes/x" e
--- "/Volumes/x" sono la stessa cartella per il filesystem - ma cambiano la
--- chiave: bastava una barra di troppo perche' lo stesso progetto comparisse
--- due volte, e perche' il riconoscimento dell'unita' esterna, che confronta il
--- prefisso "/Volumes/", non lo riconoscesse piu' e lo desse per eliminato.
function M.normalize_path(path)
  if not path or path == "" then return path end
  local expanded = vim.fn.fnamemodify(vim.fn.expand(path), ":p")
  return (expanded:gsub("//+", "/"):gsub("(.)/$", "%1"))
end

local function load_projects_cache()
  if vim.fn.filereadable(PROJECTS_CACHE_FILE) == 0 then return {} end
  local ok, lines = pcall(vim.fn.readfile, PROJECTS_CACHE_FILE)
  if not ok or not lines or #lines == 0 then return {} end
  local ok_json, data = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not (ok_json and type(data) == "table") then return {} end

  -- Le chiavi scritte da versioni precedenti possono essere in forma non
  -- canonica: si riconducono qui, cosi' i doppioni collassano invece di
  -- restare a generare due card per lo stesso progetto.
  local clean = {}
  for k, v in pairs(data) do
    local nk = M.normalize_path(k)
    if clean[nk] == nil or (type(v) == "table" and (v.mtime or 0) >= ((clean[nk] or {}).mtime or 0)) then
      clean[nk] = v
    end
  end
  return clean
end

local function save_projects_cache(cache_data)
  if not cache_data or type(cache_data) ~= "table" then return end
  local ok_json, encoded = pcall(vim.json.encode, cache_data)
  if ok_json and encoded then
    pcall(vim.fn.writefile, { encoded }, PROJECTS_CACHE_FILE)
  end
end

function M.cache_project_metadata(p)
  if not p or not p.path or p.path == "" or p.is_missing then return end
  local c_data = load_projects_cache()
  local norm = M.normalize_path(p.path)
  local prev = c_data[norm] or {}

  -- Questa viene chiamata mentre la lista si costruisce, quando i linguaggi
  -- sono ancora in volo: scriverli comunque significava sovrascrivere con nil
  -- quelli buoni del giro precedente, e un progetto su unita' scollegata non
  -- riusciva mai a mostrarli. Cio' che non si sa adesso si tiene da prima.
  local function keep(now, before)
    if now == nil then return before end
    return now
  end

  c_data[norm] = {
    name = keep(p.name, prev.name),
    type = keep(p.type, prev.type),
    desc = keep(p.desc, prev.desc),
    dir = keep(p.dir, prev.dir),
    ago = keep(p.ago, prev.ago),
    mtime = p.mtime or prev.mtime or 0,
    is_external = p.is_external or false,
    volume_name = keep(p.volume_name, prev.volume_name),
    mount_point = keep(p.mount_point, prev.mount_point),
    languages = keep(p.languages, prev.languages),
    mine = keep(p.mine, prev.mine),
    owner = keep(p.owner, prev.owner),
  }
  save_projects_cache(c_data)
end

function M.get_volume_info(path)
  if not path or path == "" then
    return { is_external = false, volume_name = nil, mount_point = nil }
  end
  local expanded = M.normalize_path(path)

  -- macOS: /Volumes/<VolumeName>/...
  local mac_vol = expanded:match("^/Volumes/([^/]+)")
  if mac_vol then
    local lv = mac_vol:lower()
    if lv ~= "macintosh hd" and lv ~= "macintosh hd - data" and lv ~= "system" then
      return {
        is_external = true,
        volume_name = mac_vol,
        mount_point = "/Volumes/" .. mac_vol,
      }
    end
  end

  -- Linux: /media/<User>/<VolumeName>/... or /run/media/<User>/<VolumeName>/...
  local linux_media_vol = expanded:match("^/media/[^/]+/([^/]+)") or expanded:match("^/run/media/[^/]+/([^/]+)")
  if linux_media_vol then
    local mp = expanded:match("^/media/[^/]+/[^/]+") or expanded:match("^/run/media/[^/]+/[^/]+")
    return {
      is_external = true,
      volume_name = linux_media_vol,
      mount_point = mp,
    }
  end

  -- Linux: /mnt/<VolumeName>/...
  local linux_mnt_vol = expanded:match("^/mnt/([^/]+)")
  if linux_mnt_vol and linux_mnt_vol:lower() ~= "c" and linux_mnt_vol:lower() ~= "wsl" then
    return {
      is_external = true,
      volume_name = linux_mnt_vol,
      mount_point = "/mnt/" .. linux_mnt_vol,
    }
  end

  -- Windows: D:\..., E:\..., F:\... (non-C drive letters)
  local win_drive = expanded:match("^([%a]):[/\\]")
  if win_drive and win_drive:upper() ~= "C" then
    return {
      is_external = true,
      volume_name = win_drive:upper() .. ":",
      mount_point = win_drive:upper() .. ":",
    }
  end

  return { is_external = false, volume_name = nil, mount_point = nil }
end

function M.get_custom_extras()
  if vim.fn.filereadable(CUSTOM_PROJECTS_FILE) == 0 then return {} end
  local ok, lines = pcall(vim.fn.readfile, CUSTOM_PROJECTS_FILE)
  if not ok or not lines or #lines == 0 then return {} end
  local ok_json, data = pcall(vim.json.decode, table.concat(lines, "\n"))
  return (ok_json and type(data) == "table") and data or {}
end

local function norm_path(p)
  if not p or p == "" then return "" end
  return M.normalize_path(p):lower()
end

function M.is_project(target_path)
  if not target_path or target_path == "" then return false end
  local normalized = norm_path(target_path)
  local all = M.list(false)
  for _, p in ipairs(all) do
    if norm_path(p.path) == normalized then
      return true
    end
  end
  return false
end

-- Restituisce un codice stabile (non tradotto) invece di un messaggio
-- gia' pronto: la traduzione avviene nel chiamante (ui.lua), cosi' il
-- risultato resta confrontabile indipendentemente dalla lingua attiva.
-- codes: "empty_path" | "not_found" | "not_directory" | "already_registered"
--      | "write_error" | "added"
function M.add_custom_extra(path)
  if not path or path == "" then
    return false, "empty_path", nil
  end

  local expanded = vim.fn.expand(path)
  local stat = vim.uv.fs_stat(expanded)

  if not stat then
    return false, "not_found", path
  end

  if stat.type ~= "directory" then
    return false, "not_directory", vim.fn.fnamemodify(path, ":t")
  end

  if M.is_project(path) then
    return false, "already_registered", vim.fn.fnamemodify(path, ":t")
  end

  local clean_p = M.normalize_path(expanded)
  local extras = M.get_custom_extras()
  extras[#extras + 1] = clean_p
  local ok = pcall(vim.fn.writefile, { vim.json.encode(extras) }, CUSTOM_PROJECTS_FILE)
  cache = nil

  if not ok then
    return false, "write_error", nil
  end

  return true, "added", vim.fn.fnamemodify(path, ":t")
end

function M.remove_custom_extra(path)
  if not path or path == "" then return end
  path = M.normalize_path(path)
  local extras = M.get_custom_extras()
  local new_list = {}
  for _, p in ipairs(extras) do
    if p ~= path then
      new_list[#new_list + 1] = p
    end
  end
  pcall(vim.fn.writefile, { vim.json.encode(new_list) }, CUSTOM_PROJECTS_FILE)
  cache = nil
end

function M.get_recents()
  if vim.fn.filereadable(RECENTS_FILE) == 0 then return {} end
  local ok, lines = pcall(vim.fn.readfile, RECENTS_FILE)
  if not ok or not lines or #lines == 0 then return {} end
  local ok_json, data = pcall(vim.json.decode, table.concat(lines, "\n"))
  return (ok_json and type(data) == "table") and data or {}
end

function M.add_recent(path)
  path = M.normalize_path(path)
  local recents = M.get_recents()
  local new_list = { path }
  for _, p in ipairs(recents) do
    if p ~= path and #new_list < 4 then
      new_list[#new_list + 1] = p
    end
  end
  pcall(vim.fn.writefile, { vim.json.encode(new_list) }, RECENTS_FILE)
end

function M.remove_recent(path)
  path = M.normalize_path(path)
  local recents = M.get_recents()
  local new_list = {}
  for _, p in ipairs(recents) do
    if p ~= path then
      new_list[#new_list + 1] = p
    end
  end
  pcall(vim.fn.writefile, { vim.json.encode(new_list) }, RECENTS_FILE)
  cache = nil
end

-- Cartelle da ignorare a qualsiasi profondita' (potatura O(N))
local IGNORE_DIRS = {
  ["node_modules"] = true,
  ["build"] = true,
  ["dist"] = true,
  ["target"] = true,
  ["vendor"] = true,
  ["out"] = true,
  ["lib"] = true,
  ["__pycache__"] = true,
  ["Pods"] = true,
  ["DerivedData"] = true,
  [".git"] = true,
  [".idea"] = true,
  [".vscode"] = true,
  [".gradle"] = true,
  [".cache"] = true,
  ["release"] = true,
  ["releases"] = true,
  ["bin"] = true,
  ["obj"] = true,
  ["coverage"] = true,
  [".next"] = true,
  [".nuxt"] = true,
  [".turbo"] = true,
  [".docusaurus"] = true,
  ["storybook-static"] = true,
  ["dll"] = true,
}

local IGNORE_FILES = {
  ["package-lock.json"] = true,
  ["yarn.lock"] = true,
  ["pnpm-lock.yaml"] = true,
  ["composer.lock"] = true,
  ["Cargo.lock"] = true,
  ["Gemfile.lock"] = true,
  ["poetry.lock"] = true,
  ["bun.lockb"] = true,
  ["shrinkwrap.yaml"] = true,
}

-- Mappa estensioni -> Linguaggi di programmazione di codice
local LANG_MAP = {
  kt = { name = "Kotlin", hl = "ProjectsLangKotlin" },
  java = { name = "Java", hl = "ProjectsLangJava" },
  py = { name = "Python", hl = "ProjectsLangPython" },
  ts = { name = "TypeScript", hl = "ProjectsLangTS" },
  tsx = { name = "TypeScript", hl = "ProjectsLangTS" },
  js = { name = "JavaScript", hl = "ProjectsLangJS" },
  jsx = { name = "JavaScript", hl = "ProjectsLangJS" },
  go = { name = "Go", hl = "ProjectsLangGo" },
  rs = { name = "Rust", hl = "ProjectsLangRust" },
  lua = { name = "Lua", hl = "ProjectsLangLua" },
  c = { name = "C", hl = "ProjectsLangC" },
  cpp = { name = "C++", hl = "ProjectsLangCPP" },
  hpp = { name = "C++", hl = "ProjectsLangCPP" },
  h = { name = "C", hl = "ProjectsLangC" },
  swift = { name = "Swift", hl = "ProjectsLangSwift" },
  html = { name = "HTML", hl = "ProjectsLangHTML" },
  css = { name = "CSS", hl = "ProjectsLangCSS" },
  scss = { name = "CSS", hl = "ProjectsLangCSS" },
  sass = { name = "CSS", hl = "ProjectsLangCSS" },
  less = { name = "CSS", hl = "ProjectsLangCSS" },
  vue = { name = "Vue", hl = "ProjectsLangVue" },
  svelte = { name = "Svelte", hl = "ProjectsLangSvelte" },
  astro = { name = "Astro", hl = "ProjectsLangAstro" },
  php = { name = "PHP", hl = "ProjectsLangPHP" },
  rb = { name = "Ruby", hl = "ProjectsLangRuby" },
  cs = { name = "C#", hl = "ProjectsLangCSharp" },
  dart = { name = "Dart", hl = "ProjectsLangDart" },
  zig = { name = "Zig", hl = "ProjectsLangZig" },
  sh = { name = "Shell", hl = "ProjectsLangShell" },
  zsh = { name = "Shell", hl = "ProjectsLangShell" },
  sql = { name = "SQL", hl = "ProjectsLangSQL" },
}

-- marcatore -> etichetta del tipo di progetto
-- L'ordine conta: si ferma al primo riscontro, quindi i file che descrivono un
-- ecosistema preciso vengono prima di quelli che tanti progetti hanno comunque.
local TYPES = {
  { "Package.swift", "iOS" },
  { "Podfile", "iOS" },
  { "build.gradle.kts", "Android" },
  { "build.gradle", "Gradle" },
  { "pubspec.yaml", "Flutter" },
  { "Cargo.toml", "Rust" },
  { "go.mod", "Go" },
  { "mix.exs", "Elixir" },
  { "build.zig", "Zig" },
  { "composer.json", "PHP" },
  { "Gemfile", "Ruby" },
  { "pyproject.toml", "Python" },
  { "requirements.txt", "Python" },
  { "setup.py", "Python" },
  { "package.json", "Node" },
  -- Maven: era stato tolto perche' ambiguo, ma l'ambiguita' era su Android, e
  -- Android ha gia' detto la sua due righe piu' su con build.gradle. Quello che
  -- resta qui e' Java, e senza questa riga i progetti Maven non avevano tipo.
  { "pom.xml", "Java" },
  { "CMakeLists.txt", "C++" },
  { "flake.nix", "Nix" },
  { "main.tf", "Terraform" },
  { "index.html", "Web" },
  { "init.lua", "Lua" },
  -- Ultimo: un Dockerfile sta accanto a quasi ogni altro tipo, quindi vale solo
  -- quando non c'e' nient'altro da dire.
  { "Dockerfile", "Docker" },
}

function M.is_ignored(name)
  if name:sub(1, 1) == "." and name ~= ".config" then return true end
  if IGNORE_DIRS[name] then return true end
  if IGNORE_FILES[name] then return true end
  if name:match("%.min%.[a-zA-Z0-9]+$") or name:match("%.bundle%.[a-zA-Z0-9]+$") or name:match("%.map$") then
    return true
  end
  return false
end

--- Cerca progetti fra le sottocartelle dirette di `dir`.
--- Riconosce una cartella come progetto se contiene un repository Git oppure
--- uno dei file indicatori usati da project_type (package.json, Cargo.toml,
--- build.gradle, ...). Non scende in profondita': serve a popolare la lista
--- partendo da una cartella-contenitore, non a rastrellare il disco.
---@param dir string
---@return string[] percorsi assoluti dei progetti trovati
function M.detect_projects_in(dir)
  local found = {}
  local root = M.normalize_path(dir or "")
  if root == "" or vim.fn.isdirectory(root) == 0 then return found end

  local ok, handle = pcall(vim.uv.fs_scandir, root)
  if not ok or not handle then return found end

  while true do
    local name, t = vim.uv.fs_scandir_next(handle)
    if not name then break end
    if t == "directory" and not M.is_ignored(name) then
      local full = root .. "/" .. name
      local is_proj = vim.uv.fs_stat(full .. "/.git") ~= nil
      if not is_proj then
        for _, entry in ipairs(TYPES) do
          if vim.uv.fs_stat(full .. "/" .. entry[1]) then
            is_proj = true
            break
          end
        end
      end
      if is_proj then found[#found + 1] = full end
    end
  end

  table.sort(found)
  return found
end

local LANG_CACHE = {}

-- Rilevamento Asincrono non bloccante O(N) delle percentuali linguaggi
function M.load_languages(items, on_update, force)
  local queue = {}
  for _, it in ipairs(items) do
    -- `force` deve svuotare la voce, non solo essere passato: prima bastava che
    -- la cache esistesse perche' il ricalcolo venisse saltato, quindi un
    -- progetto scansionato mentre il suo disco era staccato - e quindi con
    -- l'elenco vuoto - restava senza linguaggi anche dopo averlo ricollegato.
    if force then LANG_CACHE[it.path] = nil end
    if LANG_CACHE[it.path] then
      it.languages = LANG_CACHE[it.path]
      -- M.list() ricrea sempre `it` da zero: quando i linguaggi arrivano
      -- dalla cache vanno riaggiunti anche ai termini di ricerca, altrimenti
      -- cercare per linguaggio smette di funzionare dopo il primo refresh.
      local search_terms = {}
      for _, l in ipairs(it.languages) do search_terms[#search_terms + 1] = l.name:lower() end
      it.search = it.search .. " " .. table.concat(search_terms, " ")
    end
    if not it.languages then
      queue[#queue + 1] = it
    end
  end
  if #queue == 0 then
    if on_update then on_update() end
    return
  end

  local idx = 1
  local function process_next()
    if idx > #queue then return end

    local item = queue[idx]
    idx = idx + 1

    local stats = {}
    local total_code_bytes = 0
    local md_bytes = 0

    -- Stesso tetto alla profondita' del conteggio righe: un albero patologico
    -- non deve poter esaurire lo stack.
    local function scan(dir, depth)
      if depth > MAX_SCAN_DEPTH then return end
      local ok, handle = pcall(vim.uv.fs_scandir, dir)
      if not ok or not handle then return end
      while true do
        local name, t = vim.uv.fs_scandir_next(handle)
        if not name then break end
        if not M.is_ignored(name) then
          local full = dir .. "/" .. name
          if t == "file" then
            local ext = name:match("%.([^%.]+)$")
            if ext then
              ext = ext:lower()
              local info = LANG_MAP[ext]
              local fstat = vim.uv.fs_stat(full)
              local sz = fstat and fstat.size or 0
              if sz > 0 then
                if info then
                  stats[info.name] = (stats[info.name] or 0) + sz
                  total_code_bytes = total_code_bytes + sz
                elseif ext == "md" or ext == "markdown" then
                  md_bytes = md_bytes + sz
                end
              end
            end
          elseif t == "directory" then
            scan(full, depth + 1)
          end
        end
      end
    end

    pcall(scan, item.path, 0)

    local list = {}
    if total_code_bytes > 0 then
      for name, sz in pairs(stats) do
        local p_exact = (sz / total_code_bytes) * 100
        if p_exact >= 0.5 then
          local hl = "ProjectsMeta"
          for _, info in pairs(LANG_MAP) do
            if info.name == name then hl = info.hl; break end
          end
          list[#list + 1] = { name = name, pct = math.max(1, math.floor(p_exact + 0.5)), sz = sz, hl = hl }
        end
      end
      table.sort(list, function(a, b) return a.sz > b.sz end)

      if #list > 0 then
        local current_sum = 0
        for _, l in ipairs(list) do current_sum = current_sum + l.pct end
        if current_sum ~= 100 then
          list[1].pct = list[1].pct + (100 - current_sum)
        end
      end
    elseif md_bytes > 0 then
      list = { { name = "Markdown", pct = 100, sz = md_bytes, hl = "ProjectsLangMarkdown" } }
    end

    local search_terms = {}
    for _, l in ipairs(list) do search_terms[#search_terms + 1] = l.name:lower() end
    item.languages = list
    LANG_CACHE[item.path] = list
    -- Solo se si e' trovato qualcosa: un elenco vuoto e' quasi sempre il segno
    -- che la cartella non era raggiungibile, e non vale la pena ricordarlo.
    if #list > 0 then M.cache_project_metadata(item) end
    item.search = item.search .. " " .. table.concat(search_terms, " ")

    if on_update then on_update(item) end
    vim.schedule(process_next)
  end

  vim.schedule(process_next)
end

function M.readme_path(dir)
  for _, n in ipairs({ "README.md", "readme.md", "Readme.md", "README", "README.txt" }) do
    local p = dir .. "/" .. n
    if vim.fn.filereadable(p) == 1 then return p end
  end
  local ok, handle = pcall(vim.uv.fs_scandir, dir)
  if ok and handle then
    while true do
      local name, t = vim.uv.fs_scandir_next(handle)
      if not name then break end
      if t == "file" and (name:match("%.md$") or name:match("%.markdown$")) then
        return dir .. "/" .. name
      end
    end
  end
  return nil
end

local function readme_desc(dir)
  local file = M.readme_path(dir)
  if not file then return nil end

  local ok, lines = pcall(vim.fn.readfile, file, "", 60)
  if not ok then return nil end

  for _, line in ipairs(lines) do
    local l = vim.trim(line)
    local skip = l == ""
      or l:match("^#")
      or l:match("^!%[")
      or l:match("^<")
      or l:match("^|")
      or l:match("^[-=*_]+$")
      or l:match("^```")
      or l:match("^%[!")
    if not skip then
      l = l:gsub("^[-*+>]%s*", "")
      l = l:gsub("<[^>]*>", "")
      l = l:gsub("%[([^%]]*)%]%([^%)]*%)", "%1")
      l = l:gsub("[*_`]+", "")
      l = vim.trim(l)
      if #l >= 12 then return l end
    end
  end
  return nil
end

local function project_type(dir)
  for _, t in ipairs(TYPES) do
    if vim.uv.fs_stat(dir .. "/" .. t[1]) then return t[2] end
  end
  local handle = vim.uv.fs_scandir(dir)
  if handle then
    while true do
      local name, type = vim.uv.fs_scandir_next(handle)
      if not name then break end
      if name:match("%.xcodeproj$") or name:match("%.xcworkspace$") then
        return "iOS"
      end
      if name:match("%.csproj$") or name:match("%.sln$") then
        return "C#"
      end
    end
  end
  return nil
end

local function mtime(dir)
  local st = vim.uv.fs_stat(dir)
  return st and st.mtime.sec or 0
end

local function ago(dir)
  local st = vim.uv.fs_stat(dir)
  if not st then return nil end
  local i18n = require("projecthub.i18n")
  local d = math.floor((os.time() - st.mtime.sec) / 86400)
  if d <= 0 then return i18n.t("today") end
  if d == 1 then return i18n.t("yesterday") end
  if d < 30 then return (d == 1) and i18n.t("day_ago") or i18n.t("days_ago", d) end
  if d < 365 then
    local m = math.floor(d / 30)
    if m <= 1 then return i18n.t("month_ago") end
    return i18n.t("months_ago", m)
  end
  local y = math.floor(d / 365)
  if y <= 1 then return i18n.t("year_ago") end
  return i18n.t("years_ago", y)
end

local function remote_owner(dir)
  local cfg = dir .. "/.git/config"
  if vim.fn.filereadable(cfg) == 0 then return nil end
  local ok, lines = pcall(vim.fn.readfile, cfg, "", 80)
  if not ok then return nil end
  local in_origin = false
  for _, l in ipairs(lines) do
    if l:match('^%s*%[remote "origin"%]') then
      in_origin = true
    elseif l:match("^%s*%[") then
      in_origin = false
    elseif in_origin then
      local url = l:match("^%s*url%s*=%s*(.+)$")
      if url then
        return url:match("[:/]([^/]+)/[^/]+%.git%s*$") or url:match("[:/]([^/]+)/[^/]+%s*$")
      end
    end
  end
  return nil
end

local function is_mine(dir)
  local owner = remote_owner(dir)
  if not owner then return true, nil end
  for _, o in ipairs(M.me.owners) do
    if owner:lower() == o:lower() then return true, owner end
  end
  return false, owner
end

local cache

function M.sort(list)
  table.sort(list, function(a, b)
    local a_rec = a.recent_rank ~= nil
    local b_rec = b.recent_rank ~= nil
    if a_rec ~= b_rec then return a_rec end
    if a_rec and b_rec then return a.recent_rank < b.recent_rank end

    if a.mine ~= b.mine then return a.mine end
    return a.mtime > b.mtime
  end)
  return list
end

function M.paths()
  local seen, out = {}, {}
  local function add(path)
    path = M.normalize_path(path)
    if seen[path] or vim.fn.isdirectory(path) == 0 then return end
    seen[path] = true
    out[#out + 1] = path
  end

  for _, root in ipairs(M.roots) do
    local dir, depth = vim.fn.expand(root[1]), root[2] or 1
    if vim.fn.isdirectory(dir) == 1 then
      for name, type in vim.fs.dir(dir, { depth = depth, skip = function(d) return not M.is_ignored(d) end }) do
        local parts = vim.split(name, "/")
        if type == "directory" and #parts == depth and not M.is_ignored(parts[#parts]) then
          add(dir .. "/" .. name)
        end
      end
    end
  end
  for _, p in ipairs(M.extra) do add(p) end
  for _, p in ipairs(M.get_custom_extras()) do add(p) end
  return out
end

function M.list(refresh)
  if cache and not refresh then return cache end
  local home = vim.fn.expand("~")
  local recents = M.get_recents()
  local recents_map = {}
  for idx, p in ipairs(recents) do
    recents_map[p] = idx
  end

  local seen = {}
  local out = {}
  local disk_cache = load_projects_cache()

  for _, path in ipairs(M.paths()) do
    local norm_path = M.normalize_path(path)
    seen[norm_path] = true
    local mine, owner = is_mine(path)
    local ptype = project_type(path)
    local recent_rank = recents_map[norm_path]
    local vol_info = M.get_volume_info(path)

    local p_item = {
      mine = mine,
      owner = owner,
      path = path,
      name = vim.fn.fnamemodify(path, ":t"),
      dir = vim.fn.fnamemodify(path, ":h"):gsub("^" .. vim.pesc(home), "~"),
      desc = readme_desc(path),
      type = ptype,
      ago = ago(path),
      mtime = mtime(path),
      recent_rank = recent_rank,
      is_missing = false,
      is_external = vol_info.is_external,
      is_disconnected = false,
      volume_name = vol_info.volume_name,
      mount_point = vol_info.mount_point,
      search = vim.fn.fnamemodify(path, ":t") .. " " .. path .. " " .. (ptype or "") .. (vol_info.volume_name and (" " .. vol_info.volume_name) or ""),
    }
    out[#out + 1] = p_item
    M.cache_project_metadata(p_item)
  end

  local missing_candidates = {}
  for _, p in ipairs(M.get_custom_extras()) do
    missing_candidates[M.normalize_path(p)] = true
  end
  for _, p in ipairs(M.extra) do
    missing_candidates[M.normalize_path(p)] = true
  end
  for norm, _ in pairs(recents_map) do
    missing_candidates[norm] = true
  end
  for norm, _ in pairs(disk_cache) do
    missing_candidates[norm] = true
  end

  for norm_path, _ in pairs(missing_candidates) do
    if not seen[norm_path] and vim.fn.isdirectory(norm_path) == 0 then
      seen[norm_path] = true
      local vol_info = M.get_volume_info(norm_path)
      local cached = disk_cache[norm_path] or {}

      if vol_info.is_external or cached.is_external then
        local v_name = vol_info.volume_name or cached.volume_name or "SSD"
        local p_name = cached.name or vim.fn.fnamemodify(norm_path, ":t")
        local p_type = cached.type or "SSD"
        local p_desc = cached.desc or (require("projecthub.i18n").t("external_box_line1") .. " " .. v_name)
        local p_dir = cached.dir or vim.fn.fnamemodify(norm_path, ":h"):gsub("^" .. vim.pesc(home), "~")

        out[#out + 1] = {
          mine = (cached.mine ~= nil) and cached.mine or true,
          owner = cached.owner,
          path = norm_path,
          name = p_name,
          dir = p_dir,
          desc = p_desc,
          type = p_type,
          ago = cached.ago or require("projecthub.i18n").t("unknown"),
          mtime = cached.mtime or 0,
          recent_rank = recents_map[norm_path] or 999,
          is_missing = false,
          is_external = true,
          is_disconnected = true,
          volume_name = v_name,
          mount_point = vol_info.mount_point or cached.mount_point,
          languages = cached.languages,
          search = p_name .. " " .. norm_path .. " " .. v_name .. " " .. require("projecthub.i18n").t("external_search_terms"),
        }
      else
        out[#out + 1] = {
          mine = true,
          owner = nil,
          path = norm_path,
          name = vim.fn.fnamemodify(norm_path, ":t"),
          dir = vim.fn.fnamemodify(norm_path, ":h"):gsub("^" .. vim.pesc(home), "~"),
          desc = require("projecthub.i18n").t("missing_desc"),
          type = require("projecthub.i18n").t("missing_type"),
          ago = require("projecthub.i18n").t("unknown"),
          mtime = 0,
          recent_rank = recents_map[norm_path] or 999,
          is_missing = true,
          is_external = false,
          is_disconnected = false,
          search = vim.fn.fnamemodify(norm_path, ":t") .. " " .. norm_path .. " " .. require("projecthub.i18n").t("missing_search_terms"),
        }
      end
    end
  end

  M.sort(out)
  cache = out
  return out
end

function M.load_git(items, on_done, force)
  if force then
    M.clear_commit_cache()
  end
  M.load_github_meta_all(items)
  local queue = {}
  for _, it in ipairs(items) do
    if force or not it.git then queue[#queue + 1] = it end
  end
  if #queue == 0 then
    if on_done then on_done() end
    return
  end

  -- Un solo processo per progetto (prima erano 3 concatenati): a parita' di
  -- processi concorrenti si puo' alzare il lotto e ridurre il tempo totale.
  local i, batch_size = 1, 24
  local function process_batch()
    if i > #queue then
      if on_done then on_done() end
      return
    end

    local batch_n = math.min(batch_size, #queue - i + 1)
    local pending = batch_n
    local batch_start = i

    -- Un solo processo per progetto invece di tre annidati (status -> rev-list
    -- -> shortlog). Oltre a ridurre di 2/3 gli spawn, elimina lo stallo: prima
    -- il contatore veniva decrementato solo in fondo alla catena, quindi se
    -- `git status` usciva con codice 0 ma senza output la catena non partiva
    -- e la coda restava bloccata per sempre, senza errore.
    local function finish(item, g, auths)
      if item.git_done then return end
      item.git_done = true
      if g then
        g.dirty = (g.modified + g.staged + g.untracked + g.conflicts) > 0
        item.git = g
      elseif not item.git then
        item.git = { none = true }
      end
      if auths and next(auths) ~= nil then item.authors = auths end
      pending = pending - 1
      if pending <= 0 then
        i = batch_start + batch_n
        vim.schedule(process_batch)
      end
    end

    for j = 0, batch_n - 1 do
      local item = queue[i + j]
      item.git_done = nil
      local git_dir = item.path .. "/.git"
      if vim.fn.isdirectory(git_dir) == 0 then
        finish(item, nil, nil)
      else
        local q = vim.fn.shellescape(item.path)
        local script = table.concat({
          "git -C " .. q .. " --no-optional-locks status --porcelain=v2 --branch 2>/dev/null",
          'printf "\\037COMMITS %s\\n" "$(git -C ' .. q .. ' rev-list --count HEAD 2>/dev/null || echo 0)"',
          'printf "\\037AUTHORS\\n"',
          "git -C " .. q .. " shortlog -sn --no-merges HEAD 2>/dev/null",
        }, "; ")

        local out = {}
        vim.fn.jobstart({ "sh", "-c", script }, {
          stdout_buffered = true,
          on_stdout = function(_, data)
            if data then out = data end
          end,
          on_stderr = function() end,
          on_exit = function()
            local g = {
              branch = "?", commits = 0, modified = 0, staged = 0,
              untracked = 0, conflicts = 0, ahead = 0, behind = 0, dirty = false,
            }
            local auths = {}
            local in_authors = false
            for _, line in ipairs(out) do
              if line == "\031AUTHORS" then
                in_authors = true
              elseif line:match("^\031COMMITS ") then
                g.commits = tonumber(line:match("(%d+)")) or 0
              elseif in_authors then
                local an = line:match("^%s*%d+%s+(.+)")
                if an then
                  auths[vim.trim(an):lower():gsub("[%s%-_%.]", "")] = true
                end
              else
                local b = line:match("^# branch%.head%s+(.+)")
                if b then g.branch = b end
                local a, beh = line:match("^# branch%.ab%s+%+(%d+)%s+%-(%d+)")
                if a and beh then
                  g.ahead, g.behind = tonumber(a) or 0, tonumber(beh) or 0
                end
                local xy = line:match("^[12]%s+(%S+)")
                if xy and #xy >= 2 then
                  if xy:sub(1, 1) ~= "." then g.staged = g.staged + 1 end
                  if xy:sub(2, 2) ~= "." then g.modified = g.modified + 1 end
                elseif line:match("^%?") then
                  g.untracked = g.untracked + 1
                elseif line:match("^u") then
                  g.conflicts = g.conflicts + 1
                end
              end
            end
            finish(item, g, auths)
          end,
        })
      end
    end
  end

  process_batch()
end

local NOTES_FILE = DATA_DIR .. "/notes.json"

function M.get_notes()
  if vim.fn.filereadable(NOTES_FILE) == 0 then return {} end
  local ok, lines = pcall(vim.fn.readfile, NOTES_FILE)
  if not ok or not lines or #lines == 0 then return {} end
  local ok_json, data = pcall(vim.json.decode, table.concat(lines, "\n"))
  return (ok_json and type(data) == "table") and data or {}
end

function M.get_note(path)
  path = M.normalize_path(path)
  local notes = M.get_notes()
  return notes[path] or ""
end

function M.save_note(path, text)
  path = M.normalize_path(path)
  local notes = M.get_notes()
  notes[path] = text
  pcall(vim.fn.writefile, { vim.json.encode(notes) }, NOTES_FILE)
end

local GH_META_FILE = DATA_DIR .. "/github_meta.json"
local GH_CACHE = {}
-- Percorsi per cui una richiesta e' gia' partita e non e' ancora tornata.
local GH_INFLIGHT = {}

local function load_gh_cache_from_disk()
  if vim.fn.filereadable(GH_META_FILE) == 0 then return {} end
  local ok, lines = pcall(vim.fn.readfile, GH_META_FILE)
  if not ok or not lines or #lines == 0 then return {} end
  local ok_json, data = pcall(vim.json.decode, table.concat(lines, "\n"))
  return (ok_json and type(data) == "table") and data or {}
end

local gh_save_pending = false

-- Ogni risposta GitHub chiamava questa funzione, che riserializza e riscrive
-- l'INTERO file: con 29 repository erano 29 riscritture complete in pochi
-- istanti. Le scritture vengono ora accorpate in una sola.
local function save_gh_cache_to_disk()
  if gh_save_pending then return end
  gh_save_pending = true
  vim.defer_fn(function()
    gh_save_pending = false
    local to_save = {}
    for k, v in pairs(GH_CACHE) do
      if type(v) == "table" and not v.is_fallback then
        to_save[k] = v
      end
    end
    local encoded = (next(to_save) == nil) and "{}" or vim.json.encode(to_save)
    pcall(vim.fn.writefile, { encoded }, GH_META_FILE)
  end, 400)
end

GH_CACHE = load_gh_cache_from_disk()

local COMMIT_CACHE = {}
-- Le statistiche autori dipendono solo dal progetto, non dal numero di
-- commit richiesti: tenerle in COMMIT_CACHE (chiave path:limit) faceva
-- rieseguire `git shortlog` (~30ms su repo grandi) ad ogni cambio limite.
local AUTHORS_CACHE = {}
-- `git config user.name` e' globale: veniva letto ad ogni chiamata,
-- costando ~12ms di processo per un valore che non cambia mai.
local LOCAL_GIT_NAME = nil

function M.clear_commit_cache(path)
  if path then
    for k, _ in pairs(COMMIT_CACHE) do
      if k:sub(1, #path) == path then
        COMMIT_CACHE[k] = nil
      end
    end
    AUTHORS_CACHE[path] = nil
  else
    COMMIT_CACHE = {}
    AUTHORS_CACHE = {}
  end
end

function M.has_commit_cache(key)
  return COMMIT_CACHE[key] ~= nil
end

------------------------------------------------------- autori non umani
-- Un commit firmato da una pipeline o da un assistente non si legge come uno
-- scritto a mano: sapere a colpo d'occhio quali righe non vengono da una
-- persona cambia il modo in cui si scorre una cronologia.
--
-- Il riscontro avviene per parole intere, non per sottostringa: "claude" dentro
-- "Claudel" o "bot" dentro "Abbott" sarebbero falsi positivi che marchiano una
-- persona vera come macchina, ed e' l'errore piu' antipatico da fare qui.
local AI_TOKENS = {
  claude = true, anthropic = true, copilot = true, chatgpt = true,
  openai = true, codex = true, cursor = true, devin = true, gemini = true,
  codeium = true, tabnine = true, aider = true, sweep = true, codegen = true,
  llm = true,
  -- Volutamente NON c'e' il token "ai" da solo: e' un nome proprio diffuso
  -- (Ai Nakamura) e marchiare una persona come macchina e' l'errore peggiore
  -- che questa funzione possa fare. "Devin AI" viene riconosciuto lo stesso,
  -- da "devin"; per i casi rimasti fuori c'e' la lista in setup().
}
local BOT_TOKENS = {
  bot = true, bots = true, dependabot = true, renovate = true, greenkeeper = true,
  snyk = true, imgbot = true, codecov = true, netlify = true, vercel = true,
  travis = true, circleci = true, jenkins = true, precommit = true,
  semanticrelease = true, mergify = true, allcontributors = true,
  githubactions = true, precommitci = true,
}

--- @return string|nil "ai", "bot", oppure nil per una persona
function M.classify_author(name)
  local raw = tostring(name or "")
  if raw == "" then return nil end

  local extra = config.options.bots or {}
  local ai_extra, bot_extra = {}, {}
  for _, w in ipairs(extra.ai or {}) do ai_extra[tostring(w):lower()] = true end
  for _, w in ipairs(extra.bot or {}) do bot_extra[tostring(w):lower()] = true end

  -- "github-actions[bot]" -> github, actions, bot
  local tokens = {}
  for token in raw:lower():gmatch("[%a][%a%d]*") do
    tokens[#tokens + 1] = token
  end

  local is_bot = false
  local function look(word)
    if AI_TOKENS[word] or ai_extra[word] then return "ai" end
    if BOT_TOKENS[word] or bot_extra[word] then is_bot = true end
  end

  for i, token in ipairs(tokens) do
    if look(token) == "ai" then return "ai" end
    -- Anche la coppia adiacente, perche' diversi nomi arrivano gia' spezzati
    -- dal separatore: "pre-commit ci" o "semantic-release-bot" vanno letti
    -- come un termine solo, non come parole sciolte.
    if tokens[i + 1] and look(token .. tokens[i + 1]) == "ai" then return "ai" end
  end
  -- L'AI ha la precedenza: un "claude[bot]" resta prima di tutto un assistente,
  -- percio' il verdetto bot si emette solo dopo aver scandito il nome intero.
  return is_bot and "bot" or nil
end

-- Quanto aspettare prima di riprovare un prelievo fallito.
local GH_FALLBACK_TTL = 300

--- Ogni quanto tornare a chiedere a GitHub stelle, fork e visibilita'.
local function gh_ttl()
  return math.max(60, tonumber((config.options.github or {}).refresh) or 1800)
end

--- I metadati in cache sono ancora buoni, o vanno richiesti di nuovo?
---
--- Prima bastava che esistessero: una volta scaricato, il numero di stelle
--- restava quello per sempre, anche riaprendo Neovim, perche' niente lo
--- dichiarava mai vecchio. Un repository che passava da 1 a 4 stelle continuava
--- a mostrarne 1 finche' qualcuno non cancellava il file a mano.
function M.has_gh_cache(path)
  local c = GH_CACHE[path]
  if c == false then return true end
  if type(c) == "table" then
    -- Le voci scritte da versioni precedenti non hanno la data: valgono come
    -- scadute, cosi' si aggiornano da sole al primo avvio.
    local at = tonumber(c.fetched_at) or 0
    if at <= 0 then return false end
    -- Un tentativo andato male vale comunque come risposta per un po'. Prima
    -- valeva zero, e un repository che GitHub non sa raccontare - rete giu',
    -- `gh` non autenticato, remote privato - veniva richiesto a ogni singolo
    -- ridisegno, per sempre.
    local ttl = c.is_fallback and GH_FALLBACK_TTL or gh_ttl()
    return (os.time() - at) < ttl
  end
  return false
end

--- Dichiara vecchio tutto quello che c'e', senza buttarlo: il pannello continua
--- a mostrare i numeri di prima mentre quelli nuovi arrivano, invece di
--- svuotarsi e riempirsi. Serve al refresh manuale.
function M.expire_gh_cache()
  for _, v in pairs(GH_CACHE) do
    if type(v) == "table" then v.fetched_at = 0 end
  end
end

function M.get_commit_details(path, limit, force)
  limit = limit or 25
  local key = path .. ":" .. tostring(limit)
  if not force and COMMIT_CACHE[key] then
    return COMMIT_CACHE[key].commits, COMMIT_CACHE[key].stats
  end

  local git_dir = path .. "/.git"
  if vim.fn.isdirectory(git_dir) == 0 then
    COMMIT_CACHE[key] = { commits = {}, stats = {} }
    return {}, {}
  end

  local author_stats, owners_set, me_set
  local cached_authors = (not force) and AUTHORS_CACHE[path] or nil
  if cached_authors then
    author_stats, owners_set, me_set = cached_authors.stats, cached_authors.owners, cached_authors.me
  else
    local shortlog_cmd = string.format("git -C %s shortlog -sn --no-merges HEAD 2>/dev/null", vim.fn.shellescape(path))
    local h_s = io.popen(shortlog_cmd)
    local gh_meta = M.get_github_meta(path)
    local repo_owner_raw = (gh_meta and gh_meta.owner) and gh_meta.owner or ""
    local repo_owner_clean = repo_owner_raw:lower():gsub("[%s%-_%.]", "")

    local me_owners = M.me and M.me.owners or {}
    local is_my_repo = false
    if repo_owner_clean == "" then
      is_my_repo = true
    else
      for _, o in ipairs(me_owners) do
        if o:lower():gsub("[%s%-_%.]", "") == repo_owner_clean then
          is_my_repo = true
          break
        end
      end
    end

    if LOCAL_GIT_NAME == nil then
      LOCAL_GIT_NAME = ""
      local p_git = io.popen("git config user.name 2>/dev/null")
      if p_git then
        local g_out = p_git:read("*a")
        p_git:close()
        if g_out then LOCAL_GIT_NAME = vim.trim(g_out):lower():gsub("[%s%-_%.]", "") end
      end
    end
    local local_git_name = LOCAL_GIT_NAME

    author_stats = {}
    owners_set = {}
    me_set = {}

    if h_s then
      local s_str = h_s:read("*a")
      h_s:close()
      for line in s_str:gmatch("[^\r\n]+") do
        local count, name = line:match("^%s*(%d+)%s+(.+)$")
        if count and name then
          local c_name = vim.trim(name)
          local c_clean = c_name:lower():gsub("[%s%-_%.]", "")

          local is_me = false
          if local_git_name ~= "" and (c_clean == local_git_name or c_clean:find(local_git_name, 1, true)) then
            is_me = true
          else
            for _, o in ipairs(me_owners) do
              local o_clean = o:lower():gsub("[%s%-_%.]", "")
              if c_clean == o_clean or c_clean:find(o_clean, 1, true) or o_clean:find(c_clean, 1, true) then
                is_me = true
                break
              end
            end
          end

          if is_me then me_set[c_clean] = true end

          author_stats[#author_stats + 1] = {
            name = c_name,
            count = tonumber(count) or 0,
            is_owner = false,
            is_me = is_me,
            kind = M.classify_author(c_name),
          }
        end
      end

      if #author_stats > 0 then
        -- 1. Corona chi corrisponde al proprietario del remote, anche come
        --    alias (es. l'autore "lama-development" su lama-development/BoardHub).
        local matched_remote_owner = false
        if repo_owner_clean ~= "" then
          for _, ast in ipairs(author_stats) do
            local c_clean = ast.name:lower():gsub("[%s%-_%.]", "")
            if c_clean == repo_owner_clean or c_clean:find(repo_owner_clean, 1, true) or repo_owner_clean:find(c_clean, 1, true) then
              ast.is_owner = true
              owners_set[c_clean] = true
              matched_remote_owner = true
            end
          end
        end

        -- 2. Se il repository è mio, la corona spetta anche ai miei alias
        --    locali: git firma i commit con il nome esteso ("Andrea Perini")
        --    mentre il remote porta il login ("phantumblade"), e sono la
        --    stessa persona.
        local matched_me = false
        if is_my_repo then
          for _, ast in ipairs(author_stats) do
            if ast.is_me then
              ast.is_owner = true
              owners_set[ast.name:lower():gsub("[%s%-_%.]", "")] = true
              matched_me = true
            end
          end
        end

        -- 3. Il contributor #1 vale come creatore SOLO in mancanza dei
        --    riscontri sopra: organizzazione che non committa mai (es.
        --    "LazyVim" vs il creatore "Folke Lemaitre") o repository senza
        --    remote. Applicarlo sempre metterebbe la corona al collaboratore
        --    più attivo anche sul repository di qualcun altro.
        if not matched_remote_owner and not matched_me then
          author_stats[1].is_owner = true
          local top_clean = author_stats[1].name:lower():gsub("[%s%-_%.]", "")
          owners_set[top_clean] = true
        end
      end
    end
    AUTHORS_CACHE[path] = { stats = author_stats, owners = owners_set, me = me_set }
  end

  local num_authors = #author_stats
  local show_author = num_authors > 1

  local cmd = string.format("git -C %s log HEAD -n %d --pretty=format:\"%%h|%%cr|%%an|%%s\" 2>/dev/null", vim.fn.shellescape(path), limit)
  local handle = io.popen(cmd)
  local commits = {}
  if handle then
    local output = handle:read("*a")
    handle:close()
    if output and output ~= "" then
      for line in output:gmatch("[^\r\n]+") do
        local hash, age, author, subject = line:match("^([^|]+)|([^|]+)|([^|]+)|(.+)$")
        if hash and age and subject then
          local a_trim = vim.trim(author)
          local a_clean = a_trim:lower():gsub("[%s%-_%.]", "")
          local a_is_owner = owners_set[a_clean] or false
          local a_is_me = me_set[a_clean] or false
          commits[#commits + 1] = {
            hash = hash,
            age = age,
            author = a_trim,
            subject = subject,
            show_author = show_author,
            is_owner = a_is_owner,
            is_me = a_is_me,
            kind = M.classify_author(a_trim),
          }
        end
      end
    end
  end

  COMMIT_CACHE[key] = { commits = commits, stats = author_stats }
  return commits, author_stats
end

function M.get_recent_commits(path, limit)
  return M.get_commit_details(path, limit)
end

--------------------------------------------------------------- commit in arrivo
-- La dashboard legge soltanto il repository locale: finche' nessuno esegue un
-- `git fetch`, i commit spinti dai collaboratori su origin restano invisibili e
-- il pannello mostra in buona fede una versione vecchia del progetto. Qui un
-- fetch di sfondo aggiorna i riferimenti remoti - senza mai toccare HEAD ne' il
-- working tree - e ricava i commit che stanno davanti al punto di sincronia.
--
-- Il costo va tenuto basso, perche' questo gira mentre l'utente scorre e
-- digita. Tre regole lo governano:
--   1. i fetch scorrono a finestra, mai tutti insieme;
--   2. chi non porta novita' viene interrogato sempre piu' di rado (backoff);
--   3. i progetti affollati - quelli scaricati da altri - vengono seguiti da
--      lontano e in silenzio, perche' non e' li' che si aspettano notizie.
local INCOMING_CACHE = {}
local FETCH_STATE = {}
local WATCH_FILE = DATA_DIR .. "/incoming_watch.json"
local WATCH_OVERRIDE = nil
-- Quanti commit in arrivo sapevamo gia' di avere, l'ultima volta. Vive su disco
-- perche' INCOMING_CACHE muore con Neovim: senza, ogni riapertura ripartiva da
-- zero e riannunciava come nuovo tutto l'arretrato, ogni singola volta.
local SEEN_FILE = DATA_DIR .. "/incoming_seen.json"
local SEEN_COUNT = nil
local seen_save_pending = false

-- Quante volte di fila un repository puo' rispondere "niente di nuovo" prima
-- che l'intervallo smetta di raddoppiare. 3 significa fino a 8 volte la base.
local MAX_BACKOFF_STEPS = 3
-- Un progetto affollato resta sorvegliato, ma da molto piu' lontano.
local CROWDED_SLOWDOWN = 4
-- Fetch contemporanei. Oltre questa soglia si mette in coda: l'obiettivo e'
-- non far mai comparire una selva di processi git nel monitor di sistema.
local MAX_PARALLEL_FETCH = 3

local function incoming_opts()
  local o = config.options.incoming or {}
  return {
    enabled = o.enabled ~= false,
    -- Sotto il minuto si tratterebbe la rete come se fosse il disco: il fetch
    -- costa una connessione per repository, non uno `stat`.
    interval = math.max(60, tonumber(o.interval) or 300),
    timeout = math.max(5, tonumber(o.timeout) or 15),
    notify = o.notify ~= false,
    max_authors = math.max(1, tonumber(o.notify_max_authors) or 5),
  }
end

local function norm_path(path)
  return M.normalize_path(path)
end

local function load_seen()
  if SEEN_COUNT then return SEEN_COUNT end
  SEEN_COUNT = {}
  if vim.fn.filereadable(SEEN_FILE) == 1 then
    local ok, lines = pcall(vim.fn.readfile, SEEN_FILE)
    if ok and lines and #lines > 0 then
      local ok_json, data = pcall(vim.json.decode, table.concat(lines, "\n"))
      if ok_json and type(data) == "table" then SEEN_COUNT = data end
    end
  end
  return SEEN_COUNT
end

local function save_seen()
  if seen_save_pending then return end
  seen_save_pending = true
  -- I fetch rientrano a raffica: una scrittura sola per raffica invece di una
  -- per repository, come gia' fa la cache dei metadati GitHub.
  vim.defer_fn(function()
    seen_save_pending = false
    local to_save = {}
    for k, v in pairs(load_seen()) do
      -- Zero e' l'assenza di notizie: non vale la pena ricordarlo, e tenerlo
      -- farebbe crescere il file con ogni progetto mai aperto.
      if type(v) == "number" and v > 0 then to_save[k] = v end
    end
    local encoded = (next(to_save) == nil) and "{}" or vim.json.encode(to_save)
    pcall(vim.fn.writefile, { encoded }, SEEN_FILE)
  end, 500)
end

------------------------------------------------- sorveglianza per progetto

local function load_watch()
  if WATCH_OVERRIDE then return WATCH_OVERRIDE end
  WATCH_OVERRIDE = {}
  if vim.fn.filereadable(WATCH_FILE) == 1 then
    local ok, lines = pcall(vim.fn.readfile, WATCH_FILE)
    if ok and lines and #lines > 0 then
      local ok_json, data = pcall(vim.json.decode, table.concat(lines, "\n"))
      if ok_json and type(data) == "table" then WATCH_OVERRIDE = data end
    end
  end
  return WATCH_OVERRIDE
end

--- Scelta esplicita dell'utente per questo progetto, se l'ha espressa.
--- @return boolean|nil true/false se e' stata forzata, nil se decide l'euristica
function M.get_watch_override(path)
  local v = load_watch()[norm_path(path)]
  if v == nil then return nil end
  return v and true or false
end

--- Quanti autori distinti ha il progetto. Il dato arriva gia' pronto da
--- load_git (shortlog), quindi qui non si spawna niente.
function M.author_count(item)
  local n = 0
  for _ in pairs((item and item.authors) or {}) do n = n + 1 end
  return (n > 0) and n or 1
end

--- Un progetto e' "sorvegliato" quando merita notifiche e un ritmo serrato.
--- L'euristica: pochi autori significa progetto tuo o di un piccolo gruppo, ed
--- e' li' che un commit altrui e' una notizia. Molti autori significa quasi
--- sempre un repository altrui che hai clonato, dove le notifiche sarebbero
--- solo rumore. La scelta manuale, quando c'e', vince sempre.
function M.is_watched(path, author_count)
  local ov = M.get_watch_override(path)
  if ov ~= nil then return ov end
  return (author_count or 1) <= incoming_opts().max_authors
end

--- Inverte lo stato per questo progetto e lo registra su disco.
--- @return boolean il nuovo stato
function M.toggle_watch(path, author_count)
  local now_watched = M.is_watched(path, author_count)
  local want = not now_watched
  local w = load_watch()
  local key = norm_path(path)

  -- Se la scelta manuale coincide con quello che l'euristica direbbe da sola,
  -- si toglie l'eccezione invece di cristallizzarla: cosi' il progetto torna a
  -- seguire la regola generale se un domani cambia numero di collaboratori.
  if want == ((author_count or 1) <= incoming_opts().max_authors) then
    w[key] = nil
  else
    w[key] = want
  end

  local to_save = {}
  for k, v in pairs(w) do to_save[k] = v end
  local encoded = (next(to_save) == nil) and "{}" or vim.json.encode(to_save)
  pcall(vim.fn.writefile, { encoded }, WATCH_FILE)
  return want
end

------------------------------------------------------------------ lettura

--- Commit presenti su upstream e non ancora in locale.
--- @return table|nil { commits = {...}, count = n, upstream = "origin/main" }
function M.get_incoming(path)
  local e = INCOMING_CACHE[path]
  if e and e.count and e.count > 0 then return e end
  return nil
end

function M.clear_incoming(path)
  if path then
    INCOMING_CACHE[path] = nil
    FETCH_STATE[path] = nil
  else
    INCOMING_CACHE = {}
    FETCH_STATE = {}
  end
end

--- Dimentica l'arretrato gia' visto: il prossimo giro riannuncera' tutto.
--- Serve solo per i test e per rimettere in bolla una situazione strana.
function M.forget_seen()
  SEEN_COUNT = {}
  pcall(vim.fn.writefile, { "{}" }, SEEN_FILE)
end

--- Applica a una lista di commit gli stessi ruoli (corona / membro) gia'
--- calcolati da get_commit_details, cosi' le righe in arrivo si leggono
--- esattamente come quelle locali invece di apparire tutte anonime.
function M.tag_commit_roles(path, list)
  local ca = AUTHORS_CACHE[path]
  if not ca then return list end
  local multi = (ca.stats and #ca.stats > 1) or false
  for _, c in ipairs(list) do
    local clean = tostring(c.author or ""):lower():gsub("[%s%-_%.]", "")
    c.is_owner = ca.owners[clean] or false
    c.is_me = ca.me[clean] or false
    c.kind = M.classify_author(c.author)
    c.show_author = multi
  end
  return list
end

------------------------------------------------------------- aggiornamento

--- Ogni buca consecutiva raddoppia l'attesa, fino al tetto: un repository che
--- da mezz'ora non si muove non merita la stessa insistenza di uno attivo.
local function effective_interval(base, state, watched)
  local misses = math.min(state.misses or 0, MAX_BACKOFF_STEPS)
  return base * (watched and 1 or CROWDED_SLOWDOWN) * (2 ^ misses)
end

--- Vale la pena interrogare la rete per questo repository, adesso?
local function fetch_due(path, opts, watched)
  local state = FETCH_STATE[path]
  if not state then return true end
  if state.running then return false end
  -- `last == 0` significa "mai interrogato": la prima volta si passa sempre,
  -- altrimenti su una macchina appena riavviata (uv.now() ancora sotto
  -- l'intervallo) il primo fetch non partirebbe mai.
  if (state.last or 0) <= 0 then return true end
  local wait = effective_interval(opts.interval, state, watched) * 1000
  return ((vim.uv or vim.loop).now() - state.last) >= wait
end

--- @param authors number|nil quanti autori ha il progetto: serve a ricalcolare
---        la sorveglianza al momento giusto, non a quello sbagliato.
local function do_refresh(path, want_fetch, authors, on_change, on_finish)
  local opts = incoming_opts()
  local uv = vim.uv or vim.loop
  local state = FETCH_STATE[path] or { last = 0, running = false, misses = 0 }

  if state.running then
    if on_finish then on_finish() end
    return
  end
  state.running = true
  FETCH_STATE[path] = state

  local q = vim.fn.shellescape(path)
  local steps = {}
  if want_fetch then
    -- --no-tags: aggiorna i rami gia' tracciati senza trascinarsi dietro
    -- l'intero universo dei tag dei progetti grandi.
    steps[#steps + 1] = "git -C " .. q .. " fetch --quiet --no-tags 2>/dev/null"
  end
  steps[#steps + 1] = 'printf "\\037UP %s\\n" "$(git -C ' .. q .. ' rev-parse --abbrev-ref @{u} 2>/dev/null)"'
  steps[#steps + 1] = "git -C " .. q .. " log HEAD..@{u} --pretty=format:'%h|%cr|%an|%s' 2>/dev/null"
  local script = table.concat(steps, "; ")

  local out = {}
  local job = nil
  local finished = false

  local function finish()
    if finished then return end
    finished = true

    local upstream, commits = nil, {}
    for _, line in ipairs(out) do
      local up = line:match("^\031UP%s*(.*)$")
      if up then
        upstream = (vim.trim(up) ~= "") and vim.trim(up) or nil
      else
        local hash, age, author, subject = line:match("^([^|]+)|([^|]+)|([^|]+)|(.+)$")
        if hash and age and subject then
          commits[#commits + 1] = {
            hash = hash,
            age = age,
            author = vim.trim(author),
            subject = subject,
            is_incoming = true,
          }
        end
      end
    end

    local prev = INCOMING_CACHE[path]
    -- Alla prima interrogazione di questa sessione il riferimento arriva dal
    -- disco: cosi' l'arretrato gia' visto resta silenzioso e viene annunciato
    -- solo cio' che e' comparso davvero da allora.
    local seen = load_seen()
    local key = norm_path(path)
    local prev_count = (prev and prev.count) or seen[key] or 0
    local st = FETCH_STATE[path] or {}
    st.running = false
    -- Il timestamp avanza solo dopo un vero giro di rete: un ricalcolo locale
    -- non deve far slittare il fetch successivo.
    if want_fetch then
      st.last = uv.now()
      st.misses = (#commits > prev_count) and 0 or ((st.misses or 0) + 1)
    end
    FETCH_STATE[path] = st

    INCOMING_CACHE[path] = {
      commits = commits,
      count = #commits,
      upstream = upstream or (prev and prev.upstream),
      at = uv.now(),
    }

    if seen[key] ~= #commits then
      seen[key] = #commits
      save_seen()
    end

    -- Il silenzio vale per la notifica, non per il pannello: il divider deve
    -- comparire comunque. Percio' si segnala ogni variazione, in aumento come
    -- in diminuzione, e si dice a parte se merita di essere annunciata: legare
    -- il ridisegno all'avviso faceva sparire la cronologia dai progetti muti.
    --
    -- La sorveglianza si rilegge adesso, non quando il fetch e' stato messo in
    -- coda: fra le due cose passa una richiesta di rete, e chi preme `b` in
    -- quel momento si aspetta che valga per l'avviso che sta per arrivare, non
    -- solo per il prossimo giro.
    local notifiable = M.is_watched(path, authors) and incoming_opts().notify
    if on_change and #commits ~= prev_count then
      on_change(path, INCOMING_CACHE[path], #commits - prev_count, notifiable)
    end
    if on_finish then on_finish() end
  end

  -- Un repository privato via HTTPS senza credenziali in cache chiederebbe
  -- utente e password su un terminale che non esiste, e il job resterebbe
  -- appeso per sempre: qui ogni richiesta interattiva viene negata in partenza
  -- e un timer chiude comunque la porta dopo `timeout` secondi.
  job = vim.fn.jobstart({ "sh", "-c", script }, {
    stdout_buffered = true,
    env = {
      GIT_TERMINAL_PROMPT = "0",
      GIT_ASKPASS = "true",
      SSH_ASKPASS = "true",
      GIT_SSH_COMMAND = "ssh -oBatchMode=yes -oConnectTimeout=10",
    },
    on_stdout = function(_, data)
      if data then out = data end
    end,
    on_stderr = function() end,
    on_exit = function() vim.schedule(finish) end,
  })

  if not job or job <= 0 then
    finish()
    return
  end

  vim.defer_fn(function()
    if not finished then
      pcall(vim.fn.jobstop, job)
      vim.schedule(finish)
    end
  end, opts.timeout * 1000)
end

--- Stato della sorveglianza per un repository: utile per capire perche' un
--- progetto non si sta aggiornando quanto ci si aspetta.
--- @return table { last, running, misses, interval } - interval in secondi
function M.incoming_state(path, watched)
  local state = FETCH_STATE[path] or { last = 0, running = false, misses = 0 }
  return {
    last = state.last or 0,
    running = state.running or false,
    misses = state.misses or 0,
    interval = effective_interval(incoming_opts().interval, state, watched ~= false),
  }
end

--- Ricalcolo puramente locale, senza rete: serve subito dopo un `git pull`,
--- per far sparire il divider senza attendere il giro successivo.
function M.recount_incoming(path, on_done)
  if not incoming_opts().enabled then return end
  if vim.fn.isdirectory(path .. "/.git") == 0 then return end
  do_refresh(path, false, nil, nil, on_done)
end

--- Passa in rassegna i progetti e aggiorna quelli scaduti, a finestra
--- scorrevole. Puo' essere chiamata a ogni giro del timer: chi non e' scaduto
--- non costa nulla, perche' la decisione e' un confronto fra numeri e non
--- tocca ne' disco ne' rete.
function M.refresh_incoming_all(items, on_change)
  local opts = incoming_opts()
  if not opts.enabled then return end

  local queue = {}
  for _, it in ipairs(items or {}) do
    if it.git and not it.git.none and not it.is_missing and not it.is_disconnected then
      local authors = M.author_count(it)
      -- Qui la sorveglianza serve solo a decidere ogni quanto interrogare la
      -- rete; se meriti un avviso lo si ridecide a risposta arrivata.
      if fetch_due(it.path, opts, M.is_watched(it.path, authors)) then
        queue[#queue + 1] = { path = it.path, authors = authors }
      end
    end
  end
  if #queue == 0 then return end

  local idx = 1
  local function next_one()
    if idx > #queue then return end
    local job = queue[idx]
    idx = idx + 1
    do_refresh(job.path, true, job.authors, on_change, next_one)
  end
  for _ = 1, math.min(MAX_PARALLEL_FETCH, #queue) do next_one() end
end

local function parse_git_remote(origin_url)
  if not origin_url or origin_url == "" then return nil end
  local url = vim.trim(origin_url)
  local clean = url:gsub("%.git$", ""):gsub("/+$", "")

  -- 1. Formato SSH: git@host:owner/repo
  local ssh_user, ssh_host, ssh_path = clean:match("^([%w%._%-]+)@([^:]+):(.+)$")
  if ssh_host and ssh_path then
    local parts = vim.split(ssh_path:gsub("^/+", ""), "/")
    if #parts >= 2 then
      local owner = parts[1]
      local repo = parts[#parts]
      local forge = "git"
      local h_low = ssh_host:lower()
      if h_low:find("gitlab") then
        forge = "gitlab"
      elseif h_low:find("github") then
        forge = "github"
      elseif h_low:find("bitbucket") then
        forge = "bitbucket"
      elseif h_low:find("codeberg") then
        forge = "codeberg"
      end
      local web_url = string.format("https://%s/%s/%s", ssh_host, owner, repo)
      return {
        host = ssh_host,
        forge = forge,
        owner = owner,
        repo = repo,
        web_url = web_url,
        is_ssh = true,
      }
    end
  end

  -- 2. Formato HTTPS / HTTP: https://host/owner/repo
  local proto, host, http_path = clean:match("^(https?):/+/([^/]+)/(.+)$")
  if host and http_path then
    if host:find("@") then
      host = host:match("@(.+)$") or host
    end
    local parts = vim.split(http_path:gsub("^/+", ""), "/")
    if #parts >= 2 then
      local owner = parts[1]
      local repo = parts[#parts]
      local forge = "git"
      local h_low = host:lower()
      if h_low:find("gitlab") then
        forge = "gitlab"
      elseif h_low:find("github") then
        forge = "github"
      elseif h_low:find("bitbucket") then
        forge = "bitbucket"
      elseif h_low:find("codeberg") then
        forge = "codeberg"
      end
      local web_url = string.format("%s://%s/%s/%s", proto, host, owner, repo)
      return {
        host = host,
        forge = forge,
        owner = owner,
        repo = repo,
        web_url = web_url,
        is_ssh = false,
      }
    end
  end

  return nil
end

function M.get_github_meta(path)
  local c = GH_CACHE[path]
  if type(c) == "table" then
    return c
  end

  local git_config = path .. "/.git/config"
  if vim.fn.filereadable(git_config) == 1 then
    local ok_lines, lines = pcall(vim.fn.readfile, git_config)
    if ok_lines and lines then
      local content = table.concat(lines, "\n")
      local remote_url = content:match('url%s*=%s*([^\r\n]+)')
      if remote_url then
        local r = parse_git_remote(remote_url)
        if r then
          local current_user = (config.options.me and config.options.me.owners and config.options.me.owners[1]) or ""
          local is_my_repo = (current_user ~= "" and r.owner:lower() == current_user:lower())
          local is_priv = is_my_repo and r.is_ssh
          local meta = {
            is_private = is_priv,
            stars = 0,
            forks = 0,
            owner = r.owner,
            repo = r.repo,
            forge = r.forge,
            web_url = r.web_url,
            visibility = is_priv and "PRIVATE" or "PUBLIC",
            is_fallback = true,
            fetched_at = os.time(),
          }
          GH_CACHE[path] = meta
          return meta
        end
      end
    end
  end

  if c == false then
    return nil
  end

  return nil
end

--- La callback segnala SEMPRE il completamento, anche quando non c'e' nulla da
--- fare: chi accoda le richieste ha bisogno di sapere quando liberare lo slot,
--- altrimenti la coda si ferma a meta'.
function M.async_load_github_meta(path, callback, force)
  -- Una richiesta per volta e per progetto. Senza questa guardia bastava che
  -- il pannello ridisegnasse dentro la propria callback - cosa che fa - perche'
  -- ogni ridisegno chiedesse di nuovo i metadati e ne spawnasse altri due
  -- processi: una ricorsione che finiva per esaurire i descrittori di file
  -- dell'intero Neovim ("too many open files"), non solo di questo plugin.
  if GH_INFLIGHT[path] then
    if callback then vim.schedule(callback) end
    return
  end

  local finished = false
  local function done()
    if finished then return end
    finished = true
    GH_INFLIGHT[path] = nil
    if callback then vim.schedule(callback) end
  end
  GH_INFLIGHT[path] = true

  if not force and M.has_gh_cache(path) then
    local cached = GH_CACHE[path]
    if type(cached) == "table" and not cached.is_fallback then
      done()
      return
    end
  end

  local git_dir = path .. "/.git"
  if vim.fn.isdirectory(git_dir) == 0 then
    GH_CACHE[path] = false
    done()
    return
  end

  local r_cmd = string.format("git -C %s remote get-url origin 2>/dev/null", vim.fn.shellescape(path))
  -- se il processo muore senza produrre output, on_stdout non scatta: senza
  -- questa rete lo slot della coda non verrebbe mai liberato
  local job = vim.fn.jobstart(r_cmd, {
    stdout_buffered = true,
    on_exit = function()
      vim.defer_fn(done, 50)
    end,
    on_stdout = function(_, data)
      local origin_url = (data and data[1]) and vim.trim(data[1]) or ""
      local r = parse_git_remote(origin_url)
      if not r then
        GH_CACHE[path] = false
        done()
        return
      end

      -- Se è GitHub, interroga GitHub CLI API per arricchire con stelle, fork, parent
      if r.forge == "github" then
        local gh_cmd = string.format("gh api %s 2>/dev/null", vim.fn.shellescape("repos/" .. r.owner .. "/" .. r.repo))
        vim.fn.jobstart(gh_cmd, {
          stdout_buffered = true,
          on_stdout = function(_, api_data)
            if api_data and #api_data > 0 then
              local api_str = table.concat(api_data, "\n")
              local ok, parsed = pcall(vim.json.decode, api_str)
              if ok and type(parsed) == "table" and (parsed.stargazers_count or parsed.visibility or parsed.owner or parsed.parent or parsed.source) then
                local is_priv = (parsed["private"] == true)
                local parent_repo = nil
                local p_stars, p_forks = 0, 0
                local p_obj = parsed.parent or parsed.source
                if p_obj then
                  parent_repo = p_obj.full_name or (p_obj.owner and p_obj.owner.login and (p_obj.owner.login .. "/" .. (p_obj.name or r.repo)))
                  p_stars = p_obj.stargazers_count or 0
                  p_forks = p_obj.forks_count or 0
                end

                local my_stars = parsed.stargazers_count or 0
                local my_forks = parsed.forks_count or 0

                local res = {
                  is_private = is_priv,
                  stars = (my_stars > 0) and my_stars or p_stars,
                  forks = (my_forks > 0) and my_forks or p_forks,
                  is_fork = (parsed.fork == true) or (parent_repo ~= nil),
                  parent = parent_repo,
                  visibility = tostring(parsed.visibility or (is_priv and "PRIVATE" or "PUBLIC")):upper(),
                  owner = (parsed.owner and parsed.owner.login) and parsed.owner.login or r.owner,
                  repo = r.repo,
                  forge = "github",
                  web_url = r.web_url,
                  is_fallback = false,
                  fetched_at = os.time(),
                }
                GH_CACHE[path] = res
                save_gh_cache_to_disk()
                if callback then vim.schedule(callback) end
                return
              end
            end

            local current_user = (config.options.me and config.options.me.owners and config.options.me.owners[1]) or ""
            local is_my_repo = (current_user ~= "" and r.owner:lower() == current_user:lower())
            local fallback = {
              is_private = is_my_repo and r.is_ssh,
              stars = 0,
              forks = 0,
              visibility = (is_my_repo and r.is_ssh) and "PRIVATE" or "PUBLIC",
              owner = r.owner,
              repo = r.repo,
              forge = "github",
              web_url = r.web_url,
              is_fallback = true,
              fetched_at = os.time(),
            }
            GH_CACHE[path] = fallback
            save_gh_cache_to_disk()
            if callback then vim.schedule(callback) end
          end,
        })
      else
        -- Per GitLab, Bitbucket, Codeberg e server Git remoti
        local current_user = (config.options.me and config.options.me.owners and config.options.me.owners[1]) or ""
        local is_my_repo = (current_user ~= "" and r.owner:lower() == current_user:lower())
        local res = {
          is_private = is_my_repo and r.is_ssh,
          stars = 0,
          forks = 0,
          visibility = (is_my_repo and r.is_ssh) and "PRIVATE" or "PUBLIC",
          owner = r.owner,
          repo = r.repo,
          forge = r.forge,
          web_url = r.web_url,
          is_fallback = false,
          fetched_at = os.time(),
        }
        GH_CACHE[path] = res
        save_gh_cache_to_disk()
        if callback then vim.schedule(callback) end
      end
    end,
  })
  if not job or job <= 0 then done() end
end

-- Prima venivano lanciate tutte insieme: con molti repository non ancora in
-- cache significava decine di `gh api` simultanee, che GitHub limita come
-- raffica. Ora scorrono a finestra scorrevole.
function M.load_github_meta_all(items)
  local queue = {}
  for _, it in ipairs(items) do
    if not M.has_gh_cache(it.path) then
      queue[#queue + 1] = it.path
    end
  end
  if #queue == 0 then return end

  local idx, running = 1, 0
  local MAX = 6
  local function next_one()
    if idx > #queue then return end
    local path = queue[idx]
    idx = idx + 1
    running = running + 1
    M.async_load_github_meta(path, function()
      running = running - 1
      next_one()
    end)
  end
  for _ = 1, math.min(MAX, #queue) do next_one() end
end

function M.get_github_url(path)
  local meta = M.get_github_meta(path)
  if meta and meta.web_url then
    return meta.web_url
  end

  local r_cmd = string.format("git -C %s remote get-url origin 2>/dev/null", vim.fn.shellescape(path))
  local h_r = io.popen(r_cmd)
  if h_r then
    local origin_url = vim.trim(h_r:read("*a") or "")
    h_r:close()
    if origin_url ~= "" then
      local r = parse_git_remote(origin_url)
      if r and r.web_url then
        return r.web_url
      end
    end
  end
  return nil
end

local BINARY_EXTS = {
  png = true, jpg = true, jpeg = true, gif = true, ico = true, pdf = true,
  zip = true, tar = true, gz = true, ["7z"] = true, mp3 = true, mp4 = true,
  ttf = true, woff = true, woff2 = true, eot = true, pyc = true, class = true,
  o = true, obj = true, dylib = true, so = true, dll = true, exe = true,
  jar = true, aar = true, apk = true, swp = true, db = true, sqlite = true,
}

-- Quanto in profondita' scendere in un albero di cartelle. Nessun progetto
-- vero e' annidato cosi', ma un collegamento simbolico messo male o un albero
-- generato lo sono: senza un tetto la ricorsione scende finche' non finisce lo
-- stack, e si porta dietro tutto Neovim.
local MAX_SCAN_DEPTH = 24
-- Oltre questa soglia un file non viene aperto per contarne le righe. readfile
-- carica tutto in memoria: un dump SQL o un log da mezzo giga bloccherebbe
-- l'editor per il tempo che serve a leggerlo, e il conteggio righe non vale
-- quel prezzo.
local MAX_LOC_FILE_BYTES = 2 * 1024 * 1024

-- Conteggi gia' in corso, per percorso. Senza, ogni ridisegno del pannello
-- avviava un'altra scansione completa dello stesso progetto: sono sincrone, si
-- accodano, e su un albero grande si sentono tutte.
local LOC_INFLIGHT = {}

function M.calc_loc_async(item, on_done)
  if not item then return end
  if item.loc_lines and item.loc_files then
    if on_done then on_done(item.loc_lines, item.loc_files) end
    return
  end

  local path = item.path
  if not path or path == "" then return end
  if LOC_INFLIGHT[path] then return end
  LOC_INFLIGHT[path] = true

  local total_lines = 0
  local file_count = 0

  vim.defer_fn(function()
    local function scan(dir, depth)
      if depth > MAX_SCAN_DEPTH then return end
      local ok, handle = pcall(vim.uv.fs_scandir, dir)
      if not ok or not handle then return end
      while true do
        local name, t = vim.uv.fs_scandir_next(handle)
        if not name then break end
        if not M.is_ignored(name) then
          local full = dir .. "/" .. name
          if t == "file" then
            local ext = name:match("%.([^%.]+)$")
            if not (ext and BINARY_EXTS[ext:lower()]) then
              local st = vim.uv.fs_stat(full)
              if st and (st.size or 0) <= MAX_LOC_FILE_BYTES then
                local ok_f, f_lines = pcall(vim.fn.readfile, full)
                if ok_f and f_lines then
                  total_lines = total_lines + #f_lines
                  file_count = file_count + 1
                end
              end
            end
          elseif t == "directory" then
            scan(full, depth + 1)
          end
        end
      end
    end

    local ok_scan = pcall(scan, path, 0)
    LOC_INFLIGHT[path] = nil
    -- Anche se la scansione e' andata storta il risultato si scrive comunque:
    -- lasciare i campi vuoti farebbe richiedere il conteggio a ogni ridisegno,
    -- all'infinito, che e' esattamente il ciclo da cui questa guardia protegge.
    item.loc_lines = ok_scan and total_lines or 0
    item.loc_files = ok_scan and file_count or 0
    if on_done then
      vim.schedule(function() on_done(item.loc_lines, item.loc_files) end)
    end
  end, 1)
end


function M.open(path)
  M.add_recent(path)

  if config.options.on_open then
    config.options.on_open(path)
    return
  end

  pcall(vim.cmd, "cd " .. vim.fn.fnameescape(path))

  local readme = M.readme_path(path)
  if readme and vim.fn.filereadable(readme) == 1 then
    pcall(vim.cmd, "edit " .. vim.fn.fnameescape(readme))
  end

  vim.schedule(function()
    local ok_neo = pcall(vim.cmd, "Neotree show dir=" .. vim.fn.fnameescape(path))
    if not ok_neo then
      pcall(function()
        if Snacks and Snacks.explorer then
          Snacks.explorer.open({ cwd = path })
        end
      end)
    end
  end)
end

function M.get_html_preview_file(path)
  if not path or vim.fn.isdirectory(path) == 0 then return nil end
  local idx = path .. "/index.html"
  if vim.fn.filereadable(idx) == 1 then
    return idx
  end
  local matches = vim.fn.glob(path .. "/*.html", false, true)
  if matches and #matches > 0 then
    return matches[1]
  end
  return nil
end

return M
