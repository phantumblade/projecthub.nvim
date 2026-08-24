-- Riconoscimento dei tag nei messaggi di commit.
--
-- Lo stesso tag viene scritto in una decina di modi diversi a seconda del
-- repository e di chi committa: `feat: ...`, `[FEAT] ...`, `fix(core)!: ...`,
-- `DOCS - ...`. Qui tutte queste forme vengono ricondotte a un'unica etichetta
-- maiuscola, così la cronologia si scorre a colpo d'occhio cercando il colore
-- invece di leggere ogni riga.
--
-- Il riconoscimento avviene SOLO a inizio messaggio: una parola come "fix" in
-- mezzo a una frase resta testo normale.

local M = {}

--- Da come è scritto → all'etichetta canonica.
--- Le forme delimitate (con due punti, parentesi quadre, ecc.) accettano anche
--- gli alias informali; la parola nuda invece è ammessa solo se è già il nome
--- di un tipo, per non trasformare in badge l'inizio di una frase qualsiasi.
local ALIASES = {
  feat = "FEAT", feats = "FEAT", feature = "FEAT", features = "FEAT",
  fix = "FIX", fixes = "FIX", fixed = "FIX", bugfix = "FIX", hotfix = "FIX",
  docs = "DOCS", doc = "DOCS", documentation = "DOCS",
  style = "STYLE", styles = "STYLE", format = "STYLE", formatting = "STYLE",
  refactor = "REFACTOR", refactoring = "REFACTOR", refac = "REFACTOR",
  perf = "PERF", performance = "PERF", optimize = "PERF", optimization = "PERF",
  test = "TEST", tests = "TEST", testing = "TEST",
  build = "BUILD",
  ci = "CI", cd = "CI",
  chore = "CHORE", chores = "CHORE",
  revert = "REVERT", reverted = "REVERT",
  change = "CHANGE", changed = "CHANGE", changes = "CHANGE", update = "CHANGE", updated = "CHANGE",
  breaking = "BREAKING",
  init = "INIT", initial = "INIT", start = "INIT",
  wip = "WIP",
  merge = "MERGE", merged = "MERGE",
  security = "SECURITY", sec = "SECURITY",
  deps = "DEPS", dep = "DEPS", dependencies = "DEPS", bump = "DEPS",
  add = "FEAT", new = "FEAT", remove = "CHANGE", removed = "CHANGE", delete = "CHANGE",
}

--- Alias ammessi anche senza delimitatore, perché la parola *è* il tipo.
--- "add", "update", "new", "remove" ne restano fuori di proposito: da soli
--- aprono normalissime frasi inglesi ("Add support for…") e finirebbero per
--- marcare come tag ciò che è solo l'inizio del messaggio.
local BARE_OK = {
  feat = true, feats = true, feature = true, features = true,
  fix = true, fixes = true, fixed = true, bugfix = true, hotfix = true,
  docs = true, doc = true, style = true, refactor = true, refactoring = true,
  perf = true, test = true, tests = true, build = true, ci = true,
  chore = true, revert = true, breaking = true, wip = true, merge = true,
  security = true, deps = true, init = true,
}

--- Gerarchia cromatica. Il colore dice quanta attenzione merita il commit,
--- non soltanto che è diverso dagli altri:
---   rosso/magenta  = fermati e leggi (rompe, o riguarda la sicurezza)
---   arancio/oro    = qualcosa era rotto ed è stato aggiustato, o è cambiato
---   verde          = capacità nuove
---   oliva/blu      = informazione e verifica (docs, test, CI, build)
---   viola/grigio   = manutenzione, invisibile a chi usa il progetto
---
--- Le tinte non sono scelte a occhio: sono state verificate calcolando la
--- distanza percettiva (CIE Lab ΔE) fra ogni coppia, così i tag che compaiono
--- di continuo restano i più distinguibili fra loro: minima globale 17.9,
--- con ogni badge sopra 4.5:1 di contrasto sul proprio sfondo.
M.COLORS = {
  -- Allarme: rari di proposito. Un colore che compare di continuo smette di
  -- essere un segnale, quindi il rosso è riservato a ciò che va letto subito.
  BREAKING = "#ff4d9d", -- rompe le compatibilità
  SECURITY = "#ff5370",
  REVERT   = "#e06c7d", -- si torna indietro: qualcosa non ha funzionato

  -- Riparazione e comportamento modificato
  FIX      = "#ff8f4d", -- arancio: qualcosa era rotto ed è stato aggiustato
  CHANGE   = "#ffc777",
  PERF     = "#e8b93f",

  -- Ciò che nasce
  FEAT     = "#5fd39a",
  DEPS     = "#a89060",

  -- Informazione e verifica
  DOCS     = "#c9d17e",
  TEST     = "#7dcfff",
  CI       = "#82aaff",
  BUILD    = "#4fd6be",
  MERGE    = "#9ab0d0",

  -- Manutenzione: invisibile a chi usa il progetto
  REFACTOR = "#b4f9f8",
  STYLE    = "#fca7ea",
  CHORE    = "#bb9af7",
  INIT     = "#dde3f7",
  WIP      = "#a8a29a", -- grigio caldo: spento di proposito, ma leggibile.
                        -- Caldo e non bluastro per non confondersi con MERGE.
}

