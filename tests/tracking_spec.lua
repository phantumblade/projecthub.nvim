-- Isola completamente i dati persistenti del test da quelli dell'utente.
local sandbox = vim.fn.tempname()
vim.fn.mkdir(sandbox .. "/data", "p")
vim.fn.mkdir(sandbox .. "/projects/visible", "p")
vim.env.XDG_DATA_HOME = sandbox .. "/data"

vim.opt.runtimepath:append(vim.fn.getcwd())
local config = require("projecthub.config")
config.options = vim.tbl_deep_extend("force", config.defaults, {
  roots = { { sandbox .. "/projects", 1 } },
  extra = {},
})
local P = require("projecthub.projects")

local ok, ko = 0, 0
local function check(what, got, want)
  if got == want then
    ok = ok + 1
  else
    ko = ko + 1
    print(string.format("  FALLITO  %-44s -> %s  (atteso %s)", what, tostring(got), tostring(want)))
  end
end

local project = P.normalize_path(sandbox .. "/projects/visible")
local function contains(path)
  for _, item in ipairs(P.list(false)) do
    if P.normalize_path(item.path) == path then return true end
  end
  return false
end

print("--- rimozione persistente dal tracciamento ---")
check("la root scopre il progetto", contains(project), true)
check("untrack viene salvato", P.untrack_project(project), true)
check("la cache viene invalidata", contains(project), false)
check("il progetto risulta nascosto", P.is_hidden(project), true)

-- Anche se la cartella sparisce e resta nei metadati storici, la cache non
-- deve ricreare una card "spostato/eliminato" che l'utente ha gia' escluso.
vim.fn.delete(project, "d")
local data_dir = vim.fn.stdpath("data") .. "/projecthub"
vim.fn.writefile({ vim.json.encode({ [project] = { name = "visible", mtime = 1 } }) }, data_dir .. "/projects_cache.json")
check("la cache disco non resuscita il progetto", contains(project), false)
vim.fn.mkdir(project, "p")

local added, code = P.add_custom_extra(project)
check("aggiungi riattiva il progetto", added, true)
check("aggiungi restituisce added", code, "added")
check("l'esclusione viene rimossa", P.is_hidden(project), false)
check("il progetto torna visibile", contains(project), true)

vim.fn.delete(sandbox, "rf")
print(string.format("\nrisultato: %d passati, %d falliti", ok, ko))
vim.cmd(ko == 0 and "qa!" or "cq")
