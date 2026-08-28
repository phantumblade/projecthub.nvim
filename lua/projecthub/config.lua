local M = {}

local SETTINGS_FILE = vim.fn.stdpath("data") .. "/projecthub/settings.json"

local function load_persisted_settings()
  if vim.fn.filereadable(SETTINGS_FILE) == 0 then return {} end
  local ok, lines = pcall(vim.fn.readfile, SETTINGS_FILE)
  if not ok or not lines or #lines == 0 then return {} end
  local ok_json, data = pcall(vim.json.decode, table.concat(lines, "\n"))
  return (ok_json and type(data) == "table") and data or {}
end

function M.save_setting(key, val)
  local data_dir = vim.fn.stdpath("data") .. "/projecthub"
  vim.fn.mkdir(data_dir, "p")
  local current = load_persisted_settings()
  current[key] = val
  pcall(vim.fn.writefile, { vim.json.encode(current) }, SETTINGS_FILE)
end

function M.get_setting(key)
  local current = load_persisted_settings()
  return current[key]
end

--- Lingua suggerita dal sistema, se riconosciuta fra quelle tradotte.
--- Ordine di precedenza: opzione `language` di setup() > scelta salvata
--- dall'utente col tasto L > locale di sistema > inglese.
local function detect_system_language()
  local raw = vim.v.lang
  if raw == nil or raw == "" then
    raw = os.getenv("LC_ALL") or os.getenv("LC_MESSAGES") or os.getenv("LANG") or ""
  end
  local code = tostring(raw):lower():match("^(%a%a)") or ""
  if code == "it" then return "it" end
  return "en"
end

--- Configurazione di default. Sovrascrivibile tramite require("projecthub").setup({...}).
M.defaults = {
  -- Lingua dell'interfaccia: "it" oppure "en". Se non specificata viene dedotta
  -- dalla locale di sistema (ripiegando su "en"). Cambiabile a runtime con
  -- require("projecthub").set_language("it"|"en"), o dal tasto L nella
  -- dashboard stessa. Le preferenze vengono salvate su disco e persistite tra riavvii.
  language = detect_system_language(),

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
    member = "\u{f007} ", -- nf-fa-user
    fork = "\u{ea63} ", -- nf-cod-repo_forked
    ai = "\u{f51b} ", -- nf-oct-sparkle_fill: assistenti (Claude, Copilot, ...)
    bot = "\u{f06a9} ", -- nf-md-robot: pipeline e bot (CI, dependabot, ...)
    -- Campanella delle notifiche, accanto al titolo della cronologia. La barra
    -- obliqua e' il segno piu' immediato per "muto", percio' la coppia resta
    -- campanella / campanella sbarrata. Entrambe della famiglia Material: le
    -- corrispondenti Font Awesome sono larghe quasi due celle e sbordavano
    -- fino ad addossarsi al badge del tasto.
    bell_on = "\u{f009a}",  -- nf-md-bell
    bell_off = "\u{f009b}", -- nf-md-bell_off
  },

  -- Nomi aggiuntivi da trattare come non umani, oltre a quelli riconosciuti di
  -- serie. Il confronto e' per parole intere sul nome dell'autore, quindi qui
  -- basta il termine: { ai = { "atlas" }, bot = { "deploybot" } }.
  bots = {
    ai = {},
    bot = {},
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
    enabled = true, -- true per attivare i suoni, false per disattivarli (salvato su disco)
    volume = 0.40,  -- volume morbido e bilanciato da 0.0 a 1.0
  },

  -- Sorveglianza delle stelle sui tuoi repository GitHub. Richiede la CLI `gh`
  -- autenticata (`gh auth login`). Quando uno dei tuoi repo riceve una stella
  -- compare un riquadro in alto a destra accompagnato dal suono "achievement".
  stars = {
    enabled = false,   -- true per avviare la sorveglianza all'apertura di Neovim
    interval = 120,    -- secondi fra un controllo e l'altro (minimo 30)
    scope = "owner",   -- quali repo sorvegliare:
                       --   "owner"       solo quelli che possiedi (più economico)
                       --   "contributor" i tuoi, più quelli altrui in cui hai
                       --                 almeno un commit (collaboratore attivo)
                       --   "all"         tutto ciò a cui hai accesso
    owners = {},       -- account da sorvegliare; vuoto = quello autenticato con gh
    color = "#E3B341", -- colore d'accento del riquadro (bordo, titolo, stella)
    title = nil,       -- testo del titolo; nil = usa quello tradotto
    sound = "achievement", -- nome del suono, oppure false per notificare in silenzio
  },

  -- Commit in arrivo dai collaboratori. La cronologia mostra sempre i commit
  -- del repository locale; quando su upstream ne compaiono di piu' recenti, un
  -- `git fetch` di sfondo li rileva e l'ispettore li elenca sopra un divider,
  -- separati dal punto in cui sei sincronizzato. Il fetch aggiorna solo i
  -- riferimenti remoti: HEAD, indice e working tree non vengono mai toccati.
  incoming = {
    enabled = true,  -- false per non interrogare mai la rete
    interval = 300,  -- secondi fra due fetch dello stesso repository (minimo 60)
    timeout = 15,    -- secondi oltre i quali un fetch bloccato viene abbandonato
    notify = true,   -- avvisa quando compaiono commit nuovi
    -- Oltre questo numero di autori un progetto viene seguito in silenzio e da
    -- lontano: tante firme significano quasi sempre un repository altrui che
    -- hai clonato, dove un commit nuovo non e' una notizia che ti riguarda.
    -- Il divider continua comunque a comparire. Il tasto b nella dashboard
    -- forza la scelta per il singolo progetto, in entrambe le direzioni.
    notify_max_authors = 5,
  },

  -- Callback invocata quando apri un progetto (tasto Enter). Riceve il
  -- percorso assoluto. Se nil, usa il comportamento di default: `tcd` nella
  -- cartella, poi ripristina la sessione con persistence.nvim se disponibile,
  -- altrimenti apre Neo-tree (entrambi opzionali, nessun errore se assenti).
  on_open = nil,
}

-- Inizializza options con i default e ripristina all'istante le preferenze salvate su disco
local initial_persisted = load_persisted_settings()
M.options = vim.deepcopy(M.defaults)
if initial_persisted.language ~= nil then
  M.options.language = initial_persisted.language
end
if initial_persisted.sound_enabled ~= nil then
  M.options.sound.enabled = (initial_persisted.sound_enabled == true)
end

function M.setup(opts)
  local persisted = load_persisted_settings()
  local merged = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})

  -- Le preferenze utente modificate a runtime hanno la precedenza e restano salvate
  if persisted.language ~= nil and (not opts or opts.language == nil) then
    merged.language = persisted.language
  end
  if persisted.sound_enabled ~= nil and (not opts or not opts.sound or opts.sound.enabled == nil) then
    merged.sound.enabled = (persisted.sound_enabled == true)
  end

  M.options = merged
end

return M
