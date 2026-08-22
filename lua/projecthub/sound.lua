local M = {}

local SOUND_MAP = {
  success = "success.mp3",
  delete = "delete.mp3",
  connect = "connect.mp3",
  checkpoint = "checkpoint.mp3",
  snap = "snap.mp3",
  toggle = "toggle-on.mp3",
  toggle_on = "toggle-on.mp3",
  toggle_off = "toggle-off.mp3",
  open = "open.mp3",
  error = "error.mp3",
  select = "select.mp3",
  typing = "typing.mp3",
}

local last_typing_time = 0

local function get_sound_dir()
  local src = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(src, ":h:h:h") .. "/sounds/minimal"
end

--- Riproduce un effetto sonoro in background in modo asincrono (0ms di blocco UI).
--- @param event string Identificatore del suono ("success", "delete", "connect", "checkpoint", "snap", "toggle", "open", "error", "select", "typing")
--- @param force? boolean Se true, riproduce anche se sound è disabilitato (usato per toggle_off)
function M.play(event, force)
  local ok, config = pcall(require, "projecthub.config")
  if not force and ok and config.options and config.options.sound and config.options.sound.enabled == false then
    return
  end

  if event == "typing" then
    local now = (vim.uv or vim.loop).now()
    if (now - last_typing_time) < 35 then
      return
    end
    last_typing_time = now
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

function M.is_enabled()
  local ok, config = pcall(require, "projecthub.config")
  if ok and config.options and config.options.sound then
    return config.options.sound.enabled ~= false
  end
  return true
end

function M.set_enabled(val)
  local ok, config = pcall(require, "projecthub.config")
  if ok and config.options then
    if not config.options.sound then
      config.options.sound = { volume = 0.5 }
    end
    config.options.sound.enabled = (val == true)
  end
end

--- Abilita o disabilita il sistema sonoro con notifica Toast e feedback coerente.
--- @return boolean Nuovo stato abilitato (true / false)
function M.toggle()
  local current = M.is_enabled()
  local target = not current

  local i18n = require("projecthub.i18n")
  if target then
    M.set_enabled(true)
    M.play("toggle_on")
    vim.notify("  " .. i18n.t("notify_sound_enabled"), vim.log.levels.INFO, { title = "Sound FX" })
  else
    M.play("toggle_off", true)
    M.set_enabled(false)
    vim.notify("󰝟  " .. i18n.t("notify_sound_disabled"), vim.log.levels.WARN, { title = "Sound FX" })
  end

  if package.loaded["snacks"] and _G.Snacks and _G.Snacks.dashboard and _G.Snacks.dashboard.update then
    pcall(_G.Snacks.dashboard.update)
  end

  return target
end

return M
