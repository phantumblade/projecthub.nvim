local M = {}

local SOUND_MAP = {
  success = "success",
  delete = "delete",
  connect = "connect",
  checkpoint = "checkpoint",
  snap = "snap",
  toggle = "toggle-on",
  toggle_on = "toggle-on",
  toggle_off = "toggle-off",
  open = "open",
  error = "error",
  select = "select",
  typing = "typing",
}

local last_typing_time = 0
local active_typing_job = nil

local function get_sound_dir()
  local src = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(src, ":h:h:h") .. "/sounds/minimal"
end

local function get_sound_file(name)
  local base = get_sound_dir() .. "/" .. name
  if vim.fn.filereadable(base .. ".wav") == 1 then
    return base .. ".wav"
  elseif vim.fn.filereadable(base .. ".mp3") == 1 then
    return base .. ".mp3"
  end
  return nil
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
    if (now - last_typing_time) < 45 then
      return
    end
    last_typing_time = now

    if active_typing_job then
      pcall(vim.fn.jobstop, active_typing_job)
      active_typing_job = nil
    end
  end

  local sound_name = SOUND_MAP[event] or event
  local sound_path = get_sound_file(sound_name)
  if not sound_path then
    return
  end

  local volume = (ok and config.options and config.options.sound and config.options.sound.volume) or 0.5
  if event == "typing" then
    volume = math.max(0.05, volume * 0.35)
  end

  if vim.fn.has("mac") == 1 then
    -- macOS: afplay con qualità alta (-q 1) e volume lineare
    local job = vim.fn.jobstart({ "afplay", "-q", "1", "-v", tostring(volume), sound_path }, { detach = true })
    if event == "typing" then
      active_typing_job = job
    end
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
    vim.notify(i18n.t("notify_sound_enabled"), vim.log.levels.INFO, { title = "Sound FX", icon = " " })
  else
    M.play("toggle_off", true)
    M.set_enabled(false)
    vim.notify(i18n.t("notify_sound_disabled"), vim.log.levels.WARN, { title = "Sound FX", icon = "󰝟 " })
  end

  if package.loaded["snacks"] and _G.Snacks and _G.Snacks.dashboard and _G.Snacks.dashboard.update then
    pcall(_G.Snacks.dashboard.update)
  end

  return target
end

return M
