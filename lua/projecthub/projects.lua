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

function M.get_custom_extras()
  if vim.fn.filereadable(CUSTOM_PROJECTS_FILE) == 0 then return {} end
  local ok, lines = pcall(vim.fn.readfile, CUSTOM_PROJECTS_FILE)
  if not ok or not lines or #lines == 0 then return {} end
  local ok_json, data = pcall(vim.json.decode, table.concat(lines, "\n"))
  return (ok_json and type(data) == "table") and data or {}
end

local function norm_path(p)
  if not p or p == "" then return "" end
  return vim.fn.fnamemodify(vim.fn.expand(p), ":p"):gsub("/$", ""):lower()
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

function M.add_custom_extra(path)
  if not path or path == "" then
    return false, "Percorso Non Valido", "Il percorso specificato è vuoto."
  end

  local expanded = vim.fn.expand(path)
  local stat = vim.uv.fs_stat(expanded)

  if not stat then
    return false, "Cartella Non Trovata", "Il percorso '" .. path .. "' non esiste sul tuo Mac."
  end

  if stat.type ~= "directory" then
    return false, "Tipo Non Valido", "'" .. vim.fn.fnamemodify(path, ":t") .. "' è un file e non una cartella."
  end

  if M.is_project(path) then
    return false, "Già Registrato", "'" .. vim.fn.fnamemodify(path, ":t") .. "' è già presente nei tuoi progetti."
  end

  local clean_p = vim.fn.fnamemodify(expanded, ":p"):gsub("/$", "")
  local extras = M.get_custom_extras()
  extras[#extras + 1] = clean_p
  local ok = pcall(vim.fn.writefile, { vim.json.encode(extras) }, CUSTOM_PROJECTS_FILE)
  cache = nil

  if not ok then
    return false, "Errore Scrittura JSON", "Impossibile salvare la configurazione in projects_custom.json."
  end

  return true, "Progetto Aggiunto", "La cartella '" .. vim.fn.fnamemodify(path, ":t") .. "' è stata registrata con successo!"
end

function M.remove_custom_extra(path)
  if not path or path == "" then return end
  path = vim.fn.fnamemodify(vim.fn.expand(path), ":p"):gsub("/$", "")
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
  path = vim.fn.fnamemodify(path, ":p"):gsub("/$", "")
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
  path = vim.fn.fnamemodify(path, ":p"):gsub("/$", "")
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
  sh = { name = "Shell", hl = "ProjectsLangShell" },
  zsh = { name = "Shell", hl = "ProjectsLangShell" },
}

-- marcatore -> etichetta del tipo di progetto
local TYPES = {
  { "Package.swift", "iOS" },
  { "Podfile", "iOS" },
  { "app/src/main/AndroidManifest.xml", "Android" },
  { "build.gradle.kts", "Gradle" },
  { "build.gradle", "Gradle" },
  { "pom.xml", "Java" },
  { "Cargo.toml", "Rust" },
  { "go.mod", "Go" },
  { "pyproject.toml", "Python" },
  { "requirements.txt", "Python" },
  { "package.json", "Node" },
  { "index.html", "Web" },
  { "init.lua", "Lua" },
}

function M.is_ignored(name)
  if name:sub(1, 1) == "." and name ~= ".config" then return true end
  return IGNORE_DIRS[name] == true
end

