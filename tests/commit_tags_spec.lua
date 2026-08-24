vim.opt.runtimepath:append(vim.fn.getcwd())
local T = require("projecthub.commit_tags")
local ok, ko = 0, 0
local function check(input, want_tag, want_scope, want_rest)
  local tag, scope, rest = T.parse(input)
  local good = (tag == want_tag) and (scope == want_scope)
      and (want_rest == nil or rest == want_rest)
  if good then ok = ok + 1 else
    ko = ko + 1
    print(string.format("  FALLITO  %-42s -> tag=%s scope=%s rest=%q  (atteso tag=%s scope=%s)",
      '"'..input..'"', tostring(tag), tostring(scope), tostring(rest), tostring(want_tag), tostring(want_scope)))
  end
end

print("--- forme che DEVONO essere riconosciute ---")
check("feat: aggiunge il pannello",            "FEAT", nil)
check("feat(inspector): ripristina la vista",  "FEAT", "inspector")
check("fix(core)!: rompe le API",              "FIX",  "core")
check("feat!: cambia tutto",                   "FEAT", nil)
check("[FEAT] aggiunge il pannello",           "FEAT", nil)
check("[ fix ] risolve il crash",              "FIX",  nil)
check("(docs) aggiorna il readme",             "DOCS", nil)
check("{chore} pulizia",                       "CHORE", nil)
check("<test> copertura",                      "TEST", nil)
check("FIX: rotto",                            "FIX",  nil)
check("Docs - aggiorna guida",                 "DOCS", nil)
check("chore | pulizia",                       "CHORE", nil)
check("refactor/estrae il modulo",             "REFACTOR", nil)
check("fix risolve il crash",                  "FIX",  nil)
check("HOTFIX: patch urgente",                 "FIX",  nil)
check("BREAKING CHANGE: rimuove opzione",      "BREAKING", nil)
check("perf(ui): riduce i ridisegni",          "PERF", "ui")
check("bump: dipendenze aggiornate",           "DEPS", nil)
check("Merge branch 'main'",                   "MERGE", nil)
check("wip qualcosa",                          "WIP",  nil)
check("[SETUP] aggiunge controlli just",       "SETUP", nil)
check("setup di Firebase e Maps API",          "SETUP", nil)
check("setup(ci): cache dei runner",           "SETUP", "ci")
check("bootstrap - primo ambiente",            "SETUP", nil)
check("Fixing della vecchia preview",          "FIX",  nil)

print("--- forme che NON devono diventare badge ---")
check("risolve il feat mancante",              nil, nil)
check("Aggiunge il supporto per i tag",        nil, nil)
check("Add support for tags",                  nil, nil)   -- 'add' nudo: troppo generico
check("Update the readme",                     nil, nil)   -- 'update' nudo: idem
check("il fix era sbagliato",                  nil, nil)
check("fix",                                   nil, nil)   -- solo il tag, nessun messaggio
check("",                                      nil, nil)
check("Revert \"feat: qualcosa\"",             "REVERT", nil)  -- questo invece sì

print("--- alias informali SOLO se delimitati ---")
check("[add] nuova funzione",                  "FEAT", nil)
check("update: rinfresca la cache",            "CHANGE", nil)
check("[config] regole eslint",                "SETUP", nil)
check("config del linter sbagliata",           nil, nil)   -- 'config' nudo: e' un sostantivo

print(string.format("\nrisultato: %d passati, %d falliti", ok, ko))
vim.cmd(ko == 0 and "qa!" or "cq")
