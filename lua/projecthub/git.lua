-- Risoluzione dell'eseguibile Git.
--
-- Su macOS /usr/bin/git e' uno shim di Xcode: dopo un aggiornamento puo'
-- esistere ed essere trovato sul PATH, ma rifiutarsi di partire finche' la
-- licenza non viene accettata. Controllare solo executable() in quel caso e'
-- un falso positivo e ProjectHub finirebbe per mostrare ramo "?" e 0 commit.
local config = require("projecthub.config")

local M = {}

local cached_executable = nil
local cached_error = nil
local last_check = 0
local notified = false
local NEGATIVE_CACHE_MS = 5000

local function now_ms()
  return (vim.uv or vim.loop).now()
end

local function add_candidate(out, seen, candidate)
  if type(candidate) ~= "string" or candidate == "" or seen[candidate] then return end
  seen[candidate] = true
  out[#out + 1] = candidate
end

local function candidates()
  local out, seen = {}, {}
  local configured = config.options.git and config.options.git.command or nil
  add_candidate(out, seen, configured)

  -- exepath restituisce il comando che Neovim lancerebbe davvero. Va provato,
  -- non solo trovato: /usr/bin/git puo' essere presente ma inutilizzabile.
  add_candidate(out, seen, vim.fn.exepath("git"))

  if vim.fn.has("macunix") == 1 then
    -- Il binario reale incluso in Xcode funziona anche quando lo shim
    -- /usr/bin/git e' bloccato dalla licenza non ancora accettata.
    add_candidate(out, seen, "/Applications/Xcode.app/Contents/Developer/usr/bin/git")
    add_candidate(out, seen, "/opt/homebrew/bin/git")
    add_candidate(out, seen, "/usr/local/bin/git")
  end

  -- Utile sui sistemi in cui exepath() non risolve il comando ma la shell si'.
  add_candidate(out, seen, "git")
  return out
end

local function probe(candidate)
  local ok, process = pcall(vim.system, { candidate, "--version" }, { text = true })
  if not ok then return false, tostring(process) end
  local result = process:wait(2500)
  if result and result.code == 0 and tostring(result.stdout or ""):match("git version") then
    return true, nil
  end
  local reason = result and (result.stderr or result.stdout) or "processo Git senza risposta"
  return false, vim.trim(tostring(reason or ""))
end

--- Restituisce un eseguibile Git che e' stato realmente avviato con successo.
--- I fallimenti vengono ricordati solo per pochi secondi, cosi' accettare la
--- licenza o installare Git mentre Neovim e' aperto basta per farlo ripartire.
---@param force boolean|nil
---@return string|nil
function M.executable(force)
  local now = now_ms()
  if not force and cached_executable then return cached_executable end
  if not force and cached_error and (now - last_check) < NEGATIVE_CACHE_MS then return nil end

  cached_executable, cached_error = nil, nil
  last_check = now
  local errors = {}
  for _, candidate in ipairs(candidates()) do
    local ok, err = probe(candidate)
    if ok then
      cached_executable = candidate
      return candidate
    end
    if err and err ~= "" then errors[#errors + 1] = err end
  end
  cached_error = table.concat(errors, "\n")
  return nil
end

--- Forma pronta da inserire in una pipeline della shell.
---@return string|nil
function M.shell_command()
  local executable = M.executable()
  return executable and vim.fn.shellescape(executable) or nil
end

function M.error()
  return cached_error
end

function M.reset()
  cached_executable, cached_error, last_check, notified = nil, nil, 0, false
end

function M.notify_unavailable()
  if notified then return end
  notified = true
  local reason = cached_error or ""
  local hint
  if reason:lower():find("xcode license", 1, true) then
    hint = "sudo xcodebuild -license accept"
  else
    hint = reason ~= "" and reason or "git --version"
  end
  vim.schedule(function()
    vim.notify(
      require("projecthub.i18n").t("notify_git_unavailable", hint),
      vim.log.levels.ERROR
    )
  end)
end

return M
