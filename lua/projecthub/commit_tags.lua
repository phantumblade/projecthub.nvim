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

--- Gerarchia cromatica: il colore dice che *tipo* di rischio o di lavoro
--- rappresenta il commit, non solo che è diverso dagli altri.
---   rosso/magenta  = qualcosa era rotto, o si rompe adesso
---   verde          = capacità nuove
---   ambra/oro      = comportamento modificato, prestazioni
---   blu/ciano      = informazione e verifica (docs, test, CI)
---   viola/grigio   = manutenzione, nessun effetto sull'utente
M.COLORS = {
  BREAKING = "#ff4d9d", -- il più acceso della tavolozza: rompe le compatibilità
  SECURITY = "#ff757f",
  FIX      = "#f7768e",
  REVERT   = "#ff966c",
  FEAT     = "#73daca",
  CHANGE   = "#ff9e64",
  PERF     = "#ffc777",
  DOCS     = "#e0af68",
  TEST     = "#7dcfff",
  CI       = "#82aaff",
  BUILD    = "#4fd6be",
  DEPS     = "#c3e88d",
  REFACTOR = "#b4f9f8",
  STYLE    = "#fca7ea",
  CHORE    = "#bb9af7",
  INIT     = "#c8d3f5",
  MERGE    = "#86e1fc",
  WIP      = "#949dd4", -- volutamente spento: non è lavoro finito
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

--- Definisce i gruppi: testo acceso su sfondo tenue dello stesso colore.
function M.set_hl()
  for tag, fg in pairs(M.COLORS) do
    vim.api.nvim_set_hl(0, M.hl_group(tag), {
      fg = fg,
      bg = blend(fg, 0.16), -- abbastanza da leggersi come pillola, non tanto da sbiadire il testo
      bold = true,
    })
  end
  vim.api.nvim_set_hl(0, "ProjectsTagScope", { fg = "#545c7e", italic = true })
end

return M
