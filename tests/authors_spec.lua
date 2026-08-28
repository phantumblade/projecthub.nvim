vim.opt.runtimepath:append(vim.fn.getcwd())
local config = require("projecthub.config")
config.options = vim.tbl_deep_extend("force", config.defaults, {
  bots = { ai = { "atlas" }, bot = { "deploybot" } },
})
local P = require("projecthub.projects")

local ok, ko = 0, 0
local function check(name, want)
  local got = P.classify_author(name)
  if got == want then
    ok = ok + 1
  else
    ko = ko + 1
    print(string.format("  FALLITO  %-26s -> %s  (atteso %s)", '"' .. name .. '"', tostring(got), tostring(want)))
  end
end

print("--- pipeline e bot ---")
check("github-actions[bot]", "bot")
check("dependabot[bot]", "bot")
check("renovate[bot]", "bot")
check("semantic-release-bot", "bot")
check("pre-commit ci", "bot")
check("Codecov", "bot")
check("deploybot", "bot")               -- aggiunto dalla configurazione

print("--- assistenti ---")
check("Claude", "ai")
check("Claude Opus 5", "ai")
check("Claude AI", "ai")
check("GitHub Copilot", "ai")
check("Cursor Agent", "ai")
check("Devin AI", "ai")
check("Atlas", "ai")                    -- aggiunto dalla configurazione
-- Un assistente che firma come bot resta prima di tutto un assistente
check("claude[bot]", "ai")

print("--- persone vere: nessuna deve finire marchiata ---")
check("Andrea Perini", nil)
check("Davide La Marca", nil)
check("lama-development", nil)
check("Folke Lemaitre", nil)
check("Claudel Dupont", nil)            -- contiene "claude"
check("Claudia Rossi", nil)             -- contiene "claud"
check("John Abbott", nil)               -- contiene "bott"
check("Robert Botticelli", nil)         -- contiene "bot"
check("Ai Nakamura", nil)               -- "Ai" e' un nome proprio
check("Ai Weiwei", nil)
check("Roberto Botta", nil)

print(string.format("\nrisultato: %d passati, %d falliti", ok, ko))
vim.cmd(ko == 0 and "qa!" or "cq")
