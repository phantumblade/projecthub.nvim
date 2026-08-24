-- Notifiche di ProjectHub: un solo posto in cui vivono icona, livello,
-- colori e suono di ogni tipo di avviso, così tutto ciò che il plugin
-- comunica ha lo stesso aspetto — dashboard, cambio lingua o stelle GitHub.
--
-- I gruppi di evidenziazione passati in `hl` vengono onorati dai notifier
-- che li supportano (snacks.nvim fra questi); con vim.notify nudo restano
-- il testo e il livello, esattamente come per ogni altra notifica.

local sound = require("projecthub.sound")

local M = {}

--- Colore d'accento dei traguardi. Definito qui e non collegato a un gruppo
--- del tema, così l'oro resta oro qualunque colorscheme sia in uso.
function M.set_accent(color)
  vim.api.nvim_set_hl(0, "ProjectsAchievement", { fg = color or "#E3B341", bold = true })
end

M.set_accent()


M.themes = {
  success = {
    level = vim.log.levels.INFO,
    icon = "\u{f012c} ",
    hl = { border = "DiagnosticOk", title = "DiagnosticOk", icon = "DiagnosticOk" },
  },
  delete = {
    level = vim.log.levels.WARN,
    icon = "\u{f0a79} ",
    hl = { border = "DiagnosticError", title = "DiagnosticError", icon = "DiagnosticError" },
  },
  connect = {
    level = vim.log.levels.INFO,
    icon = "\u{f06d2} ",
    hl = { border = "DiagnosticInfo", title = "DiagnosticInfo", icon = "DiagnosticInfo" },
  },
  checkpoint = {
    level = vim.log.levels.INFO,
    icon = "\u{f082e} ",
    hl = { border = "DiagnosticWarn", title = "DiagnosticWarn", icon = "DiagnosticWarn" },
  },
  snap = {
    level = vim.log.levels.INFO,
    icon = "\u{f02a2} ",
    hl = { border = "DiagnosticHint", title = "DiagnosticHint", icon = "DiagnosticHint" },
  },
  toggle = {
    level = vim.log.levels.INFO,
    icon = "\u{f075a} ",
    hl = { border = "DiagnosticInfo", title = "DiagnosticInfo", icon = "DiagnosticInfo" },
  },
  open = {
    level = vim.log.levels.INFO,
    icon = "\u{f059f} ",
    hl = { border = "DiagnosticInfo", title = "DiagnosticInfo", icon = "DiagnosticInfo" },
  },
  warn = {
    level = vim.log.levels.WARN,
    icon = "\u{f0028} ",
    hl = { border = "DiagnosticWarn", title = "DiagnosticWarn", icon = "DiagnosticWarn" },
  },
  -- Traguardo raggiunto: oro fisso in ogni tema, perché una stella ricevuta
  -- non deve confondersi con un normale avviso informativo.
  achievement = {
    level = vim.log.levels.INFO,
    icon = "\u{f091} ", -- nf-fa-trophy
    hl = { border = "ProjectsAchievement", title = "ProjectsAchievement", icon = "ProjectsAchievement" },
  },
  error = {
    level = vim.log.levels.ERROR,
    icon = "\u{f0156} ",
    hl = { border = "DiagnosticError", title = "DiagnosticError", icon = "DiagnosticError" },
  },
}

function M.notify(title_text, msg_text, theme_name, sound_ev)
  if sound_ev then
    sound.play(sound_ev)
  end
  local theme = M.themes[theme_name or "success"] or M.themes.success
  local full_msg = title_text or ""
  if msg_text and msg_text ~= "" and msg_text ~= title_text then
    full_msg = title_text .. "\n" .. msg_text
  end

  vim.notify(full_msg, theme.level, {
    title = "ProjectHub",
    icon = theme.icon,
    hl = theme.hl,
  })
end

return M
