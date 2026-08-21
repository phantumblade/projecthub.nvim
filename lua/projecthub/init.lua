local M = {}

--- Configura projecthub.nvim. Vedi README.md per le opzioni disponibili.
---@param opts table|nil
function M.setup(opts)
  require("projecthub.config").setup(opts)
  M.register_commands()
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
end

--- Apre la dashboard dei progetti.
function M.open()
  M.register_commands()
  require("projecthub.ui").open()
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

  require("projecthub.config").options.language = l

  local i18n = require("projecthub.i18n")
  local msg = i18n.t("notify_lang_switched")
  vim.notify("󰄬 " .. msg, vim.log.levels.INFO, { title = "ProjectHub" })

  local ui = require("projecthub.ui")
  if ui.is_open and ui.is_open() then
    ui.refresh()
  end
end

--- Restituisce la lingua attualmente in uso.
function M.get_language()
  return require("projecthub.i18n").get_lang()
end

M.register_commands()

return M
