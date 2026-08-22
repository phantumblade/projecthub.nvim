local M = {}

local SOUND_MAP = {
  success = "success.mp3",
  delete = "delete.mp3",
  connect = "connect.mp3",
  checkpoint = "checkpoint.mp3",
  snap = "snap.mp3",
  toggle = "toggle-on.mp3",
  open = "open.mp3",
  error = "error.mp3",
  select = "select.mp3",
}

local function get_sound_dir()
  local src = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(src, ":h:h:h") .. "/sounds/minimal"
end

--- Riproduce un effetto sonoro in background in modo asincrono (0ms di blocco UI).
--- @param event string Identificatore del suono ("success", "delete", "connect", "checkpoint", "snap", "toggle", "open", "error", "select")
function M.play(event)
  local ok, config = pcall(require, "projecthub.config")
  if ok and config.options and config.options.sound and config.options.sound.enabled == false then
    return
  end

  local filename = SOUND_MAP[event] or (event .. ".mp3")
  local sound_path = get_sound_dir() .. "/" .. filename
  if vim.fn.filereadable(sound_path) == 0 then
    return
  end

  local volume = (ok and config.options and config.options.sound and config.options.sound.volume) or 0.5

  if vim.fn.has("mac") == 1 then
    -- macOS: afplay con flag volume (0.0 - 1.0)
    vim.fn.jobstart({ "afplay", "-v", tostring(volume), sound_path }, { detach = true })
  elseif vim.fn.has("unix") == 1 then
    -- Linux: tenta pw-play, paplay, mpv, ffplay o aplay
    if vim.fn.executable("pw-play") == 1 then
      vim.fn.jobstart({ "pw-play", sound_path }, { detach = true })
    elseif vim.fn.executable("paplay") == 1 then
      vim.fn.jobstart({ "paplay", sound_path }, { detach = true })
    elseif vim.fn.executable("mpv") == 1 then
      local vol_int = math.floor(volume * 100)
      vim.fn.jobstart({ "mpv", "--no-video", "--volume=" .. tostring(vol_int), sound_path }, { detach = true })
    elseif vim.fn.executable("ffplay") == 1 then
      local vol_int = math.floor(volume * 100)
      vim.fn.jobstart({ "ffplay", "-nodisp", "-autoexit", "-volume", tostring(vol_int), sound_path }, { detach = true })
    end
  elseif vim.fn.has("win32") == 1 then
    -- Windows: PowerShell Media.SoundPlayer o ffplay
    if vim.fn.executable("ffplay") == 1 then
      local vol_int = math.floor(volume * 100)
      vim.fn.jobstart({ "ffplay", "-nodisp", "-autoexit", "-volume", tostring(vol_int), sound_path }, { detach = true })
    else
      local ps_cmd = string.format("(New-Object Media.SoundPlayer '%s').PlaySync()", sound_path)
      vim.fn.jobstart({ "powershell", "-NoProfile", "-NonInteractive", "-Command", ps_cmd }, { detach = true })
    end
  end
end

return M
