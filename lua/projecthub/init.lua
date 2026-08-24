local M = {}

--- Configura projecthub.nvim. Vedi README.md per le opzioni disponibili.
---@param opts table|nil
function M.setup(opts)
  local cfg = require("projecthub.config")
  cfg.setup(opts)
  M.register_commands()

  -- La sorveglianza parte solo se richiesta esplicitamente: di default il
  -- plugin non contatta la rete da solo.
  if cfg.options.stars and cfg.options.stars.enabled then
    vim.schedule(function()
      require("projecthub.stars").start(true)
    end)
  end
end

--- Registra i comandi Neovim :ProjectHub, :PH, :PHLang e :PHl.
function M.register_commands()
  local open_cmd = function() M.open() end
  pcall(vim.api.nvim_create_user_command, "ProjectHub", open_cmd, { desc = "Open ProjectHub dashboard" })
  pcall(vim.api.nvim_create_user_command, "PH", open_cmd, { desc = "Open ProjectHub dashboard" })

  local lang_cmd = function(opts)
    local arg = opts.args and vim.trim(opts.args) or ""
    if arg == "" then
      local curr = M.get_language()
      local target = (curr == "it") and "en" or "it"
      M.set_language(target)
    else
      M.set_language(arg)
    end
  end

  local lang_opts = {
    nargs = "?",
    complete = function()
      return { "it", "en", "italiano", "english" }
    end,
    desc = "Switch ProjectHub language (it/en)",
  }

  pcall(vim.api.nvim_create_user_command, "ProjectHubLang", lang_cmd, lang_opts)
  pcall(vim.api.nvim_create_user_command, "PHLang", lang_cmd, lang_opts)
  pcall(vim.api.nvim_create_user_command, "PHl", lang_cmd, lang_opts)
  pcall(vim.api.nvim_create_user_command, "Phl", lang_cmd, lang_opts)

  -- Sorveglianza delle stelle GitHub
  local stars_cmd = function(o)
    local arg = (o.args and vim.trim(o.args) or ""):lower()
    local S = require("projecthub.stars")
    if arg == "" or arg == "status" then
      M.stars_status()
    elseif arg == "start" or arg == "on" then
      S.start()
    elseif arg == "stop" or arg == "off" then
      S.stop()
    elseif arg == "toggle" then
      S.toggle()
    elseif arg == "check" then
      S.check()
    elseif arg == "demo" or arg == "test" then
      S.demo()
    elseif arg == "rehearse" or arg == "live" then
      S.rehearse()
    else
      require("projecthub.notify").notify(
        "Uso: :PHStars [status|start|stop|toggle|check|demo|rehearse]", nil, "warn", "error")
    end
  end

  local stars_opts = {
    nargs = "?",
    complete = function()
      return { "status", "start", "stop", "toggle", "check", "demo", "rehearse" }
    end,
    desc = "ProjectHub GitHub star watcher",
  }
  pcall(vim.api.nvim_create_user_command, "ProjectHubStars", stars_cmd, stars_opts)
  pcall(vim.api.nvim_create_user_command, "PHStars", stars_cmd, stars_opts)

  pcall(vim.api.nvim_create_user_command, "PHStarsDemo",
    function() require("projecthub.stars").demo() end,
    { desc = "Show a fake star notification (visual + sound test)" })
  pcall(vim.api.nvim_create_user_command, "PHStarsCheck",
    function() require("projecthub.stars").check() end,
    { desc = "Poll GitHub for new stars right now" })
  pcall(vim.api.nvim_create_user_command, "PHStarsRehearse",
    function(o) require("projecthub.stars").rehearse(vim.trim(o.args or "")  ~= "" and vim.trim(o.args) or nil) end,
    { nargs = "?", desc = "Live end-to-end rehearsal against the real GitHub API" })

  local sound_toggle_cmd = function() M.toggle_sound() end
  pcall(vim.api.nvim_create_user_command, "ProjectHubSound", sound_toggle_cmd, { desc = "Toggle ProjectHub sound FX" })
  pcall(vim.api.nvim_create_user_command, "PHSound", sound_toggle_cmd, { desc = "Toggle ProjectHub sound FX" })
  pcall(vim.api.nvim_create_user_command, "PHSoundToggle", sound_toggle_cmd, { desc = "Toggle ProjectHub sound FX" })
end

--- Apre la dashboard dei progetti.
function M.open()
  M.register_commands()
  require("projecthub.ui").open()
end

--- Abilita o disabilita gli effetti sonori.
function M.toggle_sound()
  return require("projecthub.sound").toggle()
end

--- Imposta lo stato degli effetti sonori.
function M.set_sound(enabled)
  require("projecthub.sound").set_enabled(enabled)
end

--- Verifica se gli effetti sonori sono abilitati.
function M.is_sound_enabled()
  return require("projecthub.sound").is_enabled()
end

--- Cambia la lingua dell'interfaccia a runtime ("it" oppure "en").
function M.set_language(lang)
  if not lang or type(lang) ~= "string" then return end
  local l = vim.trim(lang):lower()
  if l == "eng" or l == "english" or l == "en" then
    l = "en"
  elseif l == "ita" or l == "italiano" or l == "it" then
    l = "it"
  end

  local cfg = require("projecthub.config")
  cfg.options.language = l
  if cfg.save_setting then
    cfg.save_setting("language", l)
  end

  local i18n = require("projecthub.i18n")
  require("projecthub.notify").notify(i18n.t("notify_lang_switched"), nil, "toggle", "toggle")

  local ui = require("projecthub.ui")
  if ui.is_open and ui.is_open() then
    ui.refresh()
  end
end

--- Avvia la sorveglianza delle stelle sui tuoi repository GitHub.
function M.start_stars()
  return require("projecthub.stars").start()
end

--- Ferma la sorveglianza delle stelle.
function M.stop_stars()
  return require("projecthub.stars").stop()
end

--- Stampa lo stato corrente della sorveglianza delle stelle.
function M.stars_status()
  local S = require("projecthub.stars")
  local i18n = require("projecthub.i18n")
  local s = S.status()
  local count = (s.total == 1) and i18n.t("star_count_one")
      or string.format(i18n.t("star_count_many"), s.total)
  local head = s.running
      and string.format(i18n.t("star_status_on"), s.tracked, count, s.interval)
      or string.format(i18n.t("star_status_off"), s.tracked, count)
  local when = s.last_check and os.date("%H:%M:%S", s.last_check) or i18n.t("star_status_never")
  require("projecthub.notify").notify(
    head,
    string.format(i18n.t("star_status_last"), when),
    "achievement",
    nil
  )
  return s
end

--- Restituisce la lingua attualmente in uso.
function M.get_language()
  return require("projecthub.i18n").get_lang()
end

M.register_commands()

return M