-- Rilevamento Asincrono non bloccante O(N) delle percentuali linguaggi
function M.load_languages(items, on_update, force)
  local queue = {}
  for _, it in ipairs(items) do
    if force or not it.languages then
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

    local function scan(dir)
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
            scan(full)
          end
        end
      end
    end

    scan(item.path)

    local list = {}
    if total_code_bytes > 0 then
      for name, sz in pairs(stats) do
        local pct = math.floor((sz / total_code_bytes) * 100 + 0.5)
        if pct >= 1 then
          local hl = "ProjectsMeta"
          for _, info in pairs(LANG_MAP) do
            if info.name == name then hl = info.hl; break end
          end
          list[#list + 1] = { name = name, pct = pct, sz = sz, hl = hl }
        end
      end
      table.sort(list, function(a, b) return a.sz > b.sz end)
    elseif md_bytes > 0 then
      list = { { name = "Markdown", pct = 100, sz = md_bytes, hl = "ProjectsLangMarkdown" } }
    end

    local search_terms = {}
    for _, l in ipairs(list) do search_terms[#search_terms + 1] = l.name:lower() end
    item.languages = list
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
  local d = math.floor((os.time() - st.mtime.sec) / 86400)
  if d <= 0 then return "oggi" end
  if d == 1 then return "ieri" end
  if d < 30 then return d .. " giorni fa" end
  if d < 365 then return math.floor(d / 30) .. " mesi fa" end
  return math.floor(d / 365) .. " anni fa"
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
    path = vim.fn.fnamemodify(vim.fn.expand(path), ":p"):gsub("/$", "")
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
  for _, path in ipairs(M.paths()) do
    local norm_path = vim.fn.fnamemodify(path, ":p"):gsub("/$", "")
    seen[norm_path] = true
    local mine, owner = is_mine(path)
    local ptype = project_type(path)
    local recent_rank = recents_map[norm_path]

    out[#out + 1] = {
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
      search = vim.fn.fnamemodify(path, ":t") .. " " .. path .. " " .. (ptype or ""),
    }
  end

  local missing_candidates = {}
  for _, p in ipairs(M.get_custom_extras()) do
    local norm = vim.fn.fnamemodify(p, ":p"):gsub("/$", "")
    missing_candidates[norm] = true
  end
  for _, p in ipairs(M.extra) do
    local norm = vim.fn.fnamemodify(p, ":p"):gsub("/$", "")
    missing_candidates[norm] = true
  end
  for norm, _ in pairs(recents_map) do
    missing_candidates[norm] = true
  end

  for norm_path, _ in pairs(missing_candidates) do
    if not seen[norm_path] and vim.fn.isdirectory(norm_path) == 0 then
      seen[norm_path] = true
      out[#out + 1] = {
        mine = true,
        owner = nil,
        path = norm_path,
        name = vim.fn.fnamemodify(norm_path, ":t"),
        dir = vim.fn.fnamemodify(norm_path, ":h"):gsub("^" .. vim.pesc(home), "~"),
        desc = "Percorso non trovato sul disco.",
        type = "Mancante",
        ago = "sconosciuta",
        mtime = 0,
        recent_rank = recents_map[norm_path] or 999,
        is_missing = true,
        search = vim.fn.fnamemodify(norm_path, ":t") .. " " .. norm_path .. " mancante spostato eliminato non trovato",
      }
    end
  end

  M.sort(out)
  cache = out
  return out
end

function M.load_git(items, on_done, force)
  local queue = {}
  for _, it in ipairs(items) do
    if force or not it.git then queue[#queue + 1] = it end
  end
  if #queue == 0 then
    if on_done then on_done() end
    return
  end

  local i, batch_size = 1, 10
  local function process_batch()
    if i > #queue then
      if on_done then on_done() end
      return
    end

    local pending = math.min(batch_size, #queue - i + 1)
    for j = 0, pending - 1 do
      local item = queue[i + j]
      local git_dir = item.path .. "/.git"
      if vim.fn.isdirectory(git_dir) == 0 then
        item.git = { none = true }
        pending = pending - 1
        if pending == 0 then
          i = i + math.min(batch_size, #queue - i + 1)
          vim.schedule(process_batch)
        end
      else
        local cmd = "git -C " .. vim.fn.shellescape(item.path)
          .. " status --porcelain=v2 --branch 2>/dev/null"
        vim.fn.jobstart(cmd, {
          stdout_buffered = true,
          on_stdout = function(_, data)
            if not data or #data == 0 then return end
            local g = {
              branch = "?",
              commits = 0,
              modified = 0,
              staged = 0,
              untracked = 0,
              conflicts = 0,
              ahead = 0,
              behind = 0,
              dirty = false,
            }

            for _, line in ipairs(data) do
              local b = line:match("^# branch%.head%s+(.+)")
              if b then g.branch = b end
              local ab = line:match("^# branch%.ab%s+%+(%d+)%s+%-(%d+)")
              if ab then
                local a, beh = line:match("^# branch%.ab%s+%+(%d+)%s+%-(%d+)")
                g.ahead, g.behind = tonumber(a) or 0, tonumber(beh) or 0
              end
              if line:match("^[12]%s+[M%?%.]") then g.modified = g.modified + 1 end
              if line:match("^[12]%s+[A-Z]") then g.staged = g.staged + 1 end
              if line:match("^%?") then g.untracked = g.untracked + 1 end
              if line:match("^u") then g.conflicts = g.conflicts + 1 end
            end

            g.dirty = (g.modified + g.staged + g.untracked + g.conflicts) > 0

            local log_cmd = "git -C " .. vim.fn.shellescape(item.path) .. " rev-list --count HEAD 2>/dev/null"
            vim.fn.jobstart(log_cmd, {
              stdout_buffered = true,
              on_stdout = function(_, log_data)
                if log_data and log_data[1] then
                  g.commits = tonumber(log_data[1]) or 0
                end
                item.git = g
              end,
              on_exit = function()
                pending = pending - 1
                if pending == 0 then
                  i = i + batch_size
                  vim.schedule(process_batch)
                end
              end,
            })
          end,
          on_stderr = function() end,
          on_exit = function(_, code)
            if code ~= 0 and not item.git then
              item.git = { none = true }
              pending = pending - 1
              if pending == 0 then
                i = i + batch_size
                vim.schedule(process_batch)
              end
            end
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
  path = vim.fn.fnamemodify(path, ":p"):gsub("/$", "")
  local notes = M.get_notes()
  return notes[path] or ""
end

function M.save_note(path, text)
  path = vim.fn.fnamemodify(path, ":p"):gsub("/$", "")
  local notes = M.get_notes()
  notes[path] = text
  pcall(vim.fn.writefile, { vim.json.encode(notes) }, NOTES_FILE)
end

local COMMIT_CACHE = {}
local GH_CACHE = {}

function M.has_commit_cache(key)
  return COMMIT_CACHE[key] ~= nil
end

function M.has_gh_cache(path)
  return GH_CACHE[path] ~= nil
end

function M.get_commit_details(path, limit)
  limit = limit or 25
  local key = path .. ":" .. tostring(limit)
  if COMMIT_CACHE[key] then
    return COMMIT_CACHE[key].commits, COMMIT_CACHE[key].stats
  end

  local git_dir = path .. "/.git"
  if vim.fn.isdirectory(git_dir) == 0 then
    COMMIT_CACHE[key] = { commits = {}, stats = {} }
    return {}, {}
  end

  local shortlog_cmd = string.format("git -C %s shortlog -sn HEAD 2>/dev/null", vim.fn.shellescape(path))
  local h_s = io.popen(shortlog_cmd)
  local author_stats = {}
  if h_s then
    local s_str = h_s:read("*a")
    h_s:close()
    for line in s_str:gmatch("[^\r\n]+") do
      local count, name = line:match("^%s*(%d+)%s+(.+)$")
      if count and name then
        author_stats[#author_stats + 1] = {
          name = vim.trim(name),
          count = tonumber(count) or 0,
          is_owner = false,
        }
      end
    end
  end

  local num_authors = #author_stats
  local show_author = num_authors > 1

  local cmd = string.format("git -C %s log -n %d --pretty=format:\"%%h|%%cr|%%an|%%s\" 2>/dev/null", vim.fn.shellescape(path), limit)
  local handle = io.popen(cmd)
  local commits = {}
  if handle then
    local output = handle:read("*a")
    handle:close()
    if output and output ~= "" then
      for line in output:gmatch("[^\r\n]+") do
        local hash, age, author, subject = line:match("^([^|]+)|([^|]+)|([^|]+)|(.+)$")
        if hash and age and subject then
          commits[#commits + 1] = {
            hash = hash,
            age = age,
            author = author,
            subject = subject,
            show_author = show_author,
            is_owner = false,
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

function M.get_github_meta(path)
  if GH_CACHE[path] ~= nil then
    return GH_CACHE[path] or nil
  end
  return nil
end

function M.async_load_github_meta(path, callback)
  if GH_CACHE[path] ~= nil then return end

  local git_dir = path .. "/.git"
  if vim.fn.isdirectory(git_dir) == 0 then
    GH_CACHE[path] = false
    return
  end

  local r_cmd = string.format("git -C %s remote get-url origin 2>/dev/null", vim.fn.shellescape(path))
  vim.fn.jobstart(r_cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      local origin_url = (data and data[1]) and vim.trim(data[1]) or ""
      local owner_name, repo_name = origin_url:match("github%.com[:/]([^/]+)/([^/%.]+)")
      if not (owner_name and repo_name) then
        GH_CACHE[path] = false
        return
      end

      local target = owner_name .. "/" .. repo_name
      local gh_cmd = string.format("gh repo view %s --json isPrivate,stargazerCount,forkCount,visibility,owner 2>/dev/null", vim.fn.shellescape(target))
      vim.fn.jobstart(gh_cmd, {
        stdout_buffered = true,
        on_stdout = function(_, gh_data)
          if gh_data and #gh_data > 0 then
            local str = table.concat(gh_data, "\n")
            local ok, parsed = pcall(vim.json.decode, str)
            if ok and type(parsed) == "table" then
              local res = {
                is_private = parsed.isPrivate or false,
                stars = parsed.stargazerCount or 0,
                forks = parsed.forkCount or 0,
                visibility = tostring(parsed.visibility or (parsed.isPrivate and "PRIVATE" or "PUBLIC")):upper(),
                owner = (parsed.owner and parsed.owner.login) and parsed.owner.login or owner_name,
              }
              GH_CACHE[path] = res
              if callback then vim.schedule(callback) end
              return
            end
          end
          local fallback = {
            is_private = false,
            stars = 0,
            forks = 0,
            visibility = "PUBLIC",
            owner = owner_name,
          }
          GH_CACHE[path] = fallback
          if callback then vim.schedule(callback) end
        end,
      })
    end,
  })
end

function M.get_github_url(path)
  local r_cmd = string.format("git -C %s remote get-url origin 2>/dev/null", vim.fn.shellescape(path))
  local h_r = io.popen(r_cmd)
  if h_r then
    local origin_url = vim.trim(h_r:read("*a") or "")
    h_r:close()
    if origin_url ~= "" then
      local owner_name, repo_name = origin_url:match("github%.com[:/]([^/]+)/([^/%.]+)")
      if owner_name and repo_name then
        return string.format("https://github.com/%s/%s", owner_name, repo_name)
      elseif origin_url:find("^https?://") then
        return origin_url:gsub("%.git$", "")
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

function M.calc_loc_async(item, on_done)
  if not item then return end
  if item.loc_lines and item.loc_files then
    if on_done then on_done(item.loc_lines, item.loc_files) end
    return
  end

  local total_lines = 0
  local file_count = 0
  local path = item.path

  vim.defer_fn(function()
    local function scan(dir)
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
              local ok_f, f_lines = pcall(vim.fn.readfile, full)
              if ok_f and f_lines then
                total_lines = total_lines + #f_lines
                file_count = file_count + 1
              end
            end
          elseif t == "directory" then
            scan(full)
          end
        end
      end
    end

    scan(path)
    item.loc_lines = total_lines
    item.loc_files = file_count
    if on_done then
      vim.schedule(function() on_done(total_lines, file_count) end)
    end
  end, 1)
end

function M.calc_loc(path)
  local total_lines = 0
  local file_count = 0

  local function scan(dir)
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
            local ok_f, f_lines = pcall(vim.fn.readfile, full)
            if ok_f and f_lines then
              total_lines = total_lines + #f_lines
              file_count = file_count + 1
            end
          end
        elseif t == "directory" then
          scan(full)
        end
      end
    end
  end

  scan(path)
  return total_lines, file_count
end

function M.open(path)
  M.add_recent(path)

  if config.options.on_open then
    config.options.on_open(path)
    return
  end

  vim.cmd("tcd " .. vim.fn.fnameescape(path))
  local ok, persistence = pcall(require, "persistence")
  if ok and vim.fn.filereadable(persistence.current()) == 1 then
    persistence.load()
  else
    pcall(vim.cmd, "Neotree dir=" .. vim.fn.fnameescape(path) .. " reveal")
  end
end

return M
