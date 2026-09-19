vim.opt.runtimepath:append(vim.fn.getcwd())
local config = require("projecthub.config")
config.options = vim.tbl_deep_extend("force", config.defaults, {})
local G = require("projecthub.git")

local ok, ko = 0, 0
local function check(what, good, detail)
  if good then
    ok = ok + 1
  else
    ko = ko + 1
    print(string.format("  FALLITO  %-40s -> %s", what, tostring(detail)))
  end
end

print("--- selezione dell'eseguibile Git ---")
local executable = G.executable(true)
check("trova un Git realmente funzionante", executable ~= nil, G.error())

if executable then
  local result = vim.system({ executable, "--version" }, { text = true }):wait(2500)
  check("il Git selezionato risponde", result.code == 0, result.stderr)
  check("la risposta identifica Git", tostring(result.stdout):match("git version") ~= nil, result.stdout)
  check("il comando shell e' quotato", G.shell_command() ~= nil, G.shell_command())

  -- Integrazione reale: il caricamento asincrono deve usare lo stesso
  -- eseguibile validato dal resolver e leggere davvero questo repository.
  local P = require("projecthub.projects")
  P.load_github_meta_all = function() end -- niente rete in un test locale
  local item = { path = vim.fn.getcwd() }
  local done = false
  P.load_git({ item }, function() done = true end, true)
  check("la lettura asincrona termina", vim.wait(5000, function() return done end, 10), "timeout")
  check("il ramo reale non e' '?'", item.git and item.git.branch ~= "?", item.git and item.git.branch)
  check("i commit reali non spariscono", item.git and item.git.commits > 0, item.git and item.git.commits)
end

print(string.format("\nrisultato: %d passati, %d falliti", ok, ko))
vim.cmd(ko == 0 and "qa!" or "cq")
