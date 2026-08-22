local M = {}

--- Configurazione di default. Sovrascrivibile tramite require("projecthub").setup({...}).
M.defaults = {
  -- Lingua dell'interfaccia: "it" oppure "en". Cambiabile a runtime con
  -- require("projecthub").set_language("it"|"en"), o dal tasto L nella
  -- dashboard stessa.
  language = "en",

  -- Cartelle-contenitore da scansionare per trovare progetti.
  -- { percorso, profondita_di_scansione }
  roots = {},

  -- Progetti singoli specifici, fuori dai contenitori principali.
  extra = {},

  -- Chi sei: separa i tuoi progetti da quelli clonati da altri
  -- (in base al proprietario del repository su GitHub/origin).
  me = {
    owners = {},
  },

  -- Icone per Proprietario, Organizzazione, Collaboratore e Fork (badge nell'ispettore).
  icons = {
    owner = "\u{edeb} ", -- nf-fa-crown
    org = "\u{f42b} ", -- nf-oct-organization
    member = "\u{f0009} ", -- nf-md-account
    fork = "\u{ea63} ", -- nf-cod-repo_forked
  },

  -- Dimensioni e proporzioni della finestra.
  window = {
    width = 0.90,
    height = 0.85,
    left_ratio = 0.48, -- quota lista schede vs anteprima
    min_card = 38, -- punto di equilibrio ideale: 2 colonne per finestre normali, 1 colonna un pelino prima quando si stringe o zoomma
  },

  -- Effetti sonori dell'interfaccia (libreria uisfx - preset minimal).
  sound = {
    enabled = true, -- true per attivare i suoni, false per disattivarli
    volume = 0.5,   -- volume da 0.0 a 1.0
  },

  -- Callback invocata quando apri un progetto (tasto Enter). Riceve il
  -- percorso assoluto. Se nil, usa il comportamento di default: `tcd` nella
  -- cartella, poi ripristina la sessione con persistence.nvim se disponibile,
  -- altrimenti apre Neo-tree (entrambi opzionali, nessun errore se assenti).
  on_open = nil,
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M
