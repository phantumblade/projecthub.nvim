vim.opt.runtimepath:append(vim.fn.getcwd())
local config = require("projecthub.config")
config.options = vim.tbl_deep_extend("force", config.defaults, {})
local P = require("projecthub.projects")

local ok, ko = 0, 0
local function check(what, got, want)
  if got == want then
    ok = ok + 1
  else
    ko = ko + 1
    print(string.format("  FALLITO  %-48s -> %s  (atteso %s)", what, tostring(got), tostring(want)))
  end
end

local base = vim.fn.tempname()
local function crea(rel) vim.fn.mkdir(base .. "/" .. rel, "p") end

print("--- dove sta il repository di un progetto ---")
-- Il caso da cui e' nato: una cartella di progetto con i documenti e, un
-- livello sotto, l'app con il suo .git. Aggiunta dalla radice non mostrava
-- ne' commit ne' autori.
crea("manuale/app/.git"); crea("manuale/specimen")
check("repository nella cartella stessa", P.git_root(base .. "/manuale/app"), base .. "/manuale/app")
check("una sola sottocartella con .git", P.git_root(base .. "/manuale"), base .. "/manuale/app")

-- Due candidati: non si sceglie a caso, resta senza repository come prima.
crea("doppio/sito/.git"); crea("doppio/server/.git")
check("due sottocartelle git: nessuna scelta", P.git_root(base .. "/doppio"), nil)

-- Le cartelle nascoste e quelle ignorate non contano come candidati.
crea("nascosto/.cache/.git"); crea("nascosto/node_modules/pkg/.git"); crea("nascosto/node_modules/.git")
check("cartelle nascoste o ignorate escluse", P.git_root(base .. "/nascosto"), nil)

-- Si guarda un solo livello sotto: un repository piu' in profondita' no.
crea("profondo/a/b/.git")
check("solo un livello sotto", P.git_root(base .. "/profondo"), nil)

check("cartella senza nessun repository", P.git_root(base .. "/manuale/specimen"), nil)
check("percorso inesistente", P.git_root(base .. "/non-esiste"), nil)
check("percorso vuoto", P.git_root(""), nil)

vim.fn.delete(base, "rf")
print(string.format("\nrisultato: %d passati, %d falliti", ok, ko))
vim.cmd(ko == 0 and "qa!" or "cq")