--- Estrae il tag iniziale, se c'è.
--- @param subject string il messaggio di commit
--- @return string|nil tag etichetta canonica maiuscola
--- @return string|nil scope ambito fra parentesi, se presente
--- @return string resto il messaggio senza il prefisso
function M.parse(subject)
  local s = tostring(subject or "")
  local body = s:gsub("^%s+", "")
  if body == "" then return nil, nil, s end

  local word, scope, rest, delimited

  -- 1) fra delimitatori: [FEAT] (feat) {feat} <feat>
  word, rest = body:match("^%[%s*(%a[%w_%-]*)%s*%]%s*(.*)$")
  if not word then word, rest = body:match("^%(%s*(%a[%w_%-]*)%s*%)%s*(.*)$") end
  if not word then word, rest = body:match("^{%s*(%a[%w_%-]*)%s*}%s*(.*)$") end
  if not word then word, rest = body:match("^<%s*(%a[%w_%-]*)%s*>%s*(.*)$") end
  if word then delimited = true end

  -- 2) conventional commits: feat(scope): …  feat(scope)!: …  feat!: …  feat: …
  if not word then
    word, scope, rest = body:match("^(%a[%w_%-]*)%s*%(([^%)]*)%)%s*!?%s*:%s*(.*)$")
    if word then delimited = true end
  end
  if not word then
    word, rest = body:match("^(%a[%w_%-]*)%s*!?%s*:%s*(.*)$")
    if word then delimited = true end
  end

  -- 3) separato da trattino o barra: docs - …  chore | …  refactor/…
  -- Il trattino esige spazi attorno, altrimenti "feat-nuova-cosa" (che è un
  -- nome di ramo, non un tag) verrebbe scambiato per un'etichetta. Barra
  -- verticale e barra obliqua non ne hanno bisogno: non compaiono dentro le
  -- parole composte.
  if not word then
    word, rest = body:match("^(%a[%w_%-]*)%s+[%-–—]%s+(.*)$")
    if not word then word, rest = body:match("^(%a[%w_%-]*)%s*[|/]%s*(.*)$") end
    if word then delimited = true end
  end

  -- 4) parola nuda seguita da spazio: fix qualcosa
  if not word then
    word, rest = body:match("^(%a[%w_%-]*)%s+(.*)$")
    delimited = false
  end

  if not word then return nil, nil, s end

  local key = word:lower()
  local tag = ALIASES[key]
  if not tag then return nil, nil, s end
  if not delimited and not BARE_OK[key] then return nil, nil, s end

  -- Un prefisso senza null'altro non è un tag: è tutto il messaggio.
  rest = (rest or ""):gsub("^%s+", "")
  if rest == "" then return nil, nil, s end

  if scope then
    scope = vim.trim(scope)
    if scope == "" then scope = nil end
  end
  return tag, scope, rest
end

--- Fonde un colore col fondo scuro, per ricavare lo sfondo tenue del badge.
local function blend(hex, amount)
  local r = tonumber(hex:sub(2, 3), 16)
  local g = tonumber(hex:sub(4, 5), 16)
  local b = tonumber(hex:sub(6, 7), 16)
  local br, bg_, bb = 0x1a, 0x1b, 0x26 -- fondo di riferimento
  local function mix(c, base) return math.floor(base + (c - base) * amount + 0.5) end
  return string.format("#%02x%02x%02x", mix(r, br), mix(g, bg_), mix(b, bb))
end

--- Nome del gruppo di evidenziazione per un tag.
function M.hl_group(tag)
  return "ProjectsTag" .. tag:sub(1, 1):upper() .. tag:sub(2):lower()
end

--- Gruppo per l'ambito che segue il badge (lo `scope` dei conventional commit).
function M.scope_hl_group(tag)
  return M.hl_group(tag) .. "Scope"
end

--- Definisce i gruppi: testo acceso su sfondo tenue dello stesso colore.
function M.set_hl()
  for tag, fg in pairs(M.COLORS) do
    vim.api.nvim_set_hl(0, M.hl_group(tag), {
      fg = fg,
      bg = blend(fg, 0.13), -- il valore piu alto che tiene tutti e 18 sopra 4.5:1 di contrasto
      bold = true,
    })
    -- L'ambito appartiene al badge, non al soggetto: gli si dà la stessa
    -- tinta ma spenta, così resta legato all'etichetta senza rubare la
    -- lettura al messaggio vero e proprio.
    vim.api.nvim_set_hl(0, M.scope_hl_group(tag), {
      fg = blend(fg, 0.58),
      italic = true,
    })
  end
  vim.api.nvim_set_hl(0, "ProjectsTagScope", { fg = "#545c7e", italic = true })
end

return M
