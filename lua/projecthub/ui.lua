-- Schermata progetti: ricerca in alto, schede su due colonne a sinistra,
-- anteprima del README (o albero delle cartelle) a destra.
local P = require("projecthub.projects")
local config = require("projecthub.config")
local i18n = require("projecthub.i18n")
local sound = require("projecthub.sound")
local commit_tags = require("projecthub.commit_tags")

local ICON_ERROR = "\u{f0156}"
local ICON_SUCCESS = "\u{f012c}"
local ICON_WARN = "\u{f0028}"
local ICON_GLOBE = "\u{f059f}"
local ICON_LOCK = "\u{f033e}"
local ICON_DOC = "\u{f0219}"
local ICON_FOLDER = "\u{f024f}"
local ICON_GIT = "\u{f02a2}"
local ICON_CLOCK = "\u{f00ed}"
local ICON_TEAM = "\u{f04d3}"
local ICON_NOTE = "\u{f082e}"
local ICON_FOLDER_INSPECT = "\u{f02dc}"
local ICON_RELOCATE = "\u{f06d2}"
local ICON_GITHUB = "\u{f02a4}"
local ICON_ADD = "\u{f03d4}"
local ICON_HISTORY = "\u{f02da}"
local ICON_OVERVIEW = "\u{e66a}"
local ICON_TRASH = "\u{f0a79}"
local ICON_UP_DIR = "\u{f005d}"
local ICON_STAR = "\u{f005}" -- nf-fa-star
local ICON_SYNCED = "\u{e63f}" -- nf-seti-checkbox

local M = {
  active_st = nil,
}

function M.is_open()
  return M.active_st and M.active_st.list and vim.api.nvim_win_is_valid(M.active_st.list.win)
end

local ns = vim.api.nvim_create_namespace("projecthub")
local ns_html = vim.api.nvim_create_namespace("projecthub_html")
local ns_sb = vim.api.nvim_create_namespace("projecthub_scrollbar")
local ns_psb = vim.api.nvim_create_namespace("projecthub_preview_scrollbar")
local ns_input = vim.api.nvim_create_namespace("projecthub_input")
local ns_ghost = vim.api.nvim_create_namespace("projecthub_ghost")
local CARD_ROWS = 8

M.config = {
  width = config.options.window.width,
  height = config.options.window.height,
  left_ratio = config.options.window.left_ratio,
  min_card = config.options.window.min_card,
  preview_lines = 400,
}

-- Icone per Proprietario, Organizzazione, Contributor e Fork (personalizzabili via setup()).
M.OWNER_ICON = config.options.icons.owner
M.ORG_ICON = config.options.icons.org
M.MEMBER_ICON = config.options.icons.member
M.FORK_ICON = config.options.icons.fork
M.AI_ICON = config.options.icons.ai
M.BOT_ICON = config.options.icons.bot
M.BELL_ON_ICON = config.options.icons.bell_on
M.BELL_OFF_ICON = config.options.icons.bell_off

local VISIBILITY_TOKENS = {
  pubblico = { type = "public", name = ICON_GLOBE .. " PUBBLICO", hl = "ProjectsHeaderPublic" },
  public = { type = "public", name = ICON_GLOBE .. " PUBLIC", hl = "ProjectsHeaderPublic" },
  privato = { type = "private", name = ICON_LOCK .. " PRIVATO", hl = "ProjectsHeaderPrivate" },
  private = { type = "private", name = ICON_LOCK .. " PRIVATE", hl = "ProjectsHeaderPrivate" },
  locale = { type = "local", name = ICON_FOLDER .. " LOCALE", hl = "ProjectsHeaderLocal" },
  locali = { type = "local", name = ICON_FOLDER .. " LOCALI", hl = "ProjectsHeaderLocal" },
  ["local"] = { type = "local", name = ICON_FOLDER .. " LOCAL", hl = "ProjectsHeaderLocal" },
  locals = { type = "local", name = ICON_FOLDER .. " LOCALS", hl = "ProjectsHeaderLocal" },
  untracked = { type = "local", name = ICON_FOLDER .. " UNTRACKED", hl = "ProjectsHeaderLocal" },
  unversioned = { type = "local", name = ICON_FOLDER .. " UNVERSIONED", hl = "ProjectsHeaderLocal" },
  nonversionato = { type = "local", name = ICON_FOLDER .. " NON VERSIONATO", hl = "ProjectsHeaderLocal" },
  ["non-versionato"] = { type = "local", name = ICON_FOLDER .. " NON VERSIONATO", hl = "ProjectsHeaderLocal" },
  nonversionati = { type = "local", name = ICON_FOLDER .. " NON VERSIONATI", hl = "ProjectsHeaderLocal" },
  ["non-versionati"] = { type = "local", name = ICON_FOLDER .. " NON VERSIONATI", hl = "ProjectsHeaderLocal" },
}

-- Mappa di riconoscimento dei linguaggi per la ricerca (usa i badge ProjectsPill)
local LANG_TOKENS = {
  kotlin = { name = "Kotlin", hl = "ProjectsPillKotlin" },
  java = { name = "Java", hl = "ProjectsPillJava" },
  python = { name = "Python", hl = "ProjectsPillPython" },
  typescript = { name = "TypeScript", hl = "ProjectsPillTS" },
  ts = { name = "TypeScript", hl = "ProjectsPillTS" },
  javascript = { name = "JavaScript", hl = "ProjectsPillJS" },
  js = { name = "JavaScript", hl = "ProjectsPillJS" },
  go = { name = "Go", hl = "ProjectsPillGo" },
  golang = { name = "Go", hl = "ProjectsPillGo" },
  rust = { name = "Rust", hl = "ProjectsPillRust" },
  lua = { name = "Lua", hl = "ProjectsPillLua" },
  c = { name = "C", hl = "ProjectsPillC" },
  cpp = { name = "C++", hl = "ProjectsPillCPP" },
  ["c++"] = { name = "C++", hl = "ProjectsPillCPP" },
  swift = { name = "Swift", hl = "ProjectsPillSwift" },
  html = { name = "HTML", hl = "ProjectsPillHTML" },
  css = { name = "CSS", hl = "ProjectsPillCSS" },
  sql = { name = "SQL", hl = "ProjectsPillSQL" },
  vue = { name = "Vue", hl = "ProjectsPillVue" },
  svelte = { name = "Svelte", hl = "ProjectsPillSvelte" },
  astro = { name = "Astro", hl = "ProjectsPillAstro" },
  php = { name = "PHP", hl = "ProjectsPillPHP" },
  ruby = { name = "Ruby", hl = "ProjectsPillRuby" },
  rb = { name = "Ruby", hl = "ProjectsPillRuby" },
  ["c#"] = { name = "C#", hl = "ProjectsPillCSharp" },
  csharp = { name = "C#", hl = "ProjectsPillCSharp" },
  cs = { name = "C#", hl = "ProjectsPillCSharp" },
  dart = { name = "Dart", hl = "ProjectsPillDart" },
  zig = { name = "Zig", hl = "ProjectsPillZig" },
  markdown = { name = "Markdown", hl = "ProjectsPillMarkdown" },
  md = { name = "Markdown", hl = "ProjectsPillMarkdown" },
  shell = { name = "Shell", hl = "ProjectsPillShell" },
  bash = { name = "Shell", hl = "ProjectsPillShell" },
  android = { name = "Android", hl = "ProjectsType" },
  node = { name = "Node", hl = "ProjectsPillJS" },
}

--- Etichetta del tipo di progetto. Il tipo dedotto dai file di build e' il
--- dato piu' preciso; quando non c'e' - una cartella di appunti, un insieme di
--- esercizi senza file indicatori - si ripiega sul linguaggio dominante, che la
--- barra dei linguaggi ha gia' calcolato. Il colore resta uno solo per tutti:
--- e' un'etichetta, non un semaforo.
---
--- "Markdown" e' escluso di proposito. Non viene riconosciuto insieme agli
--- altri linguaggi - in LANG_MAP non c'e' - ma da un ramo a parte, che scatta
--- solo quando nel progetto di codice non ce n'e': e' il segnaposto per "qui ci
--- sono soltanto appunti". Etichettare una cartella di note come "Markdown"
--- riempirebbe il badge senza dire niente, e nessun badge e' piu' onesto.
--- @return string|nil
local function type_label(p)
  if p.type then return p.type end
  for _, l in ipairs(p.languages or {}) do
    if l.name and l.name ~= "Markdown" then return l.name end
  end
  return nil
end

-- Font a blocchi per una parola sola, resa in grande al centro del pannello.
-- Stesso tratto della scritta d'apertura, cosi' gli stati che meritano di
-- essere gridati parlano con la stessa voce. Ci sono soltanto le lettere che
-- servono agli stati esistenti: aggiungerne altre e' un attimo, riempire la
-- tabella con l'alfabeto intero per usarne dieci no.
local BIG_FONT = {
  A = { " █████╗ ", "██╔══██╗", "███████║", "██╔══██║", "██║  ██║", "╚═╝  ╚═╝" },
  C = { " ██████╗", "██╔════╝", "██║     ", "██║     ", "╚██████╗", " ╚═════╝" },
  E = { "███████╗", "██╔════╝", "█████╗  ", "██╔══╝  ", "███████╗", "╚══════╝" },
  F = { "███████╗", "██╔════╝", "█████╗  ", "██╔══╝  ", "██║     ", "╚═╝     " },
  G = { " ██████╗ ", "██╔════╝ ", "██║  ███╗", "██║   ██║", "╚██████╔╝", " ╚═════╝ " },
  I = { "██╗", "██║", "██║", "██║", "██║", "╚═╝" },
  L = { "██╗     ", "██║     ", "██║     ", "██║     ", "███████╗", "╚══════╝" },
  N = { "███╗   ██╗", "████╗  ██║", "██╔██╗ ██║", "██║╚██╗██║", "██║ ╚████║", "╚═╝  ╚═══╝" },
  O = { " ██████╗ ", "██╔═══██╗", "██║   ██║", "██║   ██║", "╚██████╔╝", " ╚═════╝ " },
  S = { "███████╗", "██╔════╝", "███████╗", "╚════██║", "███████║", "╚══════╝" },
  T = { "████████╗", "╚══██╔══╝", "   ██║   ", "   ██║   ", "   ██║   ", "   ╚═╝   " },
  [" "] = { "   ", "   ", "   ", "   ", "   ", "   " },
}

--- Compone una parola nel font a blocchi.
--- @return table|nil sei righe, oppure nil se una lettera manca dalla tabella
local function big_word(word)
  local rows = { "", "", "", "", "", "" }
  for ch in tostring(word):upper():gmatch(".") do
    local g = BIG_FONT[ch]
    if not g then return nil end
    for i = 1, 6 do rows[i] = rows[i] .. g[i] end
  end
  return rows
end

local render_list, render_preview, render_scrollbar, render_preview_scrollbar
local scroll_preview, ensure_visible, sync_sel_with_scroll, refresh
local move, filter, reapply, card_at_mouse

local dw = vim.fn.strdisplaywidth

local function fmt_num(num)
  if not num then return nil end
  local str = tostring(num):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
  return str
end

local function wrap_text(str, max_width)
  if not str or str == "" then return {} end
  local lines = {}
  for _, raw_line in ipairs(vim.split(str, "\n")) do
    local words = {}
    for w in raw_line:gmatch("%S+") do
      words[#words + 1] = w
    end
    if #words == 0 then
      lines[#lines + 1] = ""
    else
      local cur_line = words[1]
      for i = 2, #words do
        local word = words[i]
        if dw(cur_line) + 1 + dw(word) <= max_width then
          cur_line = cur_line .. " " .. word
        else
          lines[#lines + 1] = cur_line
          cur_line = word
        end
      end
      lines[#lines + 1] = cur_line
    end
  end
  return lines
end

local function set_hl()
  local hl = {
    ProjectsBorder = "FloatBorder",
    ProjectsBorderSel = "SnacksDashboardKey",
    ProjectsName = "Title",
    ProjectsNameSel = "SnacksDashboardKey",
    ProjectsType = "SnacksDashboardIcon",
    ProjectsDesc = "Comment",
    ProjectsDir = "SnacksDashboardDir",
    ProjectsMeta = "NonText",
    ProjectsGitBranch = "Special",
    ProjectsGitDirty = "DiagnosticWarn",
    ProjectsGitStaged = "DiagnosticInfo",
    ProjectsGitNew = "DiagnosticHint",
    ProjectsGitConflict = "DiagnosticError",
    ProjectsGitSync = "DiagnosticInfo",
    ProjectsTreeDir = "Directory",
    ProjectsScrollbarThumb = "DiagnosticWarn",
    ProjectsGhostText = "Comment",
  }

  vim.api.nvim_set_hl(0, "ProjectsGhostText", { fg = "#5c6370", italic = true, default = true })

  -- Etichette dei commit: testo acceso su sfondo tenue dello stesso colore.
  commit_tags.set_hl()

  -- Spunta "in pari con il remoto": verde fisso in ogni tema, così il segnale
  -- di sincronizzazione resta riconoscibile a colpo d'occhio.
  vim.api.nvim_set_hl(0, "ProjectsGitClean", { fg = "#3FB950", bold = true })

  for from, to in pairs(hl) do
    vim.api.nvim_set_hl(0, from, { link = to, default = true })
  end

  -- Traccia della barra di scorrimento ardesia tenue (#3E4452)
  vim.api.nvim_set_hl(0, "ProjectsScrollbarTrack", {
    fg = "#3E4452",
    default = false,
  })

  -- Palette per le schede dei progetti (RIGOROSAMENTE SENZA SFONDO BG!)
  local lang_hls = {
    ProjectsLangKotlin = { fg = "#A97BFF", bold = true, undercurl = false, sp = nil },
    ProjectsLangJava = { fg = "#E5A000", bold = true, undercurl = false, sp = nil },
    ProjectsLangPython = { fg = "#4B8BBE", bold = true, undercurl = false, sp = nil },
    ProjectsLangTS = { fg = "#3178C6", bold = true, undercurl = false, sp = nil },
    ProjectsLangJS = { fg = "#E5C07B", bold = true, undercurl = false, sp = nil },
    ProjectsLangGo = { fg = "#00ADD8", bold = true, undercurl = false, sp = nil },
    ProjectsLangRust = { fg = "#DEA584", bold = true, undercurl = false, sp = nil },
    ProjectsLangLua = { fg = "#51A0D5", bold = true, undercurl = false, sp = nil },
    ProjectsLangC = { fg = "#7F8C8D", bold = true, undercurl = false, sp = nil },
    ProjectsLangCPP = { fg = "#F34B7D", bold = true, undercurl = false, sp = nil },
    ProjectsLangSwift = { fg = "#F05138", bold = true, undercurl = false, sp = nil },
    ProjectsLangHTML = { fg = "#E34C26", bold = true, undercurl = false, sp = nil },
    ProjectsLangCSS = { fg = "#9B59B6", bold = true, undercurl = false, sp = nil },
    ProjectsLangSQL = { fg = "#E38C00", bold = true, undercurl = false, sp = nil },
    ProjectsLangVue = { fg = "#41B883", bold = true, undercurl = false, sp = nil },
    ProjectsLangSvelte = { fg = "#FF3E00", bold = true, undercurl = false, sp = nil },
    ProjectsLangAstro = { fg = "#FF5D01", bold = true, undercurl = false, sp = nil },
    ProjectsLangPHP = { fg = "#777BB4", bold = true, undercurl = false, sp = nil },
    ProjectsLangRuby = { fg = "#CC342D", bold = true, undercurl = false, sp = nil },
    ProjectsLangCSharp = { fg = "#178600", bold = true, undercurl = false, sp = nil },
    ProjectsLangDart = { fg = "#00B4AB", bold = true, undercurl = false, sp = nil },
    ProjectsLangZig = { fg = "#EC915C", bold = true, undercurl = false, sp = nil },
    ProjectsLangMarkdown = { fg = "#61AFEF", bold = true, undercurl = false, sp = nil },
    ProjectsLangShell = { fg = "#2ECC71", bold = true, undercurl = false, sp = nil },
    ProjectsLangTrack = { fg = "#282C34" },

    -- Palette per i badge della barra di ricerca (SFONDO PILLOLA TENUE)
    ProjectsPillKotlin = { fg = "#A97BFF", bg = "#292038", bold = true, undercurl = false, sp = nil },
    ProjectsPillJava = { fg = "#E5A000", bg = "#332B1A", bold = true, undercurl = false, sp = nil },
    ProjectsPillPython = { fg = "#4B8BBE", bg = "#1F2C38", bold = true, undercurl = false, sp = nil },
    ProjectsPillTS = { fg = "#3178C6", bg = "#1B2A3B", bold = true, undercurl = false, sp = nil },
    ProjectsPillJS = { fg = "#E5C07B", bg = "#332F1E", bold = true, undercurl = false, sp = nil },
    ProjectsPillGo = { fg = "#00ADD8", bg = "#173138", bold = true, undercurl = false, sp = nil },
    ProjectsPillRust = { fg = "#DEA584", bg = "#382A25", bold = true, undercurl = false, sp = nil },
    ProjectsPillLua = { fg = "#51A0D5", bg = "#1E2F3A", bold = true, undercurl = false, sp = nil },
    ProjectsPillC = { fg = "#7F8C8D", bg = "#2B2E33", bold = true, undercurl = false, sp = nil },
    ProjectsPillCPP = { fg = "#F34B7D", bg = "#38202A", bold = true, undercurl = false, sp = nil },
    ProjectsPillSwift = { fg = "#F05138", bg = "#38211E", bold = true, undercurl = false, sp = nil },
    ProjectsPillHTML = { fg = "#E34C26", bg = "#38221D", bold = true, undercurl = false, sp = nil },
    ProjectsPillCSS = { fg = "#9B59B6", bg = "#2B2038", bold = true, undercurl = false, sp = nil },
    ProjectsPillSQL = { fg = "#E38C00", bg = "#33271A", bold = true, undercurl = false, sp = nil },
    ProjectsPillVue = { fg = "#41B883", bg = "#1B3329", bold = true, undercurl = false, sp = nil },
    ProjectsPillSvelte = { fg = "#FF3E00", bg = "#381F1A", bold = true, undercurl = false, sp = nil },
    ProjectsPillAstro = { fg = "#FF5D01", bg = "#38221A", bold = true, undercurl = false, sp = nil },
    ProjectsPillPHP = { fg = "#777BB4", bg = "#252638", bold = true, undercurl = false, sp = nil },
    ProjectsPillRuby = { fg = "#CC342D", bg = "#381E1D", bold = true, undercurl = false, sp = nil },
    ProjectsPillCSharp = { fg = "#178600", bg = "#1B331A", bold = true, undercurl = false, sp = nil },
    ProjectsPillDart = { fg = "#00B4AB", bg = "#173133", bold = true, undercurl = false, sp = nil },
    ProjectsPillZig = { fg = "#EC915C", bg = "#382B21", bold = true, undercurl = false, sp = nil },
    ProjectsPillMarkdown = { fg = "#61AFEF", bg = "#1F2B38", bold = true, undercurl = false, sp = nil },
    ProjectsPillShell = { fg = "#2ECC71", bg = "#1B3326", bold = true, undercurl = false, sp = nil },

  }

  -- Soft, subtle link & inline code background tint (SENZA BLOCCI INVASIVI)
  local rm_soft_links = {
    RenderMarkdownCodeInline = { fg = "#7EC7FF", bg = "#222938" },
    RenderMarkdownInline = { fg = "#7EC7FF", bg = "#222938" },
    RenderMarkdownLink = { fg = "#7EC7FF", bg = "#222938" },
    RenderMarkdownWikiLink = { fg = "#7EC7FF", bg = "#222938" },
    ["@markup.raw.inline"] = { fg = "#7EC7FF", bg = "#222938" },
    ["@markup.link.url"] = { fg = "#7EC7FF", bg = "#222938" },
  }

  for name, spec in pairs(rm_soft_links) do
    vim.api.nvim_set_hl(0, name, spec)
  end

  for name, spec in pairs(lang_hls) do
    vim.api.nvim_set_hl(0, name, vim.tbl_extend("force", spec, { default = false }))
  end

  local lazy_btn_hls = {
    ProjectsLazyBtnLabel = { fg = "#c0caf5", bg = "#293145", bold = false },
    ProjectsLazyBtnKey = { fg = "#7aa2f7", bg = "#3b4763", bold = true },
    ProjectsKeyText = { fg = "#7aa2f7", bold = true },

    ProjectsCommitHash = { fg = "#7aa2f7", bold = true },

    -- Commit presenti su upstream ma non ancora in locale. Restano in grigio,
    -- lo stesso delle date: sono identificatori che in locale non esistono
    -- ancora, quindi non devono richiamare l'occhio piu' della cronologia vera.
    -- L'arancione, oltre a gridare, prometteva un'urgenza che qui non c'e'.
    ProjectsIncomingHash = { fg = "#565f89" },
    ProjectsIncomingLabel = { fg = "#565f89" },
    ProjectsIncomingLine = { fg = "#3b4763" },

    -- Unita' esterna scollegata. Un solo accento ambra per tutto lo stato:
    -- pillola piena per dirlo a colpo d'occhio, cornice spenta perche' il
    -- riquadro deve contenere il messaggio e non gareggiarci, e un grigio per
    -- il percorso, che si legge quando serve e non prima.
    ProjectsOfflineTag = { fg = "#1a1b26", bg = "#ff9e64", bold = true },
    ProjectsOfflineAccent = { fg = "#ff9e64", bold = true },
    ProjectsOfflineBorder = { fg = "#4a3a2a" },
    ProjectsOfflineText = { fg = "#c0caf5" },
    ProjectsOfflinePath = { fg = "#7a8199" },

    -- Interruttore delle notifiche accanto al titolo della cronologia. L'oro
    -- dice "sveglia", il grigio spento dice "muta" ed e' lo stesso tono con cui
    -- il pannello segna tutto cio' che non e' attivo.
    --
    -- Senza sfondo, di proposito: nessuna campanella del font ha l'inchiostro
    -- centrato nella propria cella (md-bell occupa 0..750 su una cella da 600,
    -- quindi pende a destra) e la griglia del terminale si sposta solo di celle
    -- intere. Un riquadro non farebbe che dare all'occhio il righello per
    -- misurare quello scarto; il badge del tasto qui accanto basta gia' a dire
    -- che c'e' qualcosa da premere.
    --
    -- Il colore qui e' solo il ripiego: poco piu' sotto la campanella accesa
    -- viene riagganciata all'accento della selezione, per non avere due
    -- arancioni diversi nello stesso pannello.
    ProjectsWatchOn = { fg = "#ff9e64", bold = true },
    ProjectsWatchOff = { fg = "#565f89" },
    ProjectsCommitBranch = { fg = "#73daca" },
    ProjectsCommitAuthor = { fg = "#2ac3de" },
    ProjectsCommitAuthorPill = { fg = "#7aa2f7", bg = "#273147", bold = true },
    ProjectsAuthorPill_1 = { fg = "#7aa2f7", bg = "#222a3d", bold = true },
    ProjectsAuthorPill_2 = { fg = "#73daca", bg = "#1d3331", bold = true },
    ProjectsAuthorPill_3 = { fg = "#bb9af7", bg = "#2b213b", bold = true },
    ProjectsAuthorPill_4 = { fg = "#ff9e64", bg = "#38271e", bold = true },
    ProjectsAuthorPill_5 = { fg = "#e0af68", bg = "#332b1b", bold = true },
    ProjectsAuthorPill_6 = { fg = "#f7768e", bg = "#382028", bold = true },

    -- Autori non umani. Un solo colore per tutti - fucsia, l'unica tinta che le
    -- sei pillole degli autori non usano - cosi' la domanda "questo l'ha
    -- scritto una macchina?" si risolve col colore, prima ancora di leggere il
    -- nome. Il glifo poi distingue l'assistente dalla pipeline.
    ProjectsAuthorPillBot = { fg = "#ea76cb", bg = "#35213a", bold = true },
    ProjectsCommitDate = { fg = "#565f89" },
    ProjectsPostItText = { fg = "#e0af68", bold = true },
    ProjectsPostItMuted = { fg = "#565f89", italic = true },
    ProjectsHeaderPublic = { fg = "#73daca", bold = true },
    ProjectsHeaderPrivate = { fg = "#bb9af7", bold = true },
    ProjectsHeaderLocal = { fg = "#565f89", italic = true },
    ProjectsHeaderStars = { fg = "#e0af68", bold = true },
    ProjectsQuitKey = { fg = "#1a1b26", bg = "#f7768e", bold = true },
    ProjectsHeaderForks = { fg = "#2ac3de", bold = true },
    ProjectsTitleSpecial = { fg = "#7aa2f7", bold = true },
    ProjectsProjectTitle = { fg = "#7dcfff", bg = "#1f2d44", bold = true },
    ProjectsHeaderMissing = { fg = "#f7768e", bg = "#382028", bold = true },
    ProjectsDirBoxBorder = { fg = "#ff9e64", bold = true },
    ProjectsDirBoxText = { fg = "#ff9e64" },
    ProjectsDirKeyBadge = { fg = "#15161e", bg = "#ff9e64", bold = true },

    -- Card "progetto mancante" (cartella spostata/eliminata): bordo e sfondo rosso fissi
    ProjectsBorderMissing = { fg = "#f7768e", bold = true },
    ProjectsBorderMissingSel = { fg = "#ff6b81", bold = true },
    ProjectsMissingBg = { bg = "#3a1a22" },
    ProjectsMissingName = { fg = "#ff8fa3", bg = "#3a1a22", bold = true },
    ProjectsMissingPath = { fg = "#d98a98", bg = "#3a1a22", italic = true },
    ProjectsMissingPill = { fg = "#f7768e", bg = "#4a212b", bold = true },

    -- Testo del pannello anteprima per progetto mancante: niente sfondo,
    -- solo colore (lo sfondo resta riservato ai badge dei tasti r/d).
    ProjectsMissingPathPlain = { fg = "#d98a98", italic = true },
    ProjectsMissingMsg = { fg = "#ff4757", bold = true },
    ProjectsMissingHint = { fg = "#c9758a" },
    ProjectsMissingBtnLabel = { fg = "#ff8fa3" },
    ProjectsMissingKeyBadge = { fg = "#1a1013", bg = "#f7768e", bold = true },
  }

  for name, spec in pairs(lazy_btn_hls) do
    vim.api.nvim_set_hl(0, name, vim.tbl_extend("force", spec, { default = false }))
  end

  local accent = vim.api.nvim_get_hl(0, { name = "SnacksDashboardKey", link = false })
  if accent.fg or accent.sp then
    -- La campanella accesa prende l'accento del progetto selezionato: e' lo
    -- stesso "acceso" e non avrebbe senso che fossero due arancioni diversi.
    -- Derivarlo invece di scriverlo tiene le due cose insieme anche se cambi
    -- colorscheme.
    vim.api.nvim_set_hl(0, "ProjectsWatchOn", {
      fg = accent.fg or accent.sp,
      bold = true,
    })
    vim.api.nvim_set_hl(0, "ProjectsScrollbarThumb", {
      fg = accent.fg or accent.sp,
      bold = true,
      default = false,
    })
  end
end

local function clear_kitty_graphics()
  pcall(vim.api.nvim_chan_send, vim.v.stderr, "\27_Ga=d,d=A;\27\\")
end

local function render_web_preview_in_box(st, p, pw)
  local html_file = P.get_html_preview_file(p.path)
  if not html_file then return end

  if not (st.preview.win and vim.api.nvim_win_is_valid(st.preview.win)) then return end

  local ph = vim.api.nvim_win_get_height(st.preview.win)
  local electron_bin = vim.fn.expand("~/.local/share/terminal-browser/app/electron/terminal-browser.app/Contents/MacOS/terminal-browser")
  local chafa_bin = vim.fn.executable("chafa") == 1 and "chafa"
    or (vim.fn.executable("/opt/homebrew/bin/chafa") == 1 and "/opt/homebrew/bin/chafa" or nil)

  if chafa_bin and vim.fn.executable(electron_bin) == 1 then
    local img_path = "/tmp/ph_render_" .. vim.fn.sha256(html_file) .. ".png"
    local script_path = "/tmp/ph_render.js"

    if vim.fn.filereadable(img_path) == 0 then
      local js_code = string.format([[
const { app, BrowserWindow } = require('electron');
const fs = require('fs');
app.commandLine.appendSwitch('no-sandbox');
app.commandLine.appendSwitch('disable-gpu');
app.whenReady().then(async () => {
  const win = new BrowserWindow({ width: 1200, height: 900, show: false, webPreferences: { offscreen: true } });
  await win.loadFile('%s');
  await win.webContents.insertCSS('::-webkit-scrollbar { display: none !important; } body { overflow: hidden !important; }');
  await new Promise(r => setTimeout(r, 300));
  const image = await win.webContents.capturePage();
  fs.writeFileSync('%s', image.toPNG());
  app.quit();
});
]], html_file, img_path)
      vim.fn.writefile(vim.split(js_code, "\n"), script_path)
      vim.fn.system({ electron_bin, script_path, html_file })
    end

    if vim.fn.filereadable(img_path) == 1 then
      local win_pos = vim.api.nvim_win_get_position(st.preview.win)
      local r = win_pos[1] + 2
      local c = win_pos[2] + 2
      local box_w = math.max(10, pw - 2)
      local box_h = math.max(10, ph - 2)

      local cmd_kitty = string.format("%s -f kitty --size=%dx%d %s", chafa_bin, box_w, box_h, vim.fn.shellescape(img_path))
      local handle = io.popen(cmd_kitty)
      if handle then
        local kitty_output = handle:read("*a")
        handle:close()

        if kitty_output and vim.trim(kitty_output) ~= "" then
          local term_buf = st.preview.buf
          if not (term_buf and vim.api.nvim_buf_is_valid(term_buf)) then
            term_buf = vim.api.nvim_create_buf(false, true)
            st.preview.buf = term_buf
          end
          vim.bo[term_buf].modifiable = true
          vim.bo[term_buf].readonly = false

          local blank_lines = {}
          for _ = 1, math.max(1, ph - 2) do blank_lines[#blank_lines + 1] = string.rep(" ", math.max(1, pw - 2)) end
          vim.api.nvim_buf_set_lines(term_buf, 0, -1, false, blank_lines)
          vim.bo[term_buf].modifiable = false
          vim.bo[term_buf].readonly = true

          vim.api.nvim_win_set_buf(st.preview.win, term_buf)
          st.preview.shown = term_buf

          local footer_preview = {
            { " " .. i18n.t("btn_inspector") .. " ", "ProjectsLazyBtnLabel" },
            { " s / w ", "ProjectsLazyBtnKey" },
            { "  ", "NormalFloat" },
            { " " .. i18n.t("btn_live") .. " ", "ProjectsLazyBtnLabel" },
            { " W ", "ProjectsLazyBtnKey" },
          }
          pcall(vim.api.nvim_win_set_config, st.preview.win, {
            title = { { " " .. ICON_GLOBE .. " " .. i18n.t("title_web_preview") .. " ", "ProjectsTitleSpecial" } },
            title_pos = "right",
            footer = footer_preview,
            footer_pos = "center",
          })

          if st.preview and vim.api.nvim_win_is_valid(st.preview.sb_win) then
            pcall(vim.api.nvim_win_close, st.preview.sb_win, true)
          end

          local move_cmd = string.format("\27[%d;%dH", r, c)
          pcall(vim.api.nvim_chan_send, vim.v.stderr, move_cmd .. kitty_output)

          return
        end
      end
    end
  end
end

local dw = vim.fn.strdisplaywidth

local function fit(s, w)
  s = s or ""
  if w <= 0 then return "" end
  if dw(s) <= w then return s end
  while dw(s) > w - 1 and vim.fn.strchars(s) > 0 do
    s = vim.fn.strcharpart(s, 0, vim.fn.strchars(s) - 1)
  end
  return s .. "…"
end

-- Traduce il codice stabile restituito da P.add_custom_extra() in un
-- titolo + corpo del messaggio nella lingua attiva.
local ADD_EXTRA_RESULT_KEYS = {
  empty_path = { "err_empty_path_title", "err_empty_path_body" },
  not_found = { "err_not_found_title", "err_not_found_body" },
  not_directory = { "err_not_dir_title", "err_not_dir_body" },
  already_registered = { "err_already_title", "err_already_body" },
  write_error = { "err_write_title", "err_write_body" },
  added = { "ok_added_title", "ok_added_body" },
}

local function add_extra_result_text(code, arg)
  local keys = ADD_EXTRA_RESULT_KEYS[code]
  if not keys then return code, "" end
  return i18n.t(keys[1]), i18n.t(keys[2], arg)
end

local notify_mod = require("projecthub.notify")
local NOTIFY_THEMES = notify_mod.themes
local notify = notify_mod.notify

local function get_author_pill_hl(author_name, kind)
  if kind then return "ProjectsAuthorPillBot" end
  local clean = tostring(author_name or "user"):lower():gsub("[%s%-_%./\\]", "")
  local h = 0
  for i = 1, #clean do
    h = h + string.byte(clean, i)
  end
  local idx = (h % 6) + 1
  return "ProjectsAuthorPill_" .. idx
end

local function get_author_token(word, st)
  if not word or word == "" then return nil end
  local raw_w = word
  if raw_w:sub(1, 1) == "@" then
    raw_w = raw_w:sub(2)
  end
  if raw_w == "" then return nil end

  local w_clean = raw_w:lower():gsub("[%s%-_%./\\]", "")
  local me_owners = (config.options and config.options.me and config.options.me.owners) or {}
  local is_owner_match = false
  local matched_name = nil

  -- 1. Check me.owners (e.g. phantumblade, AndreaPerini, Andrea Perini)
  for _, o in ipairs(me_owners) do
    local o_clean = o:lower():gsub("[%s%-_%./\\]", "")
    if o_clean == w_clean then
      is_owner_match = true
      matched_name = o
      break
    end
  end

  -- 2. Check local git config user.name
  if not matched_name then
    local p_git = io.popen("git config user.name 2>/dev/null")
    if p_git then
      local g_out = p_git:read("*a")
      p_git:close()
      if g_out and vim.trim(g_out) ~= "" then
        local g_clean = vim.trim(g_out):lower():gsub("[%s%-_%./\\]", "")
        if g_clean == w_clean then
          is_owner_match = true
          matched_name = vim.trim(g_out)
        end
      end
    end
  end

  -- 3. Check known repo owners across projects in cache
  if not matched_name and st and st.all then
    for _, it in ipairs(st.all) do
      local meta = P.get_github_meta(it.path)
      if meta and meta.owner then
        local o_clean = meta.owner:lower():gsub("[%s%-_%./\\]", "")
        if o_clean == w_clean then
          matched_name = meta.owner
          break
        end
      end
    end
  end

  -- 4. If word explicitly starts with @ (e.g. @user)
  if not matched_name and word:sub(1, 1) == "@" then
    matched_name = raw_w
  end

  if matched_name then
    local hl = get_author_pill_hl(matched_name)
    local display_label = "\u{f0009} " .. matched_name
    return {
      type = "author",
      author = matched_name,
      clean = w_clean,
      name = display_label,
      hl = hl,
    }
  end

  return nil
end

local function get_token_autocomplete_candidates(st)
  local list = {}
  local seen = {}

  local function add(tok, name, hl, typ)
    local k = tok:lower()
    if not seen[k] then
      seen[k] = true
      list[#list + 1] = { token = k, name = name, hl = hl, type = typ }
    end
  end

  -- 1. Language tokens
  for k, info in pairs(LANG_TOKENS) do
    add(k, info.name, info.hl, "lang")
  end

  -- 2. Visibility tokens
  for k, info in pairs(VISIBILITY_TOKENS) do
    add(k, info.name, info.hl, "vis")
  end

  -- 3. Authors
  local me_owners = (config.options and config.options.me and config.options.me.owners) or {}
  for _, o in ipairs(me_owners) do
    add(o, o, get_author_pill_hl(o), "author")
  end

  if st and st.all then
    for _, it in ipairs(st.all) do
      local meta = P.get_github_meta(it.path)
      if meta and meta.owner then
        add(meta.owner, meta.owner, get_author_pill_hl(meta.owner), "author")
      end
    end
  end

  table.sort(list, function(a, b)
    if #a.token ~= #b.token then
      return #a.token < #b.token
    end
    return a.token < b.token
  end)

  return list
end

local function join(chunks)
  local text, hls = "", {}
  for _, c in ipairs(chunks) do
    local str = tostring(c[1] or "")
    local from = #text
    text = text .. str
    if c[2] then hls[#hls + 1] = { from, #text, c[2] } end
  end
  return text, hls
end

local function chunks_width(chunks)
  local n = 0
  for _, c in ipairs(chunks) do n = n + dw(c[1] or "") end
  return n
end

local function git_chunks(g)
  if not g then return { { "…", "ProjectsMeta" } }, {} end
  if g.none then return { { i18n.t("badge_unversioned"), "ProjectsMeta" } }, {} end

  local left = { { " " .. (g.branch or "?"), "ProjectsGitBranch" } }
  local right = {}
  local function add(t, hl) right[#right + 1] = { t, hl } end

  add(g.commits .. " commit", "ProjectsMeta")
  if g.modified > 0 then add("  ●" .. g.modified, "ProjectsGitDirty") end
  if g.staged > 0 then add(" ◆" .. g.staged, "ProjectsGitStaged") end
  if g.untracked > 0 then add(" +" .. g.untracked, "ProjectsGitNew") end
  if g.conflicts > 0 then add(" !" .. g.conflicts, "ProjectsGitConflict") end
  if g.ahead > 0 then add(" ↑" .. g.ahead, "ProjectsGitSync") end
  if g.behind > 0 then add(" ↓" .. g.behind, "ProjectsGitSync") end
  if not g.dirty and g.ahead == 0 and g.behind == 0 then
    add("  " .. ICON_SYNCED, "ProjectsGitClean")
  end
  return left, right
end

-- Card dedicata ai progetti mancanti (cartella spostata/eliminata dal disco):
-- bordo e sfondo sempre rossi (non solo quando selezionata), con i tasti
-- r (riconnetti alla nuova posizione) / d (rimuovi il tracciamento) in vista.
local function missing_card(p, w, sel)
  local iw = w - 4
  local bhl = sel and "ProjectsBorderMissingSel" or "ProjectsBorderMissing"

  local function fill_row(chunks)
    local out = { { "│ ", bhl } }
    vim.list_extend(out, chunks)
    local used = chunks_width(chunks)
    if used < iw then
      out[#out + 1] = { string.rep(" ", iw - used), "ProjectsMissingBg" }
    end
    out[#out + 1] = { " │", bhl }
    return out
  end

  local function two_col(lc_text, lc_hl, rc_text, rc_hl)
    local rc_w = rc_text ~= "" and dw(rc_text) or 0
    local lt = fit(lc_text, math.max(0, iw - rc_w - (rc_w > 0 and 1 or 0)))
    local chunks = { { lt, lc_hl } }
    if rc_w > 0 then
      local gap = iw - dw(lt) - rc_w
      chunks[#chunks + 1] = { string.rep(" ", math.max(1, gap)), "ProjectsMissingBg" }
      chunks[#chunks + 1] = { rc_text, rc_hl }
    end
    return fill_row(chunks)
  end

  local badge = " " .. (p.type and p.type:upper() or i18n.t("missing_type"):upper()) .. " "

  -- Solo lo stile (bordo/sfondo rosso) + identita' del progetto qui.
  -- Le istruzioni su cosa fare (riconnetti/rimuovi) stanno nel pannello
  -- di anteprima a destra quando questa card e' selezionata.
  local rows_out = {
    { { "╭" .. string.rep("─", w - 2) .. "╮", bhl } },
    two_col(p.name, "ProjectsMissingName", badge, "ProjectsMissingPill"),
    two_col(p.path or p.dir, "ProjectsMissingPath", "", nil),
    fill_row({}),
    fill_row({}),
    fill_row({}),
    fill_row({}),
    { { "╰" .. string.rep("─", w - 2) .. "╯", bhl } },
  }
  return rows_out
end

local function slice_chunks_by_char(chunks, offset, max_w)
  local result = {}
  local current_pos = 0
  local accumulated_w = 0

  for _, chunk in ipairs(chunks) do
    local text = chunk[1]
    local hl = chunk[2]
    local num_chars = vim.fn.strchars(text)

    for i = 0, num_chars - 1 do
      local char_str = vim.fn.strcharpart(text, i, 1)
      local char_w = dw(char_str)

      if current_pos < offset then
        current_pos = current_pos + char_w
      else
        if accumulated_w + char_w <= max_w then
          if #result > 0 and result[#result][2] == hl then
            result[#result][1] = result[#result][1] .. char_str
          else
            result[#result + 1] = { char_str, hl }
          end
          accumulated_w = accumulated_w + char_w
        else
          break
        end
      end
    end

    if accumulated_w >= max_w then
      break
    end
  end

  if accumulated_w < max_w then
    result[#result + 1] = { string.rep(" ", max_w - accumulated_w), "ProjectsMeta" }
  end

  return result
end

local function card(p, w, sel, st)
  if p.is_missing then
    return missing_card(p, w, sel)
  end
  local iw = w - 4
  local bhl = sel and "ProjectsBorderSel" or "ProjectsBorder"
  local nhl = sel and "ProjectsNameSel" or "ProjectsName"

  local function row(lc, rc)
    local out = { { "│ ", bhl } }
    vim.list_extend(out, lc)
    local gap = iw - chunks_width(lc) - chunks_width(rc)
    out[#out + 1] = { string.rep(" ", math.max(#rc > 0 and 1 or 0, gap)) }
    vim.list_extend(out, rc)
    out[#out + 1] = { " │", bhl }
    return out
  end

  local ptype = ""
  local ptype_hl = "ProjectsType"
  if p.is_disconnected then
    ptype = " 󱊞 " .. (p.volume_name and ("SSD: " .. p.volume_name) or i18n.t("badge_external_offline")) .. " "
    ptype_hl = "ProjectsOfflineAccent"
  elseif p.is_external then
    ptype = " 󱊞 " .. (p.volume_name or i18n.t("badge_external_online")) .. " "
    ptype_hl = "ProjectsType"
  else
    local label = type_label(p)
    if label then ptype = " " .. label .. " " end
  end

  -- L'icona dell'unita' la porta il badge a destra, una volta sola: sul nome,
  -- sulla cartella e sulla riga di stato era la stessa cosa detta quattro volte.
  local name = fit(p.name, iw - dw(ptype) - 2)
  local desc = p.desc and fit(p.desc, iw) or i18n.t("no_description")
  local age = p.ago or ""
  local clean_dir = (p.dir or ""):gsub("^/+", "/"):gsub("^~//+", "~/")
  local dir = fit(clean_dir, iw - dw(age) - 2)
  local gl, gr
  if p.is_disconnected then
    -- Solo la pillola: il nome dell'unita' e' gia' nel badge in alto a destra
    -- della card, e ripeterlo qui sotto non aggiunge niente.
    gl = { { " " .. i18n.t("offline_tag") .. " ", "ProjectsOfflineTag" } }
    gr = {}
  else
    gl, gr = git_chunks(p.git)
  end

  local bar_chunks = {}
  local legend_chunks = {}
  local used_w = 0

  if p.languages then
    if #p.languages > 0 then
      for idx, lang in ipairs(p.languages) do
        local seg_w = math.floor(iw * (lang.pct / 100))
        if idx == #p.languages then
          seg_w = math.max(0, iw - used_w)
        end
        if seg_w > 0 then
          bar_chunks[#bar_chunks + 1] = { string.rep("━", seg_w), lang.hl }
          used_w = used_w + seg_w
        end
      end
      if used_w < iw then
        bar_chunks[#bar_chunks + 1] = { string.rep("━", iw - used_w), "ProjectsLangTrack" }
      end

      for idx, lang in ipairs(p.languages) do
        if idx > 1 then
          legend_chunks[#legend_chunks + 1] = { "   " }
        end
        legend_chunks[#legend_chunks + 1] = { "● ", lang.hl }
        legend_chunks[#legend_chunks + 1] = { lang.name .. " ", "ProjectsMeta" }
        legend_chunks[#legend_chunks + 1] = { lang.pct .. "%", "ProjectsMeta" }
      end
    end
  else
    bar_chunks = { { string.rep("━", iw), "ProjectsLangTrack" } }
    legend_chunks = { { "analizzando linguaggi...", "ProjectsMeta" } }
  end

  local rendered_legend = {}
  if #legend_chunks > 0 then
    if chunks_width(legend_chunks) > iw then
      local loop_chunks = {}
      vim.list_extend(loop_chunks, legend_chunks)
      loop_chunks[#loop_chunks + 1] = { "   •   ", "ProjectsMeta" }
      vim.list_extend(loop_chunks, legend_chunks)

      local total_chars = 0
      for _, c in ipairs(legend_chunks) do total_chars = total_chars + vim.fn.strchars(c[1]) end
      total_chars = total_chars + 7

      local offset = (st and st.marquee_offset or 0) % math.max(1, total_chars)
      rendered_legend = slice_chunks_by_char(loop_chunks, offset, iw)
    else
      rendered_legend = slice_chunks_by_char(legend_chunks, 0, iw)
    end
  end

  local rows_out = {
    { { "╭" .. string.rep("─", w - 2) .. "╮", bhl } },
    row({ { name, nhl } }, { { ptype, ptype_hl } }),
    row({ { desc, p.desc and "ProjectsDesc" or "ProjectsMeta" } }, {}),
    row({ { dir, "ProjectsDir" } }, { { age, "ProjectsMeta" } }),
    row(gl, gr),
  }

  if #bar_chunks > 0 then
    rows_out[#rows_out + 1] = row(bar_chunks, {})
    rows_out[#rows_out + 1] = row(rendered_legend, {})
  else
    rows_out[#rows_out + 1] = row({ { "", "ProjectsMeta" } }, {})
    rows_out[#rows_out + 1] = row({ { "", "ProjectsMeta" } }, {})
  end

  rows_out[#rows_out + 1] = { { "╰" .. string.rep("─", w - 2) .. "╯", bhl } }
  return rows_out
end

local function tree(root, max)
  local icons = package.loaded["mini.icons"] or (pcall(require, "mini.icons") and require("mini.icons"))
  local out, hls, stop = {}, {}, false

  local function icon_for(name, is_dir)
    if not icons then return is_dir and " " or " ", is_dir and "ProjectsTreeDir" or nil end
    local ok, ic, hl = pcall(icons.get, is_dir and "directory" or "file", name)
    if ok and ic then return ic .. " ", hl end
    return is_dir and " " or " ", nil
  end

  local function scan(dir, prefix, depth)
    if stop then return end
    local ok, iter = pcall(vim.fs.dir, dir)
    if not ok then return end
    local entries = {}
    for name, t in iter do
      if not P.is_ignored(name) then
        entries[#entries + 1] = { name = name, dir = t == "directory" }
      end
    end
    table.sort(entries, function(a, b)
      if a.dir ~= b.dir then return a.dir end
      return a.name:lower() < b.name:lower()
    end)
    for i, e in ipairs(entries) do
      if #out >= max then
        stop = true
        return
      end
      local last = i == #entries
      local ic, ihl = icon_for(e.name, e.dir)
      local text, lhls = join({
        { prefix .. (last and "╰─ " or "├─ "), "ProjectsMeta" },
        { ic, ihl },
        { e.name .. (e.dir and "/" or ""), e.dir and "ProjectsTreeDir" or nil },
      })
      out[#out + 1] = text
      for _, h in ipairs(lhls) do
        hls[#hls + 1] = { #out - 1, h[1], h[2], h[3] }
      end
      if e.dir and depth < 2 then
        scan(dir .. "/" .. e.name, prefix .. (last and "   " or "│  "), depth + 1)
      end
    end
  end

  scan(root, "", 1)
  if #out == 0 then out = { i18n.t("tree_empty") } end
  return out, hls
end

local ns_html = vim.api.nvim_create_namespace("projects_html_conceal")

local function conceal_html_tags(buf)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end
  vim.api.nvim_buf_clear_namespace(buf, ns_html, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, 400, false)
  for i, line in ipairs(lines) do
    for s_idx, tag, e_idx in line:gmatch("()<([^>]+)>()") do
      pcall(vim.api.nvim_buf_set_extmark, buf, ns_html, i - 1, s_idx - 1, {
        end_col = e_idx - 1,
        conceal = "",
      })
    end
  end
end

-- Evidenziazione dinamica con sfondo morbido a pillola tenue (senza quadre '[]')
-- e Ghost Text (lettere mancanti in grigio per autocompletamento filtri)
local function highlight_input_languages(st)
  local buf = st.input.buf
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end
  vim.api.nvim_buf_clear_namespace(buf, ns_input, 0, -1)
  vim.api.nvim_buf_clear_namespace(buf, ns_ghost, 0, -1)
  st.ghost_suggestion = nil

  local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
  if line == "" then return end

  -- 1. Evidenziazione a pillola SOLO quando la parola è completa
  for start_pos, word in line:gmatch("()(%S+)") do
    local info = LANG_TOKENS[word:lower()] or VISIBILITY_TOKENS[word:lower()] or get_author_token(word, st)
    if info then
      local s_idx = start_pos - 1
      local e_idx = s_idx + #word
      pcall(vim.api.nvim_buf_set_extmark, buf, ns_input, 0, s_idx, {
        end_col = e_idx,
        hl_group = info.hl,
        priority = 300,
      })
    end
  end

  -- 2. Ghost Text: rileva lettere mancanti del filtro in grigio
  local win = st.input.win
  if not (win and vim.api.nvim_win_is_valid(win)) then return end

  local mode = vim.api.nvim_get_mode().mode
  local cur = vim.api.nvim_win_get_cursor(win)
  local col = cur[2]
  local check_len = col
  if mode ~= "i" and check_len < #line then
    check_len = check_len + 1
  end
  local ext_col = math.max(col, check_len)
  local before_cursor = line:sub(1, ext_col)
  local cur_word = before_cursor:match("(%S+)$")

  if cur_word and #cur_word >= 1 then
    local w_low = cur_word:lower()
    local candidates = get_token_autocomplete_candidates(st)

    for _, cand in ipairs(candidates) do
      if cand.token:sub(1, #w_low) == w_low and #cand.token > #w_low then
        local suffix = cand.token:sub(#w_low + 1)
        st.ghost_suggestion = {
          prefix = cur_word,
          completion = cand.token,
          remaining = suffix,
          col = ext_col,
        }

        pcall(vim.api.nvim_buf_set_extmark, buf, ns_ghost, 0, ext_col, {
          virt_text = { { suffix, "ProjectsGhostText" } },
          virt_text_pos = "inline",
          priority = 400,
        })
        break
      end
    end
  end
end

render_preview_scrollbar = function(st)
  if st.dir_picker_mode then
    if st.preview and st.preview.sb_buf and vim.api.nvim_buf_is_valid(st.preview.sb_buf) then
      vim.bo[st.preview.sb_buf].modifiable = true
      vim.api.nvim_buf_set_lines(st.preview.sb_buf, 0, -1, false, {})
      vim.bo[st.preview.sb_buf].modifiable = false
    end
    if st.preview and st.preview.sb_win and vim.api.nvim_win_is_valid(st.preview.sb_win) then
      pcall(vim.api.nvim_win_close, st.preview.sb_win, true)
      st.preview.sb_win = nil
    end
    return
  end

  if not (st.preview and vim.api.nvim_win_is_valid(st.preview.win)) then
    return
  end

  local win = st.preview.win
  local pw = vim.api.nvim_win_get_width(win)
  local ph = vim.api.nvim_win_get_height(win)

  -- Re-create st.preview.sb_win if needed when returning to normal preview mode
  if not (st.preview.sb_win and vim.api.nvim_win_is_valid(st.preview.sb_win)) then
    if not (st.preview.sb_buf and vim.api.nvim_buf_is_valid(st.preview.sb_buf)) then
      st.preview.sb_buf = mkbuf(true)
    end
    st.preview.sb_win = vim.api.nvim_open_win(st.preview.sb_buf, false, {
      relative = "win",
      win = win,
      row = 0,
      col = math.max(0, pw - 1),
      width = 1,
      height = ph,
      style = "minimal",
      focusable = false,
      zindex = 70,
    })
    vim.wo[st.preview.sb_win].winhighlight = "Normal:NormalFloat,FloatBorder:ProjectsBorder"
  else
    pcall(vim.api.nvim_win_set_config, st.preview.sb_win, {
      relative = "win",
      win = win,
      row = 0,
      col = math.max(0, pw - 1),
      width = 1,
      height = ph,
    })
  end

  local pbuf = vim.api.nvim_win_get_buf(win)
  if not vim.api.nvim_buf_is_valid(pbuf) then return end

  local total_lines = vim.api.nvim_buf_line_count(pbuf)
  local sbuf = st.preview.sb_buf

  if total_lines <= ph then
    vim.bo[sbuf].modifiable = true
    vim.api.nvim_buf_set_lines(sbuf, 0, -1, false, {})
    vim.bo[sbuf].modifiable = false
    return
  end

  local vista = vim.api.nvim_win_call(win, vim.fn.winsaveview)
  local topline = vista.topline or 1

  local thumb_h = math.max(2, math.floor(ph * ph / total_lines))
  local max_top = math.max(1, total_lines - ph + 1)
  local ratio = math.min(1, math.max(0, (topline - 1) / (max_top - 1)))
  local thumb_top = math.floor(ratio * (ph - thumb_h))

  local lines = {}
  local hls = {}
  for r = 0, ph - 1 do
    local is_thumb = (r >= thumb_top and r < thumb_top + thumb_h)
    lines[#lines + 1] = is_thumb and "█" or "│"
    hls[#hls + 1] = { r, is_thumb and "ProjectsScrollbarThumb" or "ProjectsScrollbarTrack" }
  end

  vim.bo[sbuf].modifiable = true
  vim.api.nvim_buf_set_lines(sbuf, 0, -1, false, lines)
  vim.bo[sbuf].modifiable = false

  vim.api.nvim_buf_clear_namespace(sbuf, ns_psb, 0, -1)
  for _, hl in ipairs(hls) do
    pcall(vim.api.nvim_buf_set_extmark, sbuf, ns_psb, hl[1], 0, {
      end_col = 1,
      hl_group = hl[2],
      priority = 300,
    })
  end
end

render_scrollbar = function(st)
  if not (st.list and vim.api.nvim_win_is_valid(st.list.win) and st.list.sb_win and vim.api.nvim_win_is_valid(st.list.sb_win)) then
    return
  end
  local win = st.list.win
  local h = vim.api.nvim_win_get_height(win)

  local max_content = 1
  if st.pos then
    for _, lnum in pairs(st.pos) do
      local b = lnum + CARD_ROWS - 1
      if b > max_content then max_content = b end
    end
  end
  if max_content <= 1 then
    max_content = vim.api.nvim_buf_line_count(st.list.buf)
  end

  local sbuf = st.list.sb_buf
  if max_content <= h then
    vim.bo[sbuf].modifiable = true
    vim.api.nvim_buf_set_lines(sbuf, 0, -1, false, {})
    vim.bo[sbuf].modifiable = false
    return
  end

  local vista = vim.api.nvim_win_call(win, vim.fn.winsaveview)
  local topline = vista.topline or 1

  local thumb_h = math.max(2, math.floor(h * h / max_content))
  local max_top = math.max(1, max_content - h + 1)
  local ratio = math.min(1, math.max(0, (topline - 1) / (max_top - 1)))
  local thumb_top = math.floor(ratio * (h - thumb_h))

  local lines = {}
  local hls = {}
  for r = 0, h - 1 do
    local is_thumb = (r >= thumb_top and r < thumb_top + thumb_h)
    lines[#lines + 1] = is_thumb and "█" or "│"
    hls[#hls + 1] = { r, is_thumb and "ProjectsScrollbarThumb" or "ProjectsScrollbarTrack" }
  end

  vim.bo[sbuf].modifiable = true
  vim.api.nvim_buf_set_lines(sbuf, 0, -1, false, lines)
  vim.bo[sbuf].modifiable = false

  vim.api.nvim_buf_clear_namespace(sbuf, ns_sb, 0, -1)
  for _, hl in ipairs(hls) do
    pcall(vim.api.nvim_buf_set_extmark, sbuf, ns_sb, hl[1], 0, {
      end_col = 1,
      hl_group = hl[2],
      priority = 300,
    })
  end
end

scroll_preview = function(st, lines)
  if not (st.preview and vim.api.nvim_win_is_valid(st.preview.win)) then return end
  local need_more_commits = false
  vim.api.nvim_win_call(st.preview.win, function()
    local v = vim.fn.winsaveview()
    local buf = vim.api.nvim_win_get_buf(st.preview.win)
    local total = vim.api.nvim_buf_line_count(buf)
    local h = vim.api.nvim_win_get_height(st.preview.win)
    local max_top = math.max(1, total - h + 1)
    local new_top = math.max(1, math.min(max_top, (v.topline or 1) + lines))
    v.topline = new_top
    v.lnum = new_top
    v.leftcol = 0
    vim.fn.winrestview(v)

    if lines > 0 and new_top + h >= total - 3 then
      local p_item = st.items[st.sel]
      local total_git_commits = (p_item and p_item.git and tonumber(p_item.git.commits)) or 0
      local cur_lim = st.commit_limit or 100
      if cur_lim < total_git_commits then
        st.commit_limit = cur_lim + 100
        need_more_commits = true
      end
    end
  end)
  render_preview_scrollbar(st)
  if need_more_commits and st.inspector_mode then
    render_inspector(st)
  end
end

local function render_inspector(st)
  if not (st.preview and vim.api.nvim_win_is_valid(st.preview.win)) then return end

  local p = st.items[st.sel]
  if not p then
    if st.preview.buf and vim.api.nvim_buf_is_valid(st.preview.buf) then
      vim.bo[st.preview.buf].modifiable = true
      vim.api.nvim_buf_set_lines(st.preview.buf, 0, -1, false, {})
      vim.bo[st.preview.buf].modifiable = false
    end
    pcall(vim.api.nvim_win_set_config, st.preview.win, { title = "", footer = "" })
    if st.preview.sb_win and vim.api.nvim_win_is_valid(st.preview.sb_win) then
      pcall(vim.api.nvim_win_close, st.preview.sb_win, true)
    end
    return
  end

  if not (st.preview.buf and vim.api.nvim_buf_is_valid(st.preview.buf)) then
    st.preview.buf = vim.api.nvim_create_buf(false, true)
  end
  local buf = st.preview.buf

  local saved_view = nil
  if vim.api.nvim_win_is_valid(st.preview.win) and vim.api.nvim_win_get_buf(st.preview.win) == buf then
    saved_view = vim.api.nvim_win_call(st.preview.win, vim.fn.winsaveview)
  end

  vim.bo[buf].modifiable = true
  vim.bo[buf].readonly = false
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].filetype = ""

  local pw = vim.api.nvim_win_get_width(st.preview.win)
  local ph = vim.api.nvim_win_get_height(st.preview.win)

  if not (p.loc_lines and p.loc_files) then
    P.calc_loc_async(p, function()
      if st.inspector_mode and st.items[st.sel] == p then
        render_inspector(st)
      end
    end)
  end

  local note = P.get_note(p.path)
  local limit = st.commit_limit or 100
  local commits, author_stats = P.get_commit_details(p.path, limit)
  if #commits == 0 then
    st.show_all_commits = false
  end

  local sel_idx = st.sel
  if not P.has_gh_cache(p.path) then
    P.async_load_github_meta(p.path, function()
      if vim.api.nvim_win_is_valid(st.preview.win) and st.sel == sel_idx and st.inspector_mode then
        render_preview(st)
      end
    end)
  end

  local lines = {}
  local hls = {}

  local function add(text, hl)
    lines[#lines + 1] = text
    if hl then
      hls[#hls + 1] = { #lines - 1, 0, #text, hl }
    end
  end

  local function fmt_num(num)
    if not num then return nil end
    local str = tostring(num):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
    return str
  end

  local function add_commit_row(c, b_name, max_w)
    if not c then return end
    local subject = tostring(c.subject or "")
    -- Il badge porta lo sfondo, lo spazio dopo no: così il colore si ferma
    -- sull'etichetta invece di colare sul testo che segue.
    local tag_badge, tag_gap, scope_txt = "", "", ""
    local tag_hl = nil

    local tag, scope, rest = commit_tags.parse(subject)
    if tag then
      tag_badge = " " .. tag .. " "
      tag_gap = " "
      tag_hl = commit_tags.hl_group(tag)
      subject = rest
      -- Nessun separatore fra ambito e soggetto: li distingue già il colore,
      -- e il puntino costava due colonne su ogni riga di commit.
      if scope then scope_txt = scope .. " " end
    end

    local indent = "   "
    local hash_str = tostring(c.hash or "???") .. " "
    local b_clean = tostring(b_name or "main"):gsub("^%[", ""):gsub("%]$", "")
    local b_str = "󰘬 " .. b_clean .. "  "
    local date_str = i18n.format_relative_time(tostring(c.age or ""))
    local author_name = tostring(c.author or "")
    local role_icon = M.MEMBER_ICON
    if c.kind == "ai" then
      role_icon = M.AI_ICON
    elseif c.kind == "bot" then
      role_icon = M.BOT_ICON
    elseif c.is_owner then
      role_icon = M.OWNER_ICON
    end
    local author_pill = (c.show_author and author_name ~= "") and (" " .. role_icon .. author_name .. " ") or ""
    local gap = (#author_pill > 0) and "  " or ""
    local right_block = date_str .. gap .. author_pill

    local fixed_w = dw(indent) + dw(hash_str) + dw(b_str) + dw(tag_badge) + dw(tag_gap)
        + dw(scope_txt) + dw(right_block)
    local avail_for_subj = max_w - fixed_w

    subject = subject:gsub("[%s%.…]+$", "")

    if dw(subject) > avail_for_subj then
      subject = fit(subject, avail_for_subj)
    end

    local left_line = indent .. hash_str .. b_str .. tag_badge .. tag_gap .. scope_txt .. subject
    local space_fill = math.max(0, max_w - dw(left_line) - dw(right_block))
    local full_line = left_line .. string.rep(" ", space_fill) .. right_block

    lines[#lines + 1] = full_line
    local row_idx = #lines - 1

    local c0 = 0
    c0 = c0 + #indent

    local c_hash_end = c0 + #hash_str
    hls[#hls + 1] = { row_idx, c0, c_hash_end,
      c.is_incoming and "ProjectsIncomingHash" or "ProjectsCommitHash" }
    c0 = c_hash_end

    local c_branch_end = c0 + #b_str
    hls[#hls + 1] = { row_idx, c0, c_branch_end, "ProjectsCommitBranch" }
    c0 = c_branch_end

    if #tag_badge > 0 then
      local c_tag_end = c0 + #tag_badge
      hls[#hls + 1] = { row_idx, c0, c_tag_end, tag_hl }
      c0 = c_tag_end + #tag_gap
    end

    if #scope_txt > 0 then
      local c_scope_end = c0 + #scope_txt
      hls[#hls + 1] = { row_idx, c0, c_scope_end,
        tag and commit_tags.scope_hl_group(tag) or "ProjectsTagScope" }
      c0 = c_scope_end
    end

    if #subject > 0 then
      local c_subj_end = c0 + #subject
      hls[#hls + 1] = { row_idx, c0, c_subj_end, "ProjectsGitStaged" }
      c0 = c_subj_end
    end

    local date_start = #full_line - #right_block
    local date_end = date_start + #date_str
    hls[#hls + 1] = { row_idx, date_start, date_end, "ProjectsCommitDate" }

    if #author_pill > 0 then
      local pill_start = date_end + #gap
      local author_hl = get_author_pill_hl(author_name, c.kind)
      hls[#hls + 1] = { row_idx, pill_start, #full_line, author_hl }
    end
  end

  -- Riga di confine fra i commit scaricati da upstream e il punto in cui il
  -- clone locale e' fermo. Tutto cio' che sta sopra non e' ancora sceso a
  -- terra; tutto cio' che sta sotto e' la versione che hai davvero.
  local function add_incoming_divider(count, upstream, max_w)
    local label = " \u{2193} " .. ((count == 1)
      and i18n.t("incoming_divider_1", upstream)
      or i18n.t("incoming_divider", count, upstream)) .. " "
    local indent = "   "
    -- Il tratto si divide in due meta' per tenere l'etichetta al centro; il
    -- resto della divisione va a destra, cosi' la riga finisce sempre esatta.
    local rule_w = math.max(0, max_w - dw(indent) - dw(label))
    local left_w = math.floor(rule_w / 2)
    local left_rule = string.rep("\u{2500}", left_w)
    local right_rule = string.rep("\u{2500}", rule_w - left_w)

    local line = indent .. left_rule .. label .. right_rule
    lines[#lines + 1] = line
    local row = #lines - 1

    local c0 = #indent
    local c1 = c0 + #left_rule
    local c2 = c1 + #label
    hls[#hls + 1] = { row, c0, c1, "ProjectsIncomingLine" }
    hls[#hls + 1] = { row, c1, c2, "ProjectsIncomingLabel" }
    hls[#hls + 1] = { row, c2, #line, "ProjectsIncomingLine" }
  end

  -- I commit in arrivo portano il nome del ramo remoto invece di quello
  -- locale: e' li' che vivono finche' non fai pull.
  local incoming_entry = (not (p.is_missing or p.is_disconnected)) and P.get_incoming(p.path) or nil
  local incoming = incoming_entry and P.tag_commit_roles(p.path, incoming_entry.commits) or {}
  local incoming_up = (incoming_entry and incoming_entry.upstream) or "origin"
  -- Solo il nome del ramo, senza il prefisso del remote: "origin/main" veniva
  -- ripetuto su ogni riga mentre il divider lo dice gia', e allargava la
  -- colonna rubando spazio al soggetto del commit.
  local incoming_branch = "[" .. incoming_up:gsub("^[^/]+/", "") .. "]"

  -- La campanella sta appesa al titolo della cronologia, non fra i pulsanti in
  -- basso: e' li' che si guarda quando ci si chiede perche' un progetto non
  -- avvisa mai, e li' vale la pena poterlo cambiare senza cercare altrove.
  local watch_on = P.is_watched(p.path, P.author_count(p))
  local function add_history_title(text, hl)
    -- Due spazi a destra, non uno: l'inchiostro della campanella sborda dalla
    -- propria cella e si mangiava l'unico spazio, incollandola al badge. Senza
    -- riquadro la spaziatura asimmetrica non si vede, si vede solo l'aria.
    local bell = " " .. (watch_on and M.BELL_ON_ICON or M.BELL_OFF_ICON) .. "  "
    local key = " b "
    local gap = "   "
    lines[#lines + 1] = text .. gap .. bell .. key
    local row = #lines - 1
    hls[#hls + 1] = { row, 0, #text, hl }
    local c0 = #text + #gap
    hls[#hls + 1] = { row, c0, c0 + #bell, watch_on and "ProjectsWatchOn" or "ProjectsWatchOff" }
    hls[#hls + 1] = { row, c0 + #bell, c0 + #bell + #key, "ProjectsLazyBtnKey" }
  end

  -- Header Info with Top-Right GitHub Badges (Visibility, Owner, Stars, Forks)
  local gh_meta = P.get_github_meta(p.path)
  local title_pill = " " .. p.name .. " "
  local header_left = "  " .. title_pill

  local current_user = (config.options.me.owners and config.options.me.owners[1]) or ""
  local show_owner_pill = false
  local owner_pill_str = ""

  local vis_text = ""
  local vis_hl = "ProjectsHeaderLocal"
  local star_text = ""
  local fork_text = ""

  if p.is_missing then
    vis_text = ICON_ERROR .. " " .. i18n.t("header_moved")
    vis_hl = "ProjectsHeaderMissing"
  elseif p.is_disconnected then
    vis_text = "󱊞 " .. (p.volume_name and ("SSD: " .. p.volume_name) or i18n.t("badge_external_offline"))
    vis_hl = "ProjectsOfflineAccent"
  elseif gh_meta then
    if gh_meta.is_private then
      vis_text = ICON_LOCK .. " " .. i18n.t("header_private")
      vis_hl = "ProjectsHeaderPrivate"
    else
      vis_text = ICON_GLOBE .. " " .. i18n.t("header_public")
      vis_hl = "ProjectsHeaderPublic"

      if (gh_meta.stars or 0) > 0 then
        star_text = "  " .. ICON_STAR .. " " .. gh_meta.stars
      end
      if (gh_meta.forks or 0) > 0 then
        fork_text = "  " .. M.FORK_ICON .. gh_meta.forks
      end
    end

    if gh_meta.owner and gh_meta.owner:lower() ~= current_user:lower() then
      show_owner_pill = true
      owner_pill_str = " " .. M.ORG_ICON .. gh_meta.owner
    end
  else
    vis_text = ICON_FOLDER .. " " .. i18n.t("header_local")
    vis_hl = "ProjectsHeaderLocal"
  end

  local right_parts = {}
  right_parts[#right_parts + 1] = { txt = vis_text, hl = vis_hl }
  if show_owner_pill then
    local o_hl = get_author_pill_hl(gh_meta.owner)
    right_parts[#right_parts + 1] = { txt = " " .. owner_pill_str, hl = o_hl }
  end
  if star_text ~= "" then
    right_parts[#right_parts + 1] = { txt = star_text, hl = "ProjectsHeaderStars" }
  end
  if fork_text ~= "" then
    right_parts[#right_parts + 1] = { txt = fork_text, hl = "ProjectsHeaderForks" }
  end

  local header_right = ""
  for _, part in ipairs(right_parts) do
    header_right = header_right .. part.txt
  end
  header_right = header_right .. "  "

  local space_fill = math.max(1, pw - vim.api.nvim_strwidth(header_left) - vim.api.nvim_strwidth(header_right))
  local full_header = header_left .. string.rep(" ", space_fill) .. header_right

  -- Nella cronologia completa l'intestazione del progetto non si ripete:
  -- nome, percorso e provenienza del fork sono già sulla card a sinistra, e
  -- qui ruberebbero tre righe a ciò che si è venuti a leggere.
  if not st.show_all_commits then
    add("")
    lines[#lines + 1] = full_header
    local h_row = #lines - 1
    hls[#hls + 1] = { h_row, 2, 2 + #title_pill, "ProjectsProjectTitle" }

    local curr_col = #full_header - #header_right
    for _, part in ipairs(right_parts) do
      local p_len = #part.txt
      hls[#hls + 1] = { h_row, curr_col, curr_col + p_len, part.hl }
      curr_col = curr_col + p_len
    end

    local clean_path = (p.path or ""):gsub("^/+", "/")
    -- L'icona dell'unita' resta solo accanto al nome del volume, in alto a
    -- destra: qui e sul titolo era la stessa cosa ripetuta tre volte.
    add("  \u{f07c} " .. clean_path, "ProjectsDir")
    if gh_meta and (gh_meta.parent or gh_meta.is_fork) then
      local parent_str = gh_meta.parent and i18n.t("fork_of", gh_meta.parent) or i18n.t("fork_of_original")
      add("   " .. ICON_RELOCATE .. " " .. parent_str, "ProjectsGitBranch")
    end
  end

  -- Blocco "Team & collaboratori", condiviso dalle due modalità: in
  -- panoramica troncato ai primi tre, nella cronologia completa per intero.
  local function emit_authors(show_all)
    if not (author_stats and #author_stats > 1) then return end
    add("")
    local team_title = (#author_stats == 1) and i18n.t("team_1") or i18n.t("team", #author_stats)
    add("  \u{f0849} " .. team_title, "ProjectsName")

    local tot_c = 0
    for _, ast in ipairs(author_stats) do
      tot_c = tot_c + (ast.count or 0)
    end
    if tot_c == 0 then tot_c = 1 end

    local max_authors = show_all and #author_stats or math.min(3, #author_stats)
    for i = 1, max_authors do
      local ast = author_stats[i]
      if ast and ast.name then
        local a_name = tostring(ast.name)
        local c_num = ast.count or 0
        local pct = math.floor((c_num / tot_c) * 100 + 0.5)
        local role_icon = M.MEMBER_ICON
        if ast.kind == "ai" then
          role_icon = M.AI_ICON
        elseif ast.kind == "bot" then
          role_icon = M.BOT_ICON
        elseif ast.is_owner then
          role_icon = M.OWNER_ICON
        end
        local pill_str = role_icon .. a_name
        local indent = "   "
        local stat_str = i18n.t("commit_stat", c_num, pct)

        local line_left = indent .. pill_str .. "  "
        local fill_w = math.max(1, pw - 6 - vim.api.nvim_strwidth(line_left) - vim.api.nvim_strwidth(stat_str))
        local full_line = line_left .. string.rep(" ", fill_w) .. stat_str

        lines[#lines + 1] = full_line
        local r_idx = #lines - 1

        local p_start = #indent
        local p_end = p_start + #pill_str
        local a_hl = get_author_pill_hl(a_name, ast.kind)
        hls[#hls + 1] = { r_idx, p_start, p_end, a_hl }

        local s_start = #full_line - #stat_str
        hls[#hls + 1] = { r_idx, s_start, #full_line, "ProjectsMeta" }
      end
    end

    if not show_all and #author_stats > 3 then
      local diff_authors = #author_stats - 3
      local a_more = "   " .. ((diff_authors == 1) and i18n.t("team_more_1") or i18n.t("team_more", diff_authors))
      add(a_more, "ProjectsMeta")
      local l_idx = #lines - 1
      local c_marker = i18n.t("press_c")
      local c_pos = a_more:find(c_marker, 1, true)
      if c_pos then
        hls[#hls + 1] = { l_idx, c_pos + #c_marker - 1, c_pos + #c_marker, "ProjectsKeyText" }
      end
    end
  end

  if st.show_all_commits then
    -- L'elenco completo dei collaboratori apre il pannello: sotto centinaia
    -- di commit sarebbe di fatto irraggiungibile.
    emit_authors(true)

    add("")
    local branch_str = (p.git and p.git.branch) and ("[" .. tostring(p.git.branch) .. "]") or "[main]"
    local total_git_commits = (p.git and tonumber(p.git.commits)) or #commits
    if total_git_commits > #commits then
      local c_title = string.format("%s (%d di %d commit caricati - Scorri per caricarne altri)", i18n.t("title_commits"), #commits, total_git_commits)
      add_history_title("  " .. ICON_GIT .. " " .. c_title, "ProjectsTitleSpecial")
    else
      add_history_title("  " .. ICON_HISTORY .. " " .. i18n.t("commits_full", #commits), "ProjectsName")
    end

    if #commits > 0 or #incoming > 0 then
      -- Sopra il divider i commit gia' presenti su upstream, dal piu' recente;
      -- sotto, invariata, la cronologia del clone locale.
      for _, c in ipairs(incoming) do
        add_commit_row(c, incoming_branch, pw - 4)
      end
      if #incoming > 0 then
        add_incoming_divider(#incoming, incoming_up, pw - 4)
      end
      for _, c in ipairs(commits) do
        add_commit_row(c, branch_str, pw - 4)
      end
    else
      add("   " .. i18n.t("commits_none"), "ProjectsDesc")
    end
  else
    if not p.is_disconnected then
      add("")
      add("  " .. ICON_OVERVIEW .. " " .. i18n.t("overview"), "ProjectsTitleSpecial")
    end

    if p.is_missing then
      local box_title = i18n.t("missing_box_title")
      local box_rows = {
        { text = i18n.t("missing_box_line1"), hl = "ProjectsHeaderMissing" },
        { text = i18n.t("missing_box_line2"), hl = "ProjectsDesc" },
        { text = fit(p.path, pw - 10), hl = "ProjectsMeta" },
        { text = "", hl = "ProjectsHeaderMissing" },
        { text = i18n.t("missing_box_actions"), hl = "ProjectsName" },
        { text = i18n.t("missing_box_reconnect"), hl = "ProjectsGitBranch" },
        { text = i18n.t("missing_box_untrack"), hl = "ProjectsGitBranch" },
      }
      local inner_w = dw(box_title) + 2
      for _, row in ipairs(box_rows) do
        inner_w = math.max(inner_w, dw(row.text))
      end
      inner_w = math.min(inner_w, math.max(20, pw - 10))

      add("   ┌─ " .. ICON_ERROR .. " " .. box_title .. " " .. string.rep("─", math.max(0, inner_w - dw(box_title) - 1)) .. "┐", "ProjectsHeaderMissing")
      add("   │  " .. string.rep(" ", inner_w) .. " │", "ProjectsHeaderMissing")
      for _, row in ipairs(box_rows) do
        local txt = fit(row.text, inner_w)
        add("   │  " .. txt .. string.rep(" ", math.max(0, inner_w - dw(txt))) .. " │", row.hl)
      end
      add("   └" .. string.rep("─", inner_w + 4) .. "┘", "ProjectsHeaderMissing")
    elseif p.is_disconnected then
      -- Lo stato si annuncia una volta sola, in grande e al centro: e' il
      -- fatto principale della schermata, non una nota a margine. Sotto, il
      -- riquadro dice le due cose che restano da sapere - dov'e' il progetto e
      -- che basta ricollegare l'unita'.
      local vol = p.volume_name or "SSD"
      local word = big_word(i18n.t("offline_tag"))
      local word_w = word and dw(word[1]) or 0

      -- Il font a blocchi ci sta solo se il pannello e' abbastanza largo.
      -- Quando non ci sta, la parola resta al suo posto scritta normalmente:
      -- stesso colore, stessa posizione, solo in caratteri veri. Stirarla con
      -- gli spazi la rendeva una fila di lettere sparse, che si legge peggio
      -- di una scritta normale e non sembra piu' nemmeno un titolo.
      local big = word and word_w <= pw - 4

      add("")
      add("")
      if big then
        local pad = string.rep(" ", math.max(0, math.floor((pw - word_w) / 2)))
        for _, l in ipairs(word) do
          lines[#lines + 1] = pad .. l
          hls[#hls + 1] = { #lines - 1, #pad, #(pad .. l), "ProjectsOfflineAccent" }
        end
      else
        local plain = i18n.t("offline_tag")
        local pad = string.rep(" ", math.max(0, math.floor((pw - dw(plain)) / 2)))
        lines[#lines + 1] = pad .. plain
        hls[#hls + 1] = { #lines - 1, #pad, #(pad .. plain), "ProjectsOfflineAccent" }
      end
      add("")
      add("")

      local inner = math.max(34, math.min(pw - 8, 64))
      local box_w = inner + 4
      local ind = string.rep(" ", math.max(0, math.floor((pw - box_w) / 2)))

      local function frame(left, right)
        local line = ind .. left .. string.rep("─", inner + 2) .. right
        lines[#lines + 1] = line
        hls[#hls + 1] = { #lines - 1, #ind, #line, "ProjectsOfflineBorder" }
      end

      --- Una riga del riquadro: i bordi tengono il colore della cornice, il
      --- contenuto il proprio. add() colorerebbe tutto insieme.
      local function row(segments)
        local body, marks, col = "", {}, 0
        for _, seg in ipairs(segments) do
          marks[#marks + 1] = { col, col + #seg[1], seg[2] }
          body = body .. seg[1]
          col = col + #seg[1]
        end
        local pad = math.max(0, inner - dw(body))
        local line = ind .. "│ " .. body .. string.rep(" ", pad) .. " │"
        lines[#lines + 1] = line
        local r = #lines - 1
        local base = #ind + #"│ "
        hls[#hls + 1] = { r, #ind, base, "ProjectsOfflineBorder" }
        for _, m in ipairs(marks) do
          hls[#hls + 1] = { r, base + m[1], base + m[2], m[3] }
        end
        hls[#hls + 1] = { r, #line - #"│", #line, "ProjectsOfflineBorder" }
      end

      frame("╭", "╮")
      row({ { "󱊞  " .. vol, "ProjectsOfflineAccent" } })
      row({ { "", "ProjectsOfflineText" } })
      row({ { i18n.t("external_box_where"), "ProjectsOfflineText" } })
      row({ { fit(p.path or "", inner), "ProjectsOfflinePath" } })
      row({ { "", "ProjectsOfflineText" } })
      row({ { fit(i18n.t("external_box_how", vol), inner), "ProjectsOfflineText" } })
      row({ { fit(i18n.t("external_box_auto"), inner), "ProjectsOfflinePath" } })
      frame("╰", "╯")
    else
      if p.loc_lines then
        local l_str = (p.loc_lines == 1) and i18n.t("loc_lines_1") or i18n.t("loc_lines", fmt_num(p.loc_lines))
        local f_str = (p.loc_files == 1) and i18n.t("loc_files_1") or i18n.t("loc_files", fmt_num(p.loc_files))
        add("   " .. ICON_DOC .. " " .. l_str, "ProjectsGitBranch")
        add("   " .. ICON_FOLDER .. " " .. f_str, "ProjectsGitBranch")
      else
        add("   " .. ICON_DOC .. " " .. i18n.t("loc_calculating_lines"), "ProjectsDesc")
        add("   " .. ICON_FOLDER .. " " .. i18n.t("loc_calculating_files"), "ProjectsDesc")
      end

      local branch_str = (p.git and p.git.branch) and ("[" .. tostring(p.git.branch) .. "]") or "[main]"
      local git_num_commits = (p.git and p.git.commits) and tostring(p.git.commits) or "0"
      local git_history_text = p.git and ((git_num_commits == "1") and i18n.t("commits_1", branch_str) or i18n.t("git_history_commits_branch", git_num_commits, branch_str)) or i18n.t("not_tracked")
      add("   " .. ICON_GIT .. " " .. i18n.t("git_history", git_history_text), "ProjectsGitStaged")
      add("   " .. ICON_CLOCK .. " " .. i18n.t("last_modified", tostring(p.ago or i18n.t("unknown"))), "ProjectsMeta")
    end

    emit_authors(false)

  if not (p.is_missing or p.is_disconnected) then
    add("")
    -- Silenziare non nasconde niente: la cronologia resta completa, divider
    -- compreso. Cambia solo che nessuna notifica partira', e lo dice la
    -- campanella qui accanto.
    add_history_title("  " .. ICON_HISTORY .. " " .. i18n.t("commits_recent"), "ProjectsName")

    local visible_commits = math.min(5, #commits)
    if visible_commits > 0 or #incoming > 0 then
      local branch_str = (p.git and p.git.branch) and ("[" .. tostring(p.git.branch) .. "]") or "[main]"

      -- In panoramica bastano le novita' piu' fresche: la cronologia completa
      -- ('c') le elenca comunque tutte, senza comprimere niente.
      local inc_shown = math.min(3, #incoming)
      for i = 1, inc_shown do
        add_commit_row(incoming[i], incoming_branch, pw - 4)
      end
      if #incoming > inc_shown then
        add("   " .. i18n.t("incoming_more", #incoming - inc_shown), "ProjectsIncomingLabel")
      end
      if #incoming > 0 then
        add_incoming_divider(#incoming, incoming_up, pw - 4)
      end

      for i = 1, visible_commits do
        add_commit_row(commits[i], branch_str, pw - 4)
      end

      if #commits > 5 then
        local diff_c = #commits - 5
        local c_more = "   " .. ((diff_c == 1) and i18n.t("commits_more_1") or i18n.t("commits_more", diff_c))
        add(c_more, "ProjectsMeta")
        local l_idx = #lines - 1
        local c_marker = i18n.t("press_c")
        local c_pos = c_more:find(c_marker, 1, true)
        if c_pos then
          hls[#hls + 1] = { l_idx, c_pos + #c_marker - 1, c_pos + #c_marker, "ProjectsKeyText" }
        end
      end
    else
      add("   " .. i18n.t("commits_none"), "ProjectsDesc")
  end

  -- Boxed Post-It Card in Bottom 1/3
  add("")
    local max_box_dw = pw - 4
    local top_head = "  ┌─ " .. ICON_NOTE .. " " .. i18n.t("notes_title") .. " "
    local top_head_dw = vim.api.nvim_strwidth(top_head)
    local top_fill = math.max(0, max_box_dw - top_head_dw - 1)
    local top_border = top_head .. string.rep("─", top_fill) .. "┐"
    add(top_border, "ProjectsName")

    local function add_box_row(txt, hl, align_center)
      local prefix = "  │ "
      local suffix = " │"
      local inner_target_dw = max_box_dw - dw(prefix) - dw(suffix)

      local txt_dw = dw(txt)
      if txt_dw > inner_target_dw then
        txt = fit(txt, inner_target_dw)
        txt_dw = dw(txt)
      end

      local pad_l = 1
      local pad_r = 1
      if align_center then
        pad_l = math.max(1, math.floor((inner_target_dw - txt_dw) / 2))
        pad_r = math.max(1, inner_target_dw - pad_l - txt_dw)
      else
        pad_l = 2
        pad_r = math.max(1, inner_target_dw - pad_l - txt_dw)
      end

      local line_str = prefix .. string.rep(" ", pad_l) .. txt .. string.rep(" ", pad_r) .. suffix
      add(line_str)

      local r_idx = #lines - 1
      hls[#hls + 1] = { r_idx, 0, #prefix, "ProjectsName" }

      if txt ~= "" then
        local t_start = #prefix + pad_l
        local t_end = t_start + #txt
        hls[#hls + 1] = { r_idx, t_start, t_end, hl }
      end

      local s_start = #line_str - #suffix
      hls[#hls + 1] = { r_idx, s_start, #line_str, "ProjectsName" }

      local n_marker = i18n.t("press_n")
      if txt:find(n_marker, 1, true) then
        local k_start = line_str:find(n_marker, 1, true)
        if k_start then
          hls[#hls + 1] = { r_idx, k_start + #n_marker - 1, k_start + #n_marker, "ProjectsKeyText" }
        end
      end
    end

    local note_lines = {}
    local is_custom_note = note and vim.trim(note) ~= ""
    local max_txt_w = math.max(20, max_box_dw - 8)

    if is_custom_note then
      note_lines = wrap_text(vim.trim(note), max_txt_w)
    else
      note_lines = {
        ICON_NOTE .. " " .. i18n.t("notes_empty_1"),
        i18n.t("notes_empty_2"),
        "",
        i18n.t("notes_hint"),
      }
    end

    local cur_count = #lines
    local target_bot_line = ph - 1
    local content_rows_count = math.max(4, target_bot_line - cur_count - 1)

    local extra_stats_rows = is_custom_note and 2 or 0
    local n_content = #note_lines + extra_stats_rows
    local top_pad = math.max(1, math.floor((content_rows_count - n_content) / 2))
    local bot_pad = math.max(0, content_rows_count - top_pad - n_content)

    for _ = 1, top_pad do
      add_box_row("", "ProjectsDesc", true)
    end

    for _, txt in ipairs(note_lines) do
      add_box_row(txt, is_custom_note and "ProjectsPostItText" or "ProjectsDesc", is_custom_note and false or true)
    end

    if is_custom_note then
      add_box_row("", "ProjectsDesc", true)
      local clean_n = vim.trim(note)
      local c_cnt = #clean_n
      local w_cnt = 0
      for _ in clean_n:gmatch("%S+") do w_cnt = w_cnt + 1 end
      local stats_str = ""
      if w_cnt == 1 and c_cnt == 1 then
        stats_str = i18n.t("notes_stats_1_1")
      elseif w_cnt == 1 then
        stats_str = i18n.t("notes_stats_1_n", c_cnt)
      elseif c_cnt == 1 then
        stats_str = i18n.t("notes_stats_n_1", w_cnt)
      else
        stats_str = i18n.t("notes_stats", w_cnt, c_cnt)
      end
      add_box_row(stats_str, "ProjectsMeta", true)
    end

    for _ = 1, bot_pad do
      add_box_row("", "ProjectsDesc", true)
    end

    local bot_fill = math.max(0, max_box_dw - 4)
    local bot_border = "  └" .. string.rep("─", bot_fill) .. "┘"
    add(bot_border, "ProjectsName")
  end
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, h in ipairs(hls) do
    pcall(vim.api.nvim_buf_set_extmark, buf, ns, h[1], h[2], { end_col = h[3], hl_group = h[4] })
  end

  vim.api.nvim_win_set_buf(st.preview.win, buf)
  st.preview.shown = buf

  if saved_view and vim.api.nvim_win_is_valid(st.preview.win) then
    pcall(vim.api.nvim_win_call, st.preview.win, function()
      vim.fn.winrestview(saved_view)
    end)
  end

  local gh_url = P.get_github_url(p.path)
  local has_git = p.git and not p.git.none
  local html_file = P.get_html_preview_file(p.path)
  local readme = P.readme_path(p.path)

  -- Su un'unita' scollegata i file non ci sono: nota, albero e cronologia non
  -- avrebbero nulla su cui lavorare, e un tasto che non fa niente e' peggio di
  -- un tasto assente. Resta GitHub, che vive nella cache dei metadati e quindi
  -- funziona anche a disco staccato.
  local offline = p.is_disconnected or p.is_missing
  local footer_preview = {}
  if not st.show_all_commits and not offline then
    footer_preview[#footer_preview + 1] = { " " .. i18n.t("btn_note") .. " ", "ProjectsLazyBtnLabel" }
    footer_preview[#footer_preview + 1] = { " n ", "ProjectsLazyBtnKey" }
  end

  if has_git and not offline then
    if #footer_preview > 0 then
      footer_preview[#footer_preview + 1] = { "  ", "NormalFloat" }
    end
    footer_preview[#footer_preview + 1] = { " " .. i18n.t("btn_commit") .. " ", "ProjectsLazyBtnLabel" }
    footer_preview[#footer_preview + 1] = { " c ", "ProjectsLazyBtnKey" }
  end

  if not offline then
    footer_preview[#footer_preview + 1] = { "  ", "NormalFloat" }
    if readme then
      footer_preview[#footer_preview + 1] = { " " .. i18n.t("btn_readme") .. " ", "ProjectsLazyBtnLabel" }
    else
      footer_preview[#footer_preview + 1] = { " " .. i18n.t("btn_tree") .. " ", "ProjectsLazyBtnLabel" }
    end
    footer_preview[#footer_preview + 1] = { " s ", "ProjectsLazyBtnKey" }
  end



  if html_file then
    footer_preview[#footer_preview + 1] = { "  ", "NormalFloat" }
    footer_preview[#footer_preview + 1] = { " " .. i18n.t("btn_web_preview") .. " ", "ProjectsLazyBtnLabel" }
    footer_preview[#footer_preview + 1] = { " w ", "ProjectsLazyBtnKey" }
  end

  local remote_label = i18n.t("btn_github")
  local meta = P.get_github_meta(p.path)
  if meta and meta.forge == "gitlab" then
    remote_label = "GitLab"
  elseif meta and meta.forge == "bitbucket" then
    remote_label = "Bitbucket"
  elseif meta and meta.forge == "codeberg" then
    remote_label = "Codeberg"
  elseif meta and meta.forge == "git" then
    remote_label = "Git"
  end

  if gh_url and gh_url ~= "" then
    footer_preview[#footer_preview + 1] = { "  ", "NormalFloat" }
    footer_preview[#footer_preview + 1] = { " " .. remote_label .. " ", "ProjectsLazyBtnLabel" }
    footer_preview[#footer_preview + 1] = { " g ", "ProjectsLazyBtnKey" }
  end

  if p.is_missing then
    footer_preview[#footer_preview + 1] = { "  ", "NormalFloat" }
    footer_preview[#footer_preview + 1] = { " " .. i18n.t("btn_reconnect") .. " ", "ProjectsLazyBtnLabel" }
    footer_preview[#footer_preview + 1] = { " r ", "ProjectsLazyBtnKey" }
  end



  pcall(vim.api.nvim_win_set_config, st.preview.win, {
    title = { { " " .. ICON_OVERVIEW .. " " .. (st.show_all_commits and i18n.t("title_commits") or i18n.t("title_info")) .. " ", "ProjectsTitleSpecial" } },
    title_pos = "right",
    footer = footer_preview,
    footer_pos = "center",
  })
  pcall(vim.api.nvim_win_set_cursor, st.preview.win, { 1, 0 })
  render_preview_scrollbar(st)
end

render_preview = function(st)
  -- Durante il benvenuto il pannello destro resta vuoto: non c'e' nessun
  -- progetto da ispezionare e il riquadro "anteprima non disponibile"
  -- distrarrebbe dalla scelta da fare.
  if st.welcome_mode and not st.dir_picker_mode then
    if not (st.preview.buf and vim.api.nvim_buf_is_valid(st.preview.buf)) then
      st.preview.buf = vim.api.nvim_create_buf(false, true)
    end
    local buf = st.preview.buf
    vim.bo[buf].modifiable = true
    vim.bo[buf].readonly = false

    local ph = vim.api.nvim_win_is_valid(st.preview.win) and vim.api.nvim_win_get_height(st.preview.win) or 20
    local pw = vim.api.nvim_win_is_valid(st.preview.win) and vim.api.nvim_win_get_width(st.preview.win) or 40

    -- Stesso font gigante del riquadro "anteprima non disponibile": il nome del
    -- prodotto non si traduce, quindi una sola versione per entrambe le lingue.
    local art_project = {
      "██████╗ ██████╗  ██████╗      ██╗███████╗ ██████╗████████╗",
      "██╔══██╗██╔══██╗██╔═══██╗     ██║██╔════╝██╔════╝╚══██╔══╝",
      "██████╔╝██████╔╝██║   ██║     ██║█████╗  ██║        ██║   ",
      "██╔═══╝ ██╔══██╗██║   ██║██   ██║██╔══╝  ██║        ██║   ",
      "██║     ██║  ██║╚██████╔╝╚█████╔╝███████╗╚██████╗   ██║   ",
      "╚═╝     ╚═╝  ╚═╝ ╚═════╝  ╚════╝ ╚══════╝ ╚═════╝   ╚═╝   ",
    }
    local art_hub = {
      "██╗  ██╗██╗   ██╗██████╗ ",
      "██║  ██║██║   ██║██╔══██╗",
      "███████║██║   ██║██████╔╝",
      "██╔══██║██║   ██║██╔══██╗",
      "██║  ██║╚██████╔╝██████╔╝",
      "╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ",
    }

    local w_lines, w_hls = {}, {}
    local function wadd(text, hl)
      local pad = string.rep(" ", math.max(0, math.floor((pw - dw(text)) / 2)))
      w_lines[#w_lines + 1] = pad .. text
      if hl then w_hls[#w_hls + 1] = { #w_lines - 1, #pad, #pad + #text, hl } end
    end

    --- centra un blocco di testo gigante mantenendo l'allineamento interno:
    --- centrare riga per riga sfalserebbe le lettere fra loro
    local function add_block(block, hl)
      local maxw = 0
      for _, l in ipairs(block) do maxw = math.max(maxw, dw(l)) end
      local pad = string.rep(" ", math.max(0, math.floor((pw - maxw) / 2)))
      for _, l in ipairs(block) do
        w_lines[#w_lines + 1] = pad .. l
        w_hls[#w_hls + 1] = { #w_lines - 1, #pad, #(pad .. l), hl }
      end
    end

    local top = math.max(1, math.floor((ph - #art_project - #art_hub - 5) / 2))
    for _ = 1, top do w_lines[#w_lines + 1] = "" end
    add_block(art_project, "ProjectsTitleSpecial")
    w_lines[#w_lines + 1] = ""
    add_block(art_hub, "ProjectsTitleSpecial")
    w_lines[#w_lines + 1] = ""
    w_lines[#w_lines + 1] = ""
    wadd(i18n.t("welcome_title"), "ProjectsName")
    for _ = 1, ph do w_lines[#w_lines + 1] = "" end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, w_lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true
    vim.bo[buf].filetype = ""
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for _, h in ipairs(w_hls) do
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, h[1], h[2], { end_col = h[3], hl_group = h[4] })
    end
    vim.api.nvim_win_set_buf(st.preview.win, buf)
    st.preview.shown = buf
    pcall(vim.api.nvim_win_set_config, st.preview.win, { title = "", footer = "" })
    pcall(vim.api.nvim_win_set_cursor, st.preview.win, { 1, 0 })
    return
  end

  if st.dir_picker_mode then
    render_preview_scrollbar(st)
    if not vim.api.nvim_buf_is_valid(st.preview.buf) then
      st.preview.buf = vim.api.nvim_create_buf(false, true)
    end
    local buf = st.preview.buf
    vim.bo[buf].modifiable = true
    vim.bo[buf].readonly = false

    local lines = {}
    local hls = {}
    local add = function(t, hl)
      lines[#lines + 1] = t
      if hl then hls[#hls + 1] = { #lines - 1, 0, #t, hl } end
    end

    local curr_dir = st.dir_curr_dir or vim.fn.expand("~")
    local sel_entry = st.dir_entries and st.dir_entries[st.dir_sel or 1]
    local target_path = (sel_entry and sel_entry.type == "dir") and sel_entry.full or curr_dir

    add("")
    local relocate_p = st.dir_picker_relocate
    if relocate_p then
      add("  " .. ICON_FOLDER_INSPECT .. " " .. i18n.t("relocate_title", relocate_p.name), "ProjectsTitleSpecial")
      add("   " .. i18n.t("relocate_old_path", relocate_p.path), "ProjectsMissingPathPlain")
      add("   " .. i18n.t("relocate_new_path", target_path), "ProjectsDir")
    else
      add("  " .. ICON_FOLDER_INSPECT .. " " .. i18n.t("dirpicker_title"), "ProjectsTitleSpecial")
      add("   " .. i18n.t("dirpicker_path", target_path), "ProjectsDir")
    end
    add("")

    local sub_dirs_cnt, files_cnt = 0, 0
    local handle = vim.uv.fs_scandir(target_path)
    if handle then
      while true do
        local name, t = vim.uv.fs_scandir_next(handle)
        if not name then break end
        if name:sub(1, 1) ~= "." then
          if t == "directory" then sub_dirs_cnt = sub_dirs_cnt + 1 else files_cnt = files_cnt + 1 end
        end
      end
    end

    local sel_name = (sel_entry and sel_entry.type == "dir") and sel_entry.name or vim.fn.fnamemodify(target_path, ":t")
    if not sel_name or sel_name == "" or sel_name == "/" then sel_name = i18n.t("generic_folder") end

    local pw = vim.api.nvim_win_is_valid(st.preview.win) and vim.api.nvim_win_get_width(st.preview.win) or 50
    local ph = vim.api.nvim_win_is_valid(st.preview.win) and vim.api.nvim_win_get_height(st.preview.win) or 20

    local s_sub = (sub_dirs_cnt == 1) and i18n.t("dirpicker_subdirs_1") or i18n.t("dirpicker_subdirs", fmt_num(sub_dirs_cnt))
    local s_fil = (files_cnt == 1) and i18n.t("dirpicker_files_1") or i18n.t("dirpicker_files", fmt_num(files_cnt))
    add("   " .. ICON_FOLDER .. " " .. s_sub, "ProjectsGitBranch")
    add("   " .. ICON_DOC .. " " .. s_fil, "ProjectsGitBranch")
    -- Vertical centering for Callout Box inside preview panel
    local cur_cnt = #lines
    local top_pad_lines = math.max(2, math.floor((ph - cur_cnt - 3) / 2))
    for _ = 1, top_pad_lines do add("") end

    local is_already = P.is_project(target_path)

    local raw_inner
    if is_already then
      raw_inner = ICON_SUCCESS .. " " .. i18n.t("dirpicker_already", sel_name)
    elseif relocate_p then
      raw_inner = ICON_ADD .. " " .. i18n.t("dirpicker_reconnect", relocate_p.name)
    else
      raw_inner = ICON_ADD .. " " .. i18n.t("dirpicker_add", sel_name)
    end
    local raw_dw = dw(raw_inner)
    local box_w = math.max(44, math.min(pw - 6, raw_dw + 4))

    local pad_l = math.max(1, math.floor((box_w - raw_dw) / 2))
    local pad_r = math.max(1, box_w - raw_dw - pad_l)

    local outer_margin = string.rep(" ", math.max(1, math.floor((pw - box_w - 2) / 2)))

    local border_top = outer_margin .. "┌" .. string.rep("─", box_w) .. "┐"
    local border_bot = outer_margin .. "└" .. string.rep("─", box_w) .. "┘"
    local box_line   = outer_margin .. "│" .. string.rep(" ", pad_l) .. raw_inner .. string.rep(" ", pad_r) .. "│"

    local border_hl = is_already and "ProjectsHeaderPublic" or "ProjectsDirBoxBorder"

    add(border_top, border_hl)
    lines[#lines + 1] = box_line
    local b_row = #lines - 1
    hls[#hls + 1] = { b_row, 0, #box_line, border_hl }

    if is_already then
      hls[#hls + 1] = { b_row, #outer_margin + 3, #box_line - 3, "ProjectsHeaderPublic" }
    else
      local a_start = box_line:find("%s+a%s+")
      if a_start then
        hls[#hls + 1] = { b_row, #outer_margin + 3, a_start, "ProjectsDirBoxText" }
        hls[#hls + 1] = { b_row, a_start, a_start + 3, "ProjectsDirKeyBadge" }
        hls[#hls + 1] = { b_row, a_start + 3, #box_line - 3, "ProjectsDirBoxText" }
      else
        hls[#hls + 1] = { b_row, #outer_margin + 3, #box_line - 3, "ProjectsDirBoxText" }
      end
    end

    add(border_bot, border_hl)

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for _, h in ipairs(hls) do
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, h[1], h[2], { end_col = h[3], hl_group = h[4] })
    end
    vim.api.nvim_win_set_buf(st.preview.win, buf)
    pcall(vim.api.nvim_win_set_config, st.preview.win, { title = "", footer = "" })
    return
  end
  if #st.items == 0 then
    if not vim.api.nvim_buf_is_valid(st.preview.buf) then
      st.preview.buf = vim.api.nvim_create_buf(false, true)
    end
    local buf = st.preview.buf
    vim.bo[buf].modifiable = true
    vim.bo[buf].readonly = false

    local ph = vim.api.nvim_win_is_valid(st.preview.win) and vim.api.nvim_win_get_height(st.preview.win) or 20
    local pw = vim.api.nvim_win_is_valid(st.preview.win) and vim.api.nvim_win_get_width(st.preview.win) or 40

    local p_lines = {}
    local p_hls = {}

    local art_it = {
      " █████╗ ███╗   ██╗████████╗███████╗██████╗ ██████╗ ██╗███╗   ███╗ █████╗ ",
      "██╔══██╗████╗  ██║╚══██╔══╝██╔════╝██╔══██╗██╔══██╗██║████╗ ████║██╔══██╗",
      "███████║██╔██╗ ██║   ██║   █████╗  ██████╔╝██████╔╝██║██╔████╔██║███████║",
      "██╔══██║██║╚██╗██║   ██║   ██╔══╝  ██╔═══╝ ██╔══██╗██║██║╚██╔╝██║██╔══██║",
      "██║  ██║██║ ╚████║   ██║   ███████╗██║     ██║  ██║██║██║ ╚═╝ ██║██║  ██║",
      "╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝     ╚═╝  ╚═╝╚═╝╚═╝     ╚═╝╚═╝  ╚═╝",
      "",
      "███╗   ██╗ ██████╗ ███╗   ██╗",
      "████╗  ██║██╔═══██╗████╗  ██║",
      "██╔██╗ ██║██║   ██║██╔██╗ ██║",
      "██║╚██╗██║██║   ██║██║╚██╗██║",
      "██║ ╚████║╚██████╔╝██║ ╚████║",
      "╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═══╝",
      "",
      "██████╗ ██╗███████╗██████╗  ██████╗ ███╗   ██╗██╗██████╗ ██╗██╗     ███████╗",
      "██╔══██╗██║██╔════╝██╔══██╗██╔═══██╗████╗  ██║██║██╔══██╗██║██║     ██╔════╝",
      "██║  ██║██║███████╗██████╔╝██║   ██║██╔██╗ ██║██║██████╔╝██║██║     █████╗  ",
      "██║  ██║██║╚════██║██╔═══╝ ██║   ██║██║╚██╗██║██║██╔══██╗██║██║     ██╔══╝  ",
      "██████╔╝██║███████║██║     ╚██████╔╝██║ ╚████║██║██████╔╝██║███████╗███████╗",
      "╚═════╝ ╚═╝╚══════╝╚═╝      ╚═════╝ ╚═╝  ╚═══╝╚═╝╚═════╝ ╚═╝╚══════╝╚══════╝",
    }

    local art_en = {
      "██████╗ ██████╗ ███████╗██╗   ██╗██╗███████╗██╗    ██╗",
      "██╔══██╗██╔══██╗██╔════╝██║   ██║██║██╔════╝██║    ██║",
      "██████╔╝██████╔╝█████╗  ██║   ██║██║█████╗  ██║ █╗ ██║",
      "██╔═══╝ ██╔══██╗██╔══╝  ╚██╗ ██╔╝██║██╔══╝  ██║███╗██║",
      "██║     ██║  ██║███████╗ ╚████╔╝ ██║███████╗╚███╔███╔╝",
      "╚═╝     ╚═╝  ╚═╝╚══════╝  ╚═══╝  ╚═╝╚══════╝ ╚══╝╚══╝ ",
      "",
      "███╗   ██╗ ██████╗ ████████╗",
      "████╗  ██║██╔═══██╗╚══██╔══╝",
      "██╔██╗ ██║██║   ██║   ██║   ",
      "██║╚██╗██║██║   ██║   ██║   ",
      "██║ ╚████║╚██████╔╝   ██║   ",
      "╚═╝  ╚═══╝ ╚═════╝    ╚═╝   ",
      "",
      " █████╗ ██╗   ██╗ █████╗ ██╗██╗      █████╗ ██████╗ ██╗     ███████╗",
      "██╔══██╗██║   ██║██╔══██╗██║██║     ██╔══██╗██╔══██╗██║     ██╔════╝",
      "███████║██║   ██║███████║██║██║     ███████║██████╔╝██║     █████╗  ",
      "██╔══██║╚██╗ ██╔╝██╔══██║██║██║     ██╔══██║██╔══██╗██║     ██╔══╝  ",
      "██║  ██║ ╚████╔╝ ██║  ██║██║███████╗██║  ██║██████╔╝███████╗███████╗",
      "╚═╝  ╚═╝  ╚═══╝  ╚═╝  ╚═╝╚═╝╚══════╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝",
    }

    local art = (i18n.get_lang() == "it") and art_it or art_en

    local top_pad = math.max(1, math.floor((ph - #art) / 2))
    for _ = 1, top_pad do p_lines[#p_lines + 1] = "" end

    for _, a in ipairs(art) do
      local pad = string.rep(" ", math.max(0, math.floor((pw - dw(a)) / 2)))
      p_lines[#p_lines + 1] = pad .. a
      p_hls[#p_hls + 1] = { #p_lines - 1, #pad, #pad + #a, "ProjectsName" }
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, p_lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

    for _, h in ipairs(p_hls) do
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, h[1], h[2], { end_col = h[3], hl_group = h[4] })
    end

    vim.api.nvim_win_set_buf(st.preview.win, buf)
    st.preview.shown = buf
    pcall(vim.api.nvim_win_set_config, st.preview.win, { title = "", footer = "" })
    if st.preview.sb_win and vim.api.nvim_win_is_valid(st.preview.sb_win) then
      pcall(vim.api.nvim_win_close, st.preview.sb_win, true)
    end
    return
  end


  local p = st.items[st.sel]
  if not (p and vim.api.nvim_win_is_valid(st.preview.win)) then
    clear_kitty_graphics()
    return
  end

  if st.web_preview_mode then
    local html_file = P.get_html_preview_file(p.path)
    if html_file then
      render_web_preview_in_box(st, p, vim.api.nvim_win_get_width(st.preview.win))
      return
    else
      st.web_preview_mode = false
      clear_kitty_graphics()
    end
  else
    clear_kitty_graphics()
  end

  if p.is_missing then
    if not vim.api.nvim_buf_is_valid(st.preview.buf) then
      st.preview.buf = vim.api.nvim_create_buf(false, true)
    end
    local buf = st.preview.buf
    vim.bo[buf].modifiable = true
    vim.bo[buf].readonly = false
    vim.bo[buf].bufhidden = "hide"

    local pw = vim.api.nvim_win_get_width(st.preview.win)
    local ph = vim.api.nvim_win_get_height(st.preview.win)
    local text_w = pw - 6

    local lines, hls = {}, {}

    -- Testo semplice centrato, senza riquadro disegnato: lo sfondo colorato
    -- resta solo sui badge dei tasti (r/d), non su ogni riga.
    local function centered_chunks(chunks)
      local total_w = 0
      for _, c in ipairs(chunks) do total_w = total_w + dw(c[1]) end
      local pad_l = math.max(0, math.floor((pw - total_w) / 2))
      local body = string.rep(" ", pad_l)
      local segs = {}
      for _, c in ipairs(chunks) do
        segs[#segs + 1] = { #body, #body + #c[1], c[2] }
        body = body .. c[1]
      end
      lines[#lines + 1] = body
      local row = #lines - 1
      for _, s in ipairs(segs) do
        if s[3] then
          hls[#hls + 1] = { row, s[1], s[2], s[3] }
        end
      end
    end

    local function centered_text(text, hl)
      centered_chunks({ { fit(text, text_w), hl } })
    end

    local desc_lines = wrap_text(i18n.t("missing_explanation"), text_w)
    local path_lines = wrap_text(p.path, text_w)

    local key_r = { { " r ", "ProjectsMissingKeyBadge" }, { " " .. i18n.t("missing_btn_reconnect"), "ProjectsMissingBtnLabel" } }
    local key_d = { { " d ", "ProjectsMissingKeyBadge" }, { " " .. i18n.t("missing_btn_remove"), "ProjectsMissingBtnLabel" } }
    local key_w = dw(" ") -- gap tra i due badge
    for _, c in ipairs(key_r) do key_w = key_w + dw(c[1]) end
    for _, c in ipairs(key_d) do key_w = key_w + dw(c[1]) end
    local key_rows = key_w <= text_w and 1 or 2

    local body_rows = 2 + #path_lines + 1 + #desc_lines + 2 + key_rows
    local top_pad = math.max(1, math.floor((ph - body_rows) / 2))
    for _ = 1, top_pad do lines[#lines + 1] = "" end

    centered_text("\u{26a0} " .. i18n.t("missing_warning"), "ProjectsMissingMsg")
    lines[#lines + 1] = ""
    for _, l in ipairs(path_lines) do centered_text(l, "ProjectsMissingPathPlain") end
    lines[#lines + 1] = ""
    for _, l in ipairs(desc_lines) do centered_text(l, "ProjectsMissingHint") end
    lines[#lines + 1] = ""
    centered_text(i18n.t("missing_press_keys"), "ProjectsMissingHint")

    if key_rows == 1 then
      local both = {}
      vim.list_extend(both, key_r)
      both[#both + 1] = { " ", nil }
      vim.list_extend(both, key_d)
      centered_chunks(both)
    else
      centered_chunks(key_r)
      centered_chunks(key_d)
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true
    vim.bo[buf].filetype = ""
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for _, h in ipairs(hls) do
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, h[1], h[2], { end_col = h[3], hl_group = h[4] })
    end
    vim.api.nvim_win_set_buf(st.preview.win, buf)
    st.preview.shown = buf
    pcall(vim.api.nvim_win_set_config, st.preview.win, { title = "", title_pos = "right" })
    pcall(vim.api.nvim_win_set_cursor, st.preview.win, { 1, 0 })
    render_preview_scrollbar(st)
    return
  end

  if (st.view_mode or "inspector") == "inspector" then
    render_inspector(st)
    return
  end

  clear_kitty_graphics()
  local readme = P.readme_path(p.path)
  local title = ""
  local buf

  local w = st.preview.win
  if vim.api.nvim_win_is_valid(w) then
    pcall(vim.api.nvim_set_option_value, "spell", false, { win = w })
    pcall(vim.api.nvim_set_option_value, "number", false, { win = w })
    pcall(vim.api.nvim_set_option_value, "wrap", true, { win = w })
    pcall(vim.api.nvim_set_option_value, "linebreak", true, { win = w })
    pcall(vim.api.nvim_set_option_value, "conceallevel", (readme and st.view_mode ~= "tree") and 3 or 0, { win = w })
    pcall(vim.api.nvim_set_option_value, "concealcursor", "nvic", { win = w })
  end

  if readme then
    if not (st.preview.buf and vim.api.nvim_buf_is_valid(st.preview.buf)) then
      st.preview.buf = vim.api.nvim_create_buf(false, true)
    end
    buf = st.preview.buf

    local need_reload = (st.preview_loaded_readme ~= readme) or (vim.bo[buf].filetype ~= "markdown")
    if need_reload then
      st.preview_loaded_readme = readme
      vim.bo[buf].modifiable = true
      vim.bo[buf].readonly = false

      local ok_lines, lines = pcall(vim.fn.readfile, readme)
      if ok_lines and lines then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      else
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
      end

      vim.bo[buf].modifiable = false
      vim.bo[buf].readonly = true
      vim.bo[buf].filetype = "markdown"

      conceal_html_tags(buf)

      local ok_rm_ui, rm_ui = pcall(require, "render-markdown.core.ui")
      if ok_rm_ui and rm_ui.update then
        pcall(rm_ui.update, buf, st.preview.win)
      end
    end

    vim.api.nvim_win_set_buf(st.preview.win, buf)
    pcall(vim.api.nvim_set_option_value, "conceallevel", 3, { win = st.preview.win })
    pcall(vim.api.nvim_set_option_value, "concealcursor", "nvic", { win = st.preview.win })
    pcall(vim.api.nvim_set_option_value, "spell", false, { win = st.preview.win })

    st.preview.shown = buf
    title = vim.fn.fnamemodify(readme, ":t")
  else
    if not vim.api.nvim_buf_is_valid(st.preview.buf) then
      st.preview.buf = vim.api.nvim_create_buf(false, true)
    end
    buf = st.preview.buf
    vim.bo[buf].modifiable = true
    vim.bo[buf].readonly = false
    vim.bo[buf].bufhidden = "hide"
    local lines, hls = tree(p.path, 200)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true
    vim.bo[buf].filetype = ""
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for _, h in ipairs(hls or {}) do
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, h[1], h[2], { end_col = h[3], hl_group = h[4] })
    end
    vim.api.nvim_win_set_buf(st.preview.win, buf)
    st.preview.shown = buf
  end

  local gh_url = P.get_github_url(p.path)
  local html_file = P.get_html_preview_file(p.path)

  local footer_preview = {
    { " " .. i18n.t("btn_note") .. " ", "ProjectsLazyBtnLabel" },
    { " n ", "ProjectsLazyBtnKey" },
  }

  footer_preview[#footer_preview + 1] = { "  ", "NormalFloat" }
  footer_preview[#footer_preview + 1] = { " " .. i18n.t("btn_inspector") .. " ", "ProjectsLazyBtnLabel" }
  footer_preview[#footer_preview + 1] = { " s ", "ProjectsLazyBtnKey" }



  if html_file then
    footer_preview[#footer_preview + 1] = { "  ", "NormalFloat" }
    footer_preview[#footer_preview + 1] = { " " .. i18n.t("btn_web_preview") .. " ", "ProjectsLazyBtnLabel" }
    footer_preview[#footer_preview + 1] = { " w ", "ProjectsLazyBtnKey" }
  end

  local remote_label = i18n.t("btn_github")
  local meta = P.get_github_meta(p.path)
  if meta and meta.forge == "gitlab" then
    remote_label = "GitLab"
  elseif meta and meta.forge == "bitbucket" then
    remote_label = "Bitbucket"
  elseif meta and meta.forge == "codeberg" then
    remote_label = "Codeberg"
  elseif meta and meta.forge == "git" then
    remote_label = "Git"
  end

  if gh_url and gh_url ~= "" then
    footer_preview[#footer_preview + 1] = { "  ", "NormalFloat" }
    footer_preview[#footer_preview + 1] = { " " .. remote_label .. " ", "ProjectsLazyBtnLabel" }
    footer_preview[#footer_preview + 1] = { " g ", "ProjectsLazyBtnKey" }
  end



  pcall(vim.api.nvim_win_set_config, st.preview.win, {
    title = { { " " .. title .. " ", "ProjectsName" } },
    title_pos = "right",
    footer = footer_preview,
    footer_pos = "center",
  })
  pcall(vim.api.nvim_win_set_cursor, st.preview.win, { 1, 0 })
  render_preview_scrollbar(st)
end

ensure_visible = function(st)
  local win = st.list.win
  if not (win and vim.api.nvim_win_is_valid(win)) then return end
  local pos = st.pos and st.pos[st.sel]
  if not pos then return end

  local h = vim.api.nvim_win_get_height(win)
  local vista = vim.api.nvim_win_call(win, vim.fn.winsaveview)
  local topline = vista.topline or 1
  local card_bottom = pos + CARD_ROWS - 1
  local margin_bottom = 4

  local new_top = topline
  if pos < topline then
    new_top = pos
    if pos > 3 then
      local line_above = vim.api.nvim_buf_get_lines(st.list.buf, pos - 3, pos - 2, false)[1] or ""
      if line_above:match("──") then
        new_top = pos - 2
      end
    end
  elseif card_bottom + margin_bottom > topline + h - 1 then
    new_top = card_bottom + margin_bottom - h + 1
  end

  new_top = math.max(1, new_top)
  if new_top ~= topline then
    vim.api.nvim_win_call(win, function()
      vim.fn.winrestview({ topline = new_top, lnum = new_top, col = 0 })
    end)
  end
  render_scrollbar(st)
end

sync_sel_with_scroll = function(st)
  local win = st.list.win
  if not (win and vim.api.nvim_win_is_valid(win)) then return end
  local vista = vim.api.nvim_win_call(win, vim.fn.winsaveview)
  local topline = vista.topline or 1
  local h = vim.api.nvim_win_get_height(win)
  local center_line = topline + math.floor(h / 2)

  local best_idx, min_dist = st.sel, 999999
  if st.pos then
    for idx, lnum in pairs(st.pos) do
      local mid = lnum + math.floor(CARD_ROWS / 2)
      local dist = math.abs(mid - center_line)
      if dist < min_dist then
        min_dist = dist
        best_idx = idx
      end
    end
  end

  if best_idx ~= st.sel then
    st.sel = best_idx
    render_list(st)
    render_preview(st)
  else
    render_scrollbar(st)
  end
end

render_list = function(st, is_marquee_tick)
  local w = st.list.width
  local cols = w >= (M.config.min_card * 2 + 4) and 2 or 1
  local cw, pad_left, col_gap
  if cols == 2 then
    cw = math.floor((w - 3) / 2)
    pad_left = " "
    col_gap = " "
  else
    cw = math.max(20, w - 2)
    local pad_w = math.max(1, math.floor((w - cw) / 2))
    pad_left = string.rep(" ", pad_w)
    col_gap = ""
  end
  st.cols, st.card_width = cols, cw

  local lines, hls, pos, rows = {}, {}, {}, {}

  local function push(text, chunk_hls)
    lines[#lines + 1] = text
    for _, h in ipairs(chunk_hls or {}) do
      hls[#hls + 1] = { #lines - 1, h[1], h[2], h[3], priority = 200 }
    end
  end

  local function divider(label, is_first)
    local text, lhls = join({
      { "── ", "ProjectsMeta" },
      { label, "ProjectsGitBranch" },
      { " " .. string.rep("─", math.max(0, w - 5 - dw(label))), "ProjectsMeta" },
    })
    if not is_first then
      push("")
    end
    push(text, lhls)
  end

  if st.welcome_mode and not st.dir_picker_mode then
    lines, hls = {}, {}
    local h = vim.api.nvim_win_is_valid(st.list.win) and vim.api.nvim_win_get_height(st.list.win) or 24

    local function centered(text, hl)
      local pad = string.rep(" ", math.max(0, math.floor((w - dw(text)) / 2)))
      push(pad .. text, hl and { { #pad, #pad + #text, hl } } or nil)
    end

    --- riga "  <icona>  Etichetta                 <tasto> ", stile dei footer
    local function option(icon, label, desc, key, hl_icon)
      -- La pillola resta accanto all'etichetta invece di essere spinta al bordo
      -- destro: con riquadri larghi finiva a mezzo schermo di distanza e non si
      -- capiva piu' quale tasto appartenesse a quale voce.
      local left = "   " .. icon .. "  " .. label
      local badge = " " .. key .. " "
      local gap = math.max(2, w - 5 - dw(left) - dw(badge))
      local text, lhls = join({
        { left, hl_icon },
        { string.rep(" ", gap) },
        { badge, "ProjectsLazyBtnKey" },
      })
      push(text, lhls)
      if desc ~= "" then
        local d = fit(desc, w - 9)
        push("      " .. d, { { 6, 6 + #d, "ProjectsDesc" } })
      end
      push("")
    end

    -- Le due righe di contorno stanno agli estremi del riquadro, entrambe in
    -- grigio: sono contesto, non scelte. In mezzo, centrato, resta solo cio'
    -- su cui l'utente deve agire.
    push("")
    centered(fit(i18n.t("welcome_sub"), w - 4), "ProjectsMeta")

    -- il blocco centrale si costruisce a parte, per poterlo centrare
    -- verticalmente rispetto allo spazio che resta
    local mid_first = #lines + 1
    local howto = i18n.t("welcome_howto")
    centered(fit(howto, w - 4), "ProjectsName")
    push("")

    option(ICON_FOLDER_INSPECT, i18n.t("welcome_scan_label"), i18n.t("welcome_scan_desc"), "s", "ProjectsGitBranch")
    option(ICON_ADD, i18n.t("welcome_manual_label"), i18n.t("welcome_manual_desc"), "a", "ProjectsHeaderPublic")

    -- "Esci" e' una via d'uscita, non una scelta alla pari: sta centrata sotto
    -- le due opzioni vere, tutta in rosso compresa la pillola del tasto.
    push("")
    local q_label = i18n.t("welcome_quit_label") .. "   "
    local q_key = " q "
    local q_pad = string.rep(" ", math.max(0, math.floor((w - dw(q_label) - dw(q_key)) / 2)))
    local q_text, q_hls = join({
      { q_pad },
      { q_label, "ProjectsHeaderMissing" },
      { q_key, "ProjectsQuitKey" },
    })
    push(q_text, q_hls)
    local mid_count = #lines - mid_first + 1

    -- si sposta il blocco centrale al centro verticale, e il suggerimento
    -- finisce sull'ultima riga utile del riquadro
    local hint_line = h - 1
    local mid_top = math.max(mid_first, math.floor((hint_line - mid_count) / 2))
    local spacer = math.max(0, mid_top - mid_first)
    if spacer > 0 then
      for _ = 1, spacer do table.insert(lines, mid_first, "") end
      for _, hl in ipairs(hls) do
        if hl[1] >= mid_first - 1 then hl[1] = hl[1] + spacer end
      end
    end

    while #lines < hint_line - 1 do push("") end
    centered(fit(i18n.t("welcome_config_hint"), w - 4), "ProjectsMeta")

    for _ = 1, h do push("") end

    vim.bo[st.list.buf].modifiable = true
    vim.api.nvim_buf_set_lines(st.list.buf, 0, -1, false, lines)
    vim.bo[st.list.buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(st.list.buf, ns, 0, -1)
    for _, hl in ipairs(hls) do
      pcall(vim.api.nvim_buf_set_extmark, st.list.buf, ns, hl[1], hl[2], {
        end_col = hl[3], hl_group = hl[4], hl_mode = "combine", priority = 200,
      })
    end
    -- Nel benvenuto non c'e' niente da filtrare: la barra mostra il titolo e
    -- resta inerte, cosi' l'unica cosa da fare e' premere uno dei tasti.
    -- Si svuota il contenuto ma il buffer resta modificabile: bloccarlo
    -- romperebbe il browser cartelle, che scrive qui la propria riga di
    -- ricerca. Non serve comunque: senza i tasti / f i la barra e'
    -- irraggiungibile, il focus resta sulla lista.
    if vim.api.nvim_buf_is_valid(st.input.buf) then
      vim.bo[st.input.buf].modifiable = true
      vim.api.nvim_buf_set_lines(st.input.buf, 0, -1, false, { "" })
    end
    pcall(vim.api.nvim_win_set_config, st.input.win, {
      title = { { " " .. ICON_OVERVIEW .. " " .. i18n.t("welcome_title") .. " ", "ProjectsTitleSpecial" } },
      title_pos = "left",
    })
    render_preview(st)
    return
  end

  if st.dir_picker_mode then
    lines, hls = {}, {}
    local curr_dir = st.dir_curr_dir or vim.fn.expand("~")
    local subdirs = {}
    local handle = vim.uv.fs_scandir(curr_dir)
    if handle then
      while true do
        local name, t = vim.uv.fs_scandir_next(handle)
        if not name then break end
        if t == "directory" and name:sub(1, 1) ~= "." then
          subdirs[#subdirs + 1] = name
        end
      end
    end
    table.sort(subdirs)

    local query = st.filter_query and vim.trim(st.filter_query):lower() or ""

    st.dir_entries = { { type = "up" } }
    for _, s in ipairs(subdirs) do
      if query == "" or s:lower():find(query, 1, true) then
        local full_p = (curr_dir == "/" and "/" or (curr_dir .. "/")) .. s
        full_p = full_p:gsub("^/+", "/")
        st.dir_entries[#st.dir_entries + 1] = { type = "dir", name = s, full = full_p }
      end
    end
    st.dir_sel = math.max(1, math.min(#st.dir_entries, st.dir_sel or 1))

    local count_label = query ~= "" and i18n.t("filtered_count", #st.dir_entries - 1, #subdirs) or tostring(#subdirs)
    if st.dir_picker_relocate then
      divider(ICON_RELOCATE .. " " .. i18n.t("section_relocate", st.dir_picker_relocate.name, count_label))
    else
      divider(ICON_FOLDER_INSPECT .. " " .. i18n.t("section_browse", count_label))
    end

    for idx, item in ipairs(st.dir_entries) do
      local is_sel = (idx == st.dir_sel)
      local is_already = (item.type == "dir") and P.is_project(item.full)
      local content = (item.type == "up") and (ICON_UP_DIR .. " " .. i18n.t("up_dir")) or (" " .. item.name)
      local badge = is_already and ("  " .. ICON_SUCCESS .. " " .. i18n.t("already_registered_badge")) or ""

      local prefix = is_sel and " ❯ " or "   "
      local line = prefix .. content .. badge

      local hl = "ProjectsName"
      if item.type == "up" then
        hl = is_sel and "ProjectsTitleSpecial" or "ProjectsMeta"
      elseif is_already then
        hl = is_sel and "ProjectsHeaderPublic" or "ProjectsGitBranch"
      else
        hl = is_sel and "ProjectsProjectTitle" or "ProjectsName"
      end

      if is_already then
        local b_start = #prefix + #content
        push(line, {
          { 0, b_start, hl },
          { b_start, #line, "ProjectsHeaderPublic" },
        })
      else
        push(line, { { 0, #line, hl } })
      end
    end

    local win = st.list.win
    local h = vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_height(win) or 20
    for _ = 1, h do lines[#lines + 1] = "" end

    vim.bo[st.list.buf].modifiable = true
    vim.api.nvim_buf_set_lines(st.list.buf, 0, -1, false, lines)
    vim.bo[st.list.buf].modifiable = false

    vim.api.nvim_buf_clear_namespace(st.list.buf, ns, 0, -1)
    for _, hl in ipairs(hls) do
      pcall(vim.api.nvim_buf_set_extmark, st.list.buf, ns, hl[1], hl[2], {
        end_col = hl[3],
        hl_group = hl[4],
        hl_mode = "combine",
        priority = hl.priority or 200,
      })
    end

    local sel_lnum = (st.dir_sel or 1) + 3
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_set_cursor, win, { sel_lnum, 0 })
      local vista = vim.api.nvim_win_call(win, vim.fn.winsaveview)
      local topline = vista.topline or 1

      local new_top = topline
      if sel_lnum < topline + 1 then
        new_top = math.max(1, sel_lnum - 1)
      elseif sel_lnum > topline + h - 2 then
        new_top = sel_lnum - h + 2
      end

      if new_top ~= topline then
        vim.api.nvim_win_call(win, function()
          vim.fn.winrestview({ topline = new_top, lnum = sel_lnum, col = 0 })
        end)
      end
    end
    render_scrollbar(st)

    pcall(vim.api.nvim_win_set_config, st.input.win, {
      title = st.dir_picker_relocate
          and (" " .. ICON_RELOCATE .. " " .. i18n.t("title_reconnect", st.dir_picker_relocate.name, curr_dir))
        or (" " .. ICON_FOLDER_INSPECT .. " " .. i18n.t("title_browse", curr_dir)),
      title_pos = "left",
    })

    local footer_chunks = {
      { " " .. i18n.t("btn_enter_dir") .. " ", "ProjectsLazyBtnLabel" },
      { " Enter ", "ProjectsLazyBtnKey" },
      { "  ", "NormalFloat" },
      { " " .. i18n.t("btn_back") .. " ", "ProjectsLazyBtnLabel" },
      { " Backspace ", "ProjectsLazyBtnKey" },
      { "  ", "NormalFloat" },
      st.dir_picker_relocate and { " " .. i18n.t("btn_reconnect_here") .. " ", "ProjectsLazyBtnLabel" } or { " " .. i18n.t("btn_add_project") .. " ", "ProjectsLazyBtnLabel" },
      { " a ", "ProjectsLazyBtnKey" },
      { "  ", "NormalFloat" },
      { " " .. i18n.t("btn_exit") .. " ", "ProjectsLazyBtnLabel" },
      { " Esc ", "ProjectsLazyBtnKey" },
    }

    pcall(vim.api.nvim_win_set_config, st.list.win, {
      footer = footer_chunks,
      footer_pos = "center",
    })
    render_preview(st)
    return
  end

  local is_searching = st.filter_query and vim.trim(st.filter_query) ~= ""

  local recents_n, mine_n, others_n = 0, 0, 0
  for _, it in ipairs(st.items) do
    if not is_searching and it.recent_rank then
      recents_n = recents_n + 1
    elseif it.mine then
      mine_n = mine_n + 1
    else
      others_n = others_n + 1
    end
  end

  local function item_group(it)
    if not it then return nil end
    if not is_searching and it.recent_rank then
      return 1
    end
    return it.mine and 2 or 3
  end

  local i = 1
  while i <= #st.items do
    local group = item_group(st.items[i])
    local prev_group = item_group(st.items[i - 1])

    if i == 1 or prev_group ~= group then
      local is_first_div = (#lines == 0)
      if group == 1 and recents_n > 0 then
        divider(ICON_HISTORY .. " " .. i18n.t("section_recent", recents_n), is_first_div)
      elseif group == 2 and mine_n > 0 then
        divider(i18n.t("section_mine", mine_n), is_first_div)
      elseif group == 3 and others_n > 0 then
        divider(i18n.t("section_others", others_n), is_first_div)
      end
    end

    local built, placed = {}, 0
    for c = 0, cols - 1 do
      local idx = i + c
      if st.items[idx] and item_group(st.items[idx]) == group then
        built[c + 1] = card(st.items[idx], cw, idx == st.sel, st)
        pos[idx] = #lines + 1
        placed = placed + 1
      end
    end
    for r = 1, CARD_ROWS do
      local chunks = {}
      if pad_left ~= "" then
        chunks[#chunks + 1] = { pad_left }
      end
      for c = 1, cols do
        if built[c] then
          if c > 1 and col_gap ~= "" then chunks[#chunks + 1] = { col_gap } end
          vim.list_extend(chunks, built[c][r])
        end
      end
      local text, lhls = join(chunks)
      push(text, lhls)
      rows[#lines] = i
    end
    i = i + math.max(1, placed)
  end

  if #st.items == 0 then
    lines, hls = {}, {}
    local h = vim.api.nvim_win_is_valid(st.list.win) and vim.api.nvim_win_get_height(st.list.win) or 20
    local top_pad = math.max(1, math.floor((h - 6) / 2))

    for _ = 1, top_pad do push("") end

    local q = st.filter_query or ""
    local words = vim.split(vim.trim(q), "%s+")
    local tags_chunks = {}
    for _, w_str in ipairs(words) do
      if w_str ~= "" then
        local info = LANG_TOKENS[w_str:lower()] or VISIBILITY_TOKENS[w_str:lower()] or get_author_token(w_str, st)
        local hl = info and info.hl or "ProjectsName"
        local label = info and info.name or w_str:upper()
        if #tags_chunks > 0 then tags_chunks[#tags_chunks + 1] = { "  " } end
        tags_chunks[#tags_chunks + 1] = { label, hl }
      end
    end

    local title_text = i18n.t("empty_title")
    local pad_title = string.rep(" ", math.max(0, math.floor((w - dw(title_text)) / 2)))
    push(pad_title .. title_text, { { #pad_title, #pad_title + #title_text, "ProjectsNameSel" } })

    if #tags_chunks > 0 then
      push("")
      local sub_text = i18n.t("empty_subtitle")
      local pad_sub = string.rep(" ", math.max(0, math.floor((w - dw(sub_text)) / 2)))
      push(pad_sub .. sub_text, { { #pad_sub, #pad_sub + #sub_text, "ProjectsDesc" } })

      local t_width = chunks_width(tags_chunks)
      local pad_tags = string.rep(" ", math.max(0, math.floor((w - t_width) / 2)))
      local full_chunks = { { pad_tags } }
      vim.list_extend(full_chunks, tags_chunks)
      local line_t, line_hls = join(full_chunks)
      push("")
      push(line_t, line_hls)
    end
  end

  local win = st.list.win
  local h = vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_height(win) or 20

  for _ = 1, h do
    lines[#lines + 1] = ""
  end

  local saved_list_view = nil
  if vim.api.nvim_win_is_valid(win) then
    saved_list_view = vim.api.nvim_win_call(win, vim.fn.winsaveview)
  end

  vim.bo[st.list.buf].modifiable = true
  vim.api.nvim_buf_set_lines(st.list.buf, 0, -1, false, lines)
  vim.bo[st.list.buf].modifiable = false

  if saved_list_view and vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_win_call, win, function()
      -- Stessa ragione: un cursore fuori dalla finestra ripristinata
      -- trascinerebbe indietro lo scorrimento. Lo si riporta nel intervallo
      -- visibile prima di ripristinare, senza spostare la vista.
      local top = saved_list_view.topline or 1
      local last = vim.api.nvim_buf_line_count(st.list.buf)
      local bottom = math.min(last, top + h - 1)
      saved_list_view.lnum = math.max(top, math.min(bottom, saved_list_view.lnum or top))
      vim.fn.winrestview(saved_list_view)
    end)
  end

  vim.api.nvim_buf_clear_namespace(st.list.buf, ns, 0, -1)
  for _, hl in ipairs(hls) do
    pcall(vim.api.nvim_buf_set_extmark, st.list.buf, ns, hl[1], hl[2], {
      end_col = hl[3],
      hl_group = hl[4],
      hl_mode = "combine",
      priority = hl.priority or 200,
    })
  end

  st.pos, st.rows = pos, rows
  if is_marquee_tick then return end
  ensure_visible(st)

  local ext_cnt = 0
  for _, it in ipairs(st.all) do
    if it.is_external then
      ext_cnt = ext_cnt + 1
    end
  end
  local local_cnt = #st.all - ext_cnt

  local title_text = ""
  if ext_cnt > 0 then
    title_text = (" \u{276f}" .. i18n.t("list_title_counts")):format(#st.all, local_cnt, ext_cnt)
  else
    title_text = (" \u{276f}" .. i18n.t("list_title")):format(#st.items, #st.all)
  end

  if st.filter_query and st.filter_query ~= "" then
    local words = vim.split(vim.trim(st.filter_query), "%s+")
    local formatted_words = {}
    for _, w_str in ipairs(words) do
      if w_str ~= "" then
        local info = LANG_TOKENS[w_str:lower()] or VISIBILITY_TOKENS[w_str:lower()] or get_author_token(w_str, st)
        formatted_words[#formatted_words + 1] = info and info.name or w_str:upper()
      end
    end
    local query_formatted = table.concat(formatted_words, " ")
    if ext_cnt > 0 then
      title_text = (" \u{276f}" .. i18n.t("list_title_filtered_counts")):format(query_formatted, #st.items, #st.all, local_cnt, ext_cnt)
    else
      title_text = (" \u{276f}" .. i18n.t("list_title_filtered")):format(query_formatted, #st.items, #st.all)
    end
  end

  pcall(vim.api.nvim_win_set_config, st.input.win, {
    title = title_text,
    title_pos = "left",
  })

  local footer_chunks = {}
  if #st.items == 0 then
    footer_chunks = {
      { " " .. i18n.t("btn_add") .. " ", "ProjectsLazyBtnLabel" },
      { " a ", "ProjectsLazyBtnKey" },
    }
  else
    footer_chunks = {
      { " " .. i18n.t("btn_add") .. " ", "ProjectsLazyBtnLabel" },
      { " a ", "ProjectsLazyBtnKey" },
      { "  ", "NormalFloat" },
      { " " .. i18n.t("btn_remove") .. " ", "ProjectsLazyBtnLabel" },
      { " d ", "ProjectsLazyBtnKey" },
      { "  ", "NormalFloat" },
      { " " .. i18n.t("btn_open") .. " ", "ProjectsLazyBtnLabel" },
      { " Enter ", "ProjectsLazyBtnKey" },
    }
  end

  pcall(vim.api.nvim_win_set_config, st.list.win, {
    footer = footer_chunks,
    footer_pos = "center",
  })
end

refresh = function(st)
  render_list(st)
  render_preview(st)
end

move = function(st, delta)
  if #st.items == 0 then return end
  local old_sel = st.sel
  st.sel = math.min(#st.items, math.max(1, st.sel + delta))
  if st.sel ~= old_sel then
    local new_p = st.items[st.sel]
    if new_p then
      local html_file = P.get_html_preview_file(new_p.path)
      if not html_file then
        st.web_preview_mode = false
      end
    end
    clear_kitty_graphics()
    st.commit_limit = 100
    if new_p then
      -- Niente chiamata sincrona a git qui: get_commit_details usa io.popen e
      -- blocca la UI 30-100ms ad ogni spostamento. Lo stato git e' gia' stato
      -- caricato in background da load_git, quindi si riusa quello.
      local g = new_p.git
      if g and (g.none or (tonumber(g.commits) or 0) == 0) then
        st.show_all_commits = false
      end
    end
  end
  refresh(st)
end

filter = function(st, immediate)
  clear_kitty_graphics()
  local q = vim.api.nvim_buf_get_lines(st.input.buf, 0, 1, false)[1] or ""

  local changed = false
  local new_line = q:gsub("(%S+)", function(word)
    local l_word = word:lower()
    if VISIBILITY_TOKENS[l_word] and word ~= word:upper() then
      changed = true
      return word:upper()
    end
    return word
  end)

  if changed then
    local cur = vim.api.nvim_win_get_cursor(st.input.win)
    vim.api.nvim_buf_set_lines(st.input.buf, 0, 1, false, { new_line })
    pcall(vim.api.nvim_win_set_cursor, st.input.win, cur)
    q = new_line
  end

  st.filter_query = q
  -- Aggiorna istantaneamente highlights e ghost text (0ms, nessun blocco tasti)
  highlight_input_languages(st)

  local function apply_filter()
    local trimmed = vim.trim(st.filter_query or "")
    if trimmed == "" then
      st.items = st.all
    else
      local words = vim.split(trimmed, "%s+")
      local lang_specs = {}
      local vis_specs = {}
      local author_specs = {}
      local text_words = {}

      for _, w in ipairs(words) do
        local lang_info = LANG_TOKENS[w:lower()]
        local vis_info = VISIBILITY_TOKENS[w:lower()]
        local author_info = get_author_token(w, st)
        if lang_info then
          lang_specs[#lang_specs + 1] = lang_info.name:lower()
        elseif vis_info then
          vis_specs[#vis_specs + 1] = vis_info.type
        elseif author_info then
          author_specs[#author_specs + 1] = author_info.clean
        else
          text_words[#text_words + 1] = w:lower()
        end
      end

      local text_q = table.concat(text_words, " ")

      local function project_has_language(it, req_lang_name)
        if not it then return false end
        local req_lower = req_lang_name:lower()

        -- 1. Check it.languages list (exact language name match)
        if it.languages and #it.languages > 0 then
          for _, l in ipairs(it.languages) do
            if l.name and l.name:lower() == req_lower then
              return true
            end
          end
        end

        -- 2. Check it.type (exact type match and platform type inferences)
        if it.type then
          local t_lower = it.type:lower()
          if t_lower == req_lower then
            return true
          end
          if t_lower == "node" and (req_lower == "javascript" or req_lower == "typescript") then
            return true
          elseif t_lower == "web" and (req_lower == "html" or req_lower == "css" or req_lower == "javascript") then
            return true
          elseif t_lower == "android" and (req_lower == "kotlin" or req_lower == "java") then
            return true
          elseif t_lower == "ios" and req_lower == "swift" then
            return true
          end
        end

        -- 3. Check whole word match in it.search with frontier pattern
        if it.search then
          local s_lower = it.search:lower()
          local pattern = "%f[%a]" .. vim.pesc(req_lower) .. "%f[%A]"
          if s_lower:match(pattern) then
            return true
          end
        end

        return false
      end

      local function project_has_author(it, req_author_clean)
        if not it then return false end

        -- Raccogli tutti gli alias dell'utente se appartiene a me.owners
        local target_aliases = { [req_author_clean] = true }
        local me_owners = (config.options and config.options.me and config.options.me.owners) or {}
        local is_me_owner = false
        for _, o in ipairs(me_owners) do
          local oc = o:lower():gsub("[%s%-_%./\\]", "")
          if oc == req_author_clean then
            is_me_owner = true
            break
          end
        end

        if is_me_owner then
          for _, o in ipairs(me_owners) do
            local oc = o:lower():gsub("[%s%-_%./\\]", "")
            target_aliases[oc] = true
          end
        end

        -- 1. Controllo Partecipanti / Autori dei Commit (in memoria O(1))
        if it.authors then
          for a_clean, _ in pairs(it.authors) do
            for alias, _ in pairs(target_aliases) do
              if a_clean == alias or a_clean:find(alias, 1, true) or alias:find(a_clean, 1, true) then
                return true
              end
            end
          end
        end

        -- 2. Controllo Proprietario del Repository GitHub (gh_meta.owner)
        local gh_meta = P.get_github_meta(it.path)
        if gh_meta and gh_meta.owner then
          local o_clean = gh_meta.owner:lower():gsub("[%s%-_%./\\]", "")
          for alias, _ in pairs(target_aliases) do
            if o_clean == alias or o_clean:find(alias, 1, true) or alias:find(o_clean, 1, true) then
              return true
            end
          end
        end

        -- 3. Controllo Repository Parent (se fork di un altro utente)
        if gh_meta and gh_meta.parent then
          local p_clean = gh_meta.parent:lower():gsub("[%s%-_%./\\]", "")
          for alias, _ in pairs(target_aliases) do
            if p_clean:find(alias, 1, true) then
              return true
            end
          end
        end

        -- 4. Controllo Repository Personali / Locali con Git
        if is_me_owner and (it.git and not it.git.none) then
          if not gh_meta or not gh_meta.owner then
            return true
          end
        end

        return false
      end

      local scored_matches = {}
      for _, it in ipairs(st.all) do
        local matches_filters = true
        if #lang_specs > 0 then
          for _, req_lang in ipairs(lang_specs) do
            if not project_has_language(it, req_lang) then
              matches_filters = false
              break
            end
          end
        end

        if matches_filters and #author_specs > 0 then
          for _, req_auth in ipairs(author_specs) do
            if not project_has_author(it, req_auth) then
              matches_filters = false
              break
            end
          end
        end

        if matches_filters and #vis_specs > 0 then
          local gh_meta = P.get_github_meta(it.path)
          for _, req_vis in ipairs(vis_specs) do
            local is_priv = (gh_meta and gh_meta.is_private == true) or (it.is_private == true) or (it.visibility == "PRIVATE")
            local is_pub = (gh_meta and gh_meta.is_private == false) or (it.is_private == false) or (it.visibility == "PUBLIC")
            local is_loc = (not gh_meta) or (it.git and it.git.none == true)

            if req_vis == "public" and not is_pub then matches_filters = false end
            if req_vis == "private" and not is_priv then matches_filters = false end
            if req_vis == "local" and not is_loc then matches_filters = false end
          end
        end

        if matches_filters then
          if #text_words > 0 then
            local name_lower = tostring(it.name or ""):lower()
            local dir_lower = tostring(it.dir or ""):lower()
            local search_lower = tostring(it.search or ""):lower()
            local score = 0

            if name_lower == text_q then
              score = 2000
            elseif name_lower:sub(1, #text_q) == text_q then
              score = 1500
            elseif name_lower:find(text_q, 1, true) then
              score = 1000
            elseif dir_lower:find(text_q, 1, true) then
              score = 500
            elseif search_lower:find(text_q, 1, true) then
              score = 100
            else
              local ok_name, f_name = pcall(vim.fn.matchfuzzy, { it.name }, text_q)
              local ok_search, f_search = pcall(vim.fn.matchfuzzy, { it.search }, text_q)
              if ok_name and f_name and #f_name > 0 then
                score = 80
              elseif ok_search and f_search and #f_search > 0 then
                score = 20
              end
            end

            if score > 0 then
              if it.mine then score = score + 50 end
              scored_matches[#scored_matches + 1] = { item = it, score = score }
            end
          else
            local score = it.mine and 100 or 10
            scored_matches[#scored_matches + 1] = { item = it, score = score }
          end
        end
      end

      table.sort(scored_matches, function(a, b)
        return a.score > b.score
      end)

      local res = {}
      for _, sm in ipairs(scored_matches) do
        res[#res + 1] = sm.item
      end
      st.items = res
    end

    st.sel = 1
    refresh(st)
  end

  if immediate then
    if st.filter_debounce_timer then
      pcall(function() st.filter_debounce_timer:stop(); st.filter_debounce_timer:close() end)
      st.filter_debounce_timer = nil
    end
    apply_filter()
    return
  end

  if st.filter_debounce_timer then
    pcall(function() st.filter_debounce_timer:stop(); st.filter_debounce_timer:close() end)
    st.filter_debounce_timer = nil
  end

  local d_timer = (vim.uv or vim.loop).new_timer()
  st.filter_debounce_timer = d_timer
  d_timer:start(100, 0, vim.schedule_wrap(function()
    if not closed then
      apply_filter()
    end
    pcall(function() d_timer:stop(); d_timer:close() end)
    if st.filter_debounce_timer == d_timer then st.filter_debounce_timer = nil end
  end))
end

reapply = function(st)
  local corrente = st.items[st.sel]
  P.sort(st.all)
  filter(st)
  if corrente then
    for i, it in ipairs(st.items) do
      if it.path == corrente.path then
        st.sel = i
        break
      end
    end
  end
  refresh(st)
end

card_at_mouse = function(st)
  local m = vim.fn.getmousepos()
  if m.winid ~= st.list.win or m.line <= 0 then return nil end
  if not (st.pos and st.items) then return nil end

  for idx, lnum in pairs(st.pos) do
    if m.line >= lnum and m.line <= lnum + CARD_ROWS - 1 then
      local is_right = (st.cols == 2 and m.wincol > st.card_width + 2)
      local final_idx = is_right and (idx + 1) or idx
      if st.items[final_idx] then
        return final_idx
      end
    end
  end
  return nil
end

function M.open()
  set_hl()
  local all = P.list()
  -- Nessun progetto: invece di rifiutarsi di aprire (lasciando l'utente senza
  -- alcun modo di procedere, visto che il tasto per aggiungerli vive DENTRO la
  -- dashboard) si apre in modalita' benvenuto, che spiega e offre le due strade.
  local welcome = (#all == 0)

  local TW = math.floor(vim.o.columns * M.config.width)
  local TH = math.floor((vim.o.lines - 2) * M.config.height)
  local SC = math.floor((vim.o.columns - TW) / 2)
  local SR = math.floor((vim.o.lines - TH) / 2)
  local LWf = math.floor(TW * M.config.left_ratio)
  local LW, RW = LWf - 2, TW - LWf - 2

  local st = { all = all, items = all, sel = 1, inspector_mode = true, welcome_mode = welcome }

  local function mkbuf(scratch)
    local b = vim.api.nvim_create_buf(false, true)
    vim.bo[b].bufhidden = scratch and "hide" or "wipe"
    if scratch then vim.bo[b].modifiable = false end
    return b
  end

  local backdrop_buf = mkbuf(true)
  local backdrop_win = vim.api.nvim_open_win(backdrop_buf, false, {
    relative = "editor",
    row = 0,
    col = 0,
    width = vim.o.columns,
    height = vim.o.lines,
    style = "minimal",
    focusable = false,
    zindex = 50,
  })
  vim.wo[backdrop_win].winhighlight = "Normal:NormalFloat,FloatBorder:NormalFloat"
  vim.wo[backdrop_win].winblend = 20

  local function mkwin(buf, opts)
    local w = vim.api.nvim_open_win(buf, false, vim.tbl_extend("force", {
      relative = "editor",
      style = "minimal",
      border = "rounded",
      zindex = 60,
    }, opts))
    vim.wo[w].winhighlight = "Normal:NormalFloat,FloatBorder:ProjectsBorder"
    vim.wo[w].spell = false
    return w
  end

  st.input = { buf = mkbuf(false) }
  vim.b[st.input.buf].completion = false
  st.list = { buf = mkbuf(true) }
  st.preview = { buf = mkbuf(true) }

  st.input.win = mkwin(st.input.buf, { row = SR + 1, col = SC + 1, width = LW, height = 1 })
  st.list.win = mkwin(st.list.buf, { row = SR + 4, col = SC + 1, width = LW, height = math.max(5, TH - 5), focusable = true })
  st.preview.win = mkwin(st.preview.buf, {
    row = SR + 1,
    col = SC + LWf + 1,
    width = RW,
    height = math.max(5, TH - 2),
    focusable = true,
    title = " " .. i18n.t("title_preview") .. " ",
    title_pos = "right",
  })
  vim.wo[st.preview.win].conceallevel = 3
  vim.wo[st.preview.win].concealcursor = "nvic"
  vim.wo[st.preview.win].wrap = true
  vim.wo[st.preview.win].linebreak = true
  vim.wo[st.list.win].scrolloff = 3
  vim.wo[st.input.win].spell = false

  -- Finestra overlay scrollbar dedicata per la lista progetti
  st.list.sb_buf = mkbuf(true)
  st.list.sb_win = vim.api.nvim_open_win(st.list.sb_buf, false, {
    relative = "win",
    win = st.list.win,
    row = 0,
    col = LW - 1,
    width = 1,
    height = math.max(5, TH - 5),
    style = "minimal",
    focusable = false,
    zindex = 70,
  })
  vim.wo[st.list.sb_win].winhighlight = "Normal:NormalFloat,FloatBorder:ProjectsBorder"

  -- Finestra overlay scrollbar dedicata per l'anteprima README
  st.preview.sb_buf = mkbuf(true)
  if not st.dir_picker_mode then
    st.preview.sb_win = vim.api.nvim_open_win(st.preview.sb_buf, false, {
      relative = "win",
      win = st.preview.win,
      row = 0,
      col = RW - 1,
      width = 1,
      height = math.max(5, TH - 2),
      style = "minimal",
      focusable = false,
      zindex = 70,
    })
    vim.wo[st.preview.sb_win].winhighlight = "Normal:NormalFloat,FloatBorder:ProjectsBorder"
  end

  local function layout_windows()
    local n_TW = math.floor(vim.o.columns * M.config.width)
    local n_TH = math.floor((vim.o.lines - 2) * M.config.height)
    local n_SC = math.floor((vim.o.columns - n_TW) / 2)
    local n_SR = math.floor((vim.o.lines - n_TH) / 2)
    local n_LWf = math.floor(n_TW * M.config.left_ratio)
    local n_LW, n_RW = n_LWf - 2, n_TW - n_LWf - 2

    st.list.width = n_LW

    if vim.api.nvim_win_is_valid(backdrop_win) then
      pcall(vim.api.nvim_win_set_config, backdrop_win, {
        relative = "editor",
        row = 0,
        col = 0,
        width = vim.o.columns,
        height = vim.o.lines,
      })
    end

    if vim.api.nvim_win_is_valid(st.input.win) then
      pcall(vim.api.nvim_win_set_config, st.input.win, {
        relative = "editor",
        row = n_SR + 1,
        col = n_SC + 1,
        width = n_LW,
        height = 1,
      })
    end

    if vim.api.nvim_win_is_valid(st.list.win) then
      pcall(vim.api.nvim_win_set_config, st.list.win, {
        relative = "editor",
        row = n_SR + 4,
        col = n_SC + 1,
        width = n_LW,
        height = math.max(5, n_TH - 5),
      })
    end

    if vim.api.nvim_win_is_valid(st.list.sb_win) then
      pcall(vim.api.nvim_win_set_config, st.list.sb_win, {
        relative = "win",
        win = st.list.win,
        row = 0,
        col = n_LW - 1,
        width = 1,
        height = math.max(5, n_TH - 5),
      })
    end

    if vim.api.nvim_win_is_valid(st.preview.win) then
      pcall(vim.api.nvim_win_set_config, st.preview.win, {
        relative = "editor",
        row = n_SR + 1,
        col = n_SC + n_LWf + 1,
        width = n_RW,
        height = math.max(5, n_TH - 2),
      })
    end

    if vim.api.nvim_win_is_valid(st.preview.sb_win) then
      if st.dir_picker_mode then
        pcall(vim.api.nvim_win_close, st.preview.sb_win, true)
      else
        pcall(vim.api.nvim_win_set_config, st.preview.sb_win, {
          relative = "win",
          win = st.preview.win,
          row = 0,
          col = n_RW - 1,
          width = 1,
          height = math.max(5, n_TH - 2),
        })
      end
    end
  end

  layout_windows()
  refresh(st)
  vim.api.nvim_set_current_win(st.list.win)
  vim.cmd("stopinsert")

  local closed = false
  local function close()
    if closed then return end
    closed = true
    if st.marquee_timer then
      pcall(function()
        st.marquee_timer:stop()
        st.marquee_timer:close()
      end)
      st.marquee_timer = nil
    end
    clear_kitty_graphics()
    if vim.api.nvim_win_is_valid(backdrop_win) then
      pcall(vim.api.nvim_win_close, backdrop_win, true)
    end
    if st.list and st.list.sb_win and vim.api.nvim_win_is_valid(st.list.sb_win) then
      pcall(vim.api.nvim_win_close, st.list.sb_win, true)
    end
    if st.preview and st.preview.sb_win and vim.api.nvim_win_is_valid(st.preview.sb_win) then
      pcall(vim.api.nvim_win_close, st.preview.sb_win, true)
    end
    for _, k in ipairs({ "input", "list", "preview" }) do
      if st[k] and st[k].win and vim.api.nvim_win_is_valid(st[k].win) then
        pcall(vim.api.nvim_win_close, st[k].win, true)
      end
    end
  end
  st.close = close

  local function open_sel(idx)
    local p = st.items[idx or st.sel]
    sound.play("select")
    vim.cmd("stopinsert")
    close()
    if p then
      P.add_recent(p.path)
      P.open(p.path)
    end
  end

  local function map(bufs, mode, keys, fn)
    bufs = type(bufs) == "table" and bufs or { bufs }
    for _, b in ipairs(bufs) do
      for _, k in ipairs(keys) do
        vim.keymap.set(mode, k, fn, { buffer = b, nowait = true, silent = true })
      end
    end
  end

  local all_bufs = { st.input.buf, st.list.buf, st.preview.buf }

  local function move_down()
    if st.dir_picker_mode then
      st.dir_sel = math.min(#(st.dir_entries or {}), (st.dir_sel or 1) + 1)
      refresh(st)
    else
      move(st, st.cols)
    end
  end

  local function move_up()
    if st.dir_picker_mode then
      st.dir_sel = math.max(1, (st.dir_sel or 1) - 1)
      refresh(st)
    else
      move(st, -st.cols)
    end
  end

  local function clear_dir_search()
    st.filter_query = ""
    if st.input and vim.api.nvim_buf_is_valid(st.input.buf) then
      vim.api.nvim_buf_set_lines(st.input.buf, 0, 1, false, { "" })
    end
  end

  local function move_right()
    if st.dir_picker_mode then
      local item = st.dir_entries and st.dir_entries[st.dir_sel or 1]
      if item then
        if item.type == "up" then
          local parent = vim.fn.fnamemodify(st.dir_curr_dir or vim.fn.expand("~"), ":h")
          if parent and parent ~= st.dir_curr_dir then
            st.dir_curr_dir = parent
            st.dir_sel = 1
            clear_dir_search()
            refresh(st)
          end
        elseif item.type == "dir" then
          st.dir_curr_dir = item.full
          st.dir_sel = 1
          clear_dir_search()
          refresh(st)
        end
      end
    else
      move(st, 1)
    end
  end

  local function move_left()
    if st.dir_picker_mode then
      local parent = vim.fn.fnamemodify(st.dir_curr_dir or vim.fn.expand("~"), ":h")
      if parent and parent ~= st.dir_curr_dir then
        st.dir_curr_dir = parent
        st.dir_sel = 1
        clear_dir_search()
        refresh(st)
      end
    else
      move(st, -1)
    end
  end

  -- h/j/k/l in modalita' inserimento solo fuori dalla barra di ricerca:
  -- dentro st.input.buf devono restare lettere digitabili, altrimenti
  -- scrivere "h" (o j/k/l) nella ricerca spostava la selezione invece
  -- di inserire il carattere.
  local nav_bufs = { st.list.buf, st.preview.buf }

  map(all_bufs, { "i", "n" }, { "<Down>", "<C-j>" }, move_down)
  map(nav_bufs, "i", { "j" }, move_down)
  map(all_bufs, { "i", "n" }, { "<Up>", "<C-k>" }, move_up)
  map(nav_bufs, "i", { "k" }, move_up)
  map(nav_bufs, { "i", "n" }, { "<Right>", "l" }, move_right)
  map(nav_bufs, { "i", "n" }, { "<Left>", "h" }, move_left)
  local function handle_tab_input()
    if st.ghost_suggestion and vim.api.nvim_win_is_valid(st.input.win) then
      local sug = st.ghost_suggestion
      local line = vim.api.nvim_buf_get_lines(st.input.buf, 0, 1, false)[1] or ""
      local ext_col = sug.col or #line
      local prefix_len = #sug.prefix
      local before = line:sub(1, math.max(0, ext_col - prefix_len))
      local after = line:sub(ext_col + 1)
      local completed_token = sug.completion .. " "
      local new_line = before .. completed_token .. after
      local new_col = #before + #completed_token

      vim.api.nvim_buf_set_lines(st.input.buf, 0, 1, false, { new_line })
      pcall(vim.api.nvim_win_set_cursor, st.input.win, { 1, new_col })
      st.ghost_suggestion = nil
      filter(st, true)
      return
    end
    move(st, 1)
  end

  map(nav_bufs, { "i", "n" }, { "<Tab>" }, move_right)
  map(nav_bufs, { "i", "n" }, { "<S-Tab>" }, move_left)
  map(st.input.buf, { "i", "n" }, { "<Tab>" }, handle_tab_input)
  map(st.input.buf, { "i", "n" }, { "<S-Tab>" }, move_left)
  map(all_bufs, { "i", "n" }, { "<PageDown>" }, function() move(st, st.cols * 3) end)
  map(all_bufs, { "i", "n" }, { "<PageUp>" }, function() move(st, -st.cols * 3) end)
  map(all_bufs, { "i", "n" }, { "<C-f>" }, function() scroll_preview(st, 10) end)
  map(all_bufs, { "i", "n" }, { "<C-b>" }, function() scroll_preview(st, -10) end)
  map(all_bufs, { "i", "n" }, { "<C-r>" }, function()
    P.load_git(st.all, function() render_list(st) end, true)
  end)

  map(all_bufs, "n", { "s" }, function()
    -- Nella schermata di benvenuto 's' avvia la ricerca automatica: si sceglie
    -- la cartella-contenitore col browser gia' esistente, poi si analizza.
    if st.welcome_mode and not st.dir_picker_mode then
      st.dir_picker_mode = true
      st.dir_picker_scan = true
      st.dir_curr_dir = st.dir_curr_dir or vim.fn.expand("~")
      st.dir_sel = 1
      clear_dir_search()
      vim.cmd("stopinsert")
      vim.api.nvim_set_current_win(st.list.win)
      refresh(st)
      return
    end

    if st.web_preview_mode then
      st.web_preview_mode = false
      clear_kitty_graphics()
      st.view_mode = "inspector"
      refresh(st)
      if vim.api.nvim_win_is_valid(st.list.win) then
        pcall(vim.api.nvim_set_current_win, st.list.win)
      end
      return
    end

    st.web_preview_mode = false
    clear_kitty_graphics()
    local p = st.items[st.sel]
    local has_readme = p and P.readme_path(p.path) ~= nil

    local current = st.view_mode or "inspector"
    if current == "inspector" then
      st.view_mode = has_readme and "readme" or "tree"
    else
      st.view_mode = "inspector"
    end
    st.show_all_commits = false
    refresh(st)
    if vim.api.nvim_win_is_valid(st.list.win) then
      pcall(vim.api.nvim_set_current_win, st.list.win)
    end
  end)

  map(all_bufs, "n", { "c" }, function()
    local p = st.items[st.sel]
    if p then
      local commits = P.get_commit_details(p.path, 1)
      if #commits == 0 then
        st.show_all_commits = false
        notify(i18n.t("notify_no_commits", p.name), nil, "warn", "error")
        return
      end
      st.view_mode = "inspector"
      st.commit_limit = 1000
      st.show_all_commits = not st.show_all_commits
      refresh(st)
    end
  end)

  map(all_bufs, "n", { "w" }, function()
    local p = st.items[st.sel]
    if p then
      local html_file = P.get_html_preview_file(p.path)
      if html_file then
        st.web_preview_mode = not st.web_preview_mode
        if not st.web_preview_mode then
          clear_kitty_graphics()
          st.view_mode = "inspector"
        end
        refresh(st)
      end
    end
  end)

  map(all_bufs, "n", { "W" }, function()
    local p = st.items[st.sel]
    if p then
      local html_file = P.get_html_preview_file(p.path)
      if html_file then
        notify(i18n.t("notify_opening_web_preview", html_file), nil, "open", "open")
        if vim.ui and vim.ui.open then
          pcall(vim.ui.open, html_file)
        else
          pcall(vim.fn.jobstart, { "open", html_file })
        end
      end
    end
  end)

  map(all_bufs, "n", { "g" }, function()
    local p = st.items[st.sel]
    if p then
      local gh_url = P.get_github_url(p.path)
      if gh_url and gh_url ~= "" then
        notify(i18n.t("notify_opening_github", gh_url), nil, "open", "open")
        if vim.ui and vim.ui.open then
          vim.ui.open(gh_url)
        else
          vim.fn.jobstart({ "open", gh_url }, { detach = true })
        end
      else
        notify(i18n.t("notify_no_github"), nil, "warn", "error")
      end
    end
  end)

  map(all_bufs, "n", { "a" }, function()
    if st.dir_picker_mode then
      local sel_entry = st.dir_entries and st.dir_entries[st.dir_sel or 1]
      local target_path = (sel_entry and sel_entry.type == "dir") and sel_entry.full or (st.dir_curr_dir or vim.fn.expand("~"))

      if st.dir_picker_relocate then
        local old_p = st.dir_picker_relocate
        if P.is_project(target_path) then
          notify(
            i18n.t("notify_already_registered_title"),
            i18n.t("notify_already_registered_body", vim.fn.fnamemodify(target_path, ":t")),
            "warn",
            "error"
          )
          return
        else
          P.remove_custom_extra(old_p.path)
          P.remove_recent(old_p.path)

          local ok, code, arg = P.add_custom_extra(target_path)
          if ok then
            P.add_recent(target_path)
            notify(
              i18n.t("notify_reconnected_title"),
              i18n.t("notify_reconnected_body", old_p.name, target_path),
              "connect",
              "connect"
            )
          else
            local fail_title, fail_body = add_extra_result_text(code, arg)
            notify(
              i18n.t("notify_reconnect_failed_title", fail_title),
              i18n.t("notify_reconnect_failed_body", fail_body),
              "error",
              "error"
            )
          end

          st.dir_picker_mode = false
          st.dir_picker_relocate = nil
          st.sel = 1
          st.all = P.list(true)
          filter(st)
          P.load_git(st.all, function() render_list(st) end, true)
          P.load_languages(st.all, function() render_list(st) end, true)
          return
        end
      end

      -- Ricerca automatica: la cartella scelta e' un contenitore, si aggiungono
      -- tutte le sottocartelle riconosciute come progetto.
      if st.dir_picker_scan then
        st.dir_picker_scan = false
        st.dir_picker_mode = false
        local short = vim.fn.fnamemodify(target_path, ":~")
        -- messaggio su una riga sola: senza un plugin di notifiche Neovim
        -- mostrerebbe il prompt "Press ENTER", che ruba il focus e chiude
        -- la dashboard proprio mentre la scansione sta partendo
        notify(i18n.t("scan_running", short), nil, "info", nil)
        -- differito di un tick: cosi' l'avviso viene disegnato PRIMA che la
        -- scansione (sincrona) prenda il controllo del loop
        vim.defer_fn(function()
          if closed or not vim.api.nvim_buf_is_valid(st.input.buf) then return end
          local found = P.detect_projects_in(target_path)
          local added = 0
          for _, dir in ipairs(found) do
            if P.add_custom_extra(dir) then added = added + 1 end
          end
          st.all = P.list(true)
          if st.welcome_mode and #st.all > 0 then st.welcome_mode = false end
          filter(st)
          if added == 0 then
            notify(i18n.t("scan_none", short), nil, "warn", "error")
          else
            local msg = (added == 1) and i18n.t("scan_found_one", short) or i18n.t("scan_found", added, short)
            notify(msg, nil, "success", "success")
          end
          refresh(st)
          P.load_git(st.all, function() render_list(st) end, true)
          P.load_languages(st.all, function() render_list(st) end, true)
        end, 60)
        return
      end

      local ok, code, arg = P.add_custom_extra(target_path)
      local res_title, res_body = add_extra_result_text(code, arg)
      if ok then
        P.add_recent(target_path)
        notify(res_title, res_body, "success", "success")
      else
        if code == "already_registered" then
          notify(res_title, res_body, "warn", "error")
        else
          notify(i18n.t("notify_op_failed_title", res_title), i18n.t("notify_op_failed_body", res_body), "error", "error")
        end
      end

      st.dir_picker_mode = false
      st.all = P.list(true)
      if st.welcome_mode and #st.all > 0 then st.welcome_mode = false end
      filter(st)
      P.load_git(st.all, function() render_list(st) end, true)
      P.load_languages(st.all, function() render_list(st) end, true)
    else
      st.dir_picker_mode = true
      st.dir_curr_dir = st.dir_curr_dir or vim.fn.expand("~")
      st.dir_sel = 1
      clear_dir_search()
      vim.cmd("stopinsert")
      vim.api.nvim_set_current_win(st.list.win)
      refresh(st)
    end
  end)

  map(all_bufs, "n", { "d" }, function()
    local p = st.items[st.sel]
    if p then
      P.remove_recent(p.path)
      P.remove_custom_extra(p.path)
      notify(i18n.t("notify_removed_title"), i18n.t("notify_removed_body", p.name), "delete", "delete")
      st.all = P.list(true)
      filter(st)
      P.load_git(st.all, function() render_list(st) end, true)
      P.load_languages(st.all, function() render_list(st) end, true)
    end
  end)

  -- Riconnessione: riusa lo stesso sfogliatore di cartelle del tasto "a"
  -- (Aggiungi progetto), solo etichettato per il resync invece che per
  -- la creazione di un nuovo progetto.
  local function start_relocate_picker()
    local p = st.items[st.sel]
    if not p then return end

    local parent = vim.fn.fnamemodify(p.path, ":h")
    st.dir_picker_mode = true
    st.dir_picker_relocate = p
    st.dir_curr_dir = (vim.fn.isdirectory(parent) == 1) and parent or vim.fn.expand("~")
    st.dir_sel = 1
    clear_dir_search()
    vim.cmd("stopinsert")
    vim.api.nvim_set_current_win(st.list.win)
    refresh(st)
  end

  map(all_bufs, "n", { "r" }, start_relocate_picker)

  -- Switch lingua interfaccia (it <-> en), a runtime, senza uscire dalla dashboard.
  map(all_bufs, "n", { "L" }, function()
    if st.dir_picker_mode then return end
    local new_lang = (i18n.get_lang() == "it") and "en" or "it"
    config.options.language = new_lang
    if config.save_setting then
      config.save_setting("language", new_lang)
    end
    notify(i18n.t("notify_lang_switched"), nil, "toggle", "toggle")
    M.refresh()
  end)

  local function prompt_note()
    local p = st.items[st.sel]
    if not p then return end
    local current_note = P.get_note(p.path)

    st.inspector_mode = true
    refresh(st)

    vim.ui.input({
      prompt = i18n.t("prompt_note", p.name),
      default = current_note,
    }, function(input)
      if input ~= nil and vim.trim(input) ~= "" then
        P.save_note(p.path, vim.trim(input))
        notify(i18n.t("notify_note_saved", p.name), nil, "checkpoint", "checkpoint")
      elseif input == "" then
        P.save_note(p.path, "")
        notify(i18n.t("notify_note_removed", p.name), nil, "delete", "delete")
      end
      st.inspector_mode = true
      refresh(st)
      if st.list and vim.api.nvim_win_is_valid(st.list.win) then
        pcall(vim.api.nvim_set_current_win, st.list.win)
        vim.cmd("stopinsert")
      end
    end)
  end

  map(all_bufs, "n", { "q", "<Esc>" }, function()
    if st.dir_picker_mode then
      st.dir_picker_mode = false
      st.dir_picker_relocate = nil
      refresh(st)
    else
      close()
    end
  end)

  map(all_bufs, "n", { "n", "e" }, prompt_note)

  -- `b` come la campanella che compare accanto al titolo della cronologia.
  -- Serve a scavalcare l'euristica sul numero di autori nei due casi in cui
  -- sbaglia: il progettino a tre mani che non ti interessa, e il repository
  -- affollato a cui invece tieni.
  map(all_bufs, "n", { "b" }, function()
    if st.welcome_mode or st.dir_picker_mode then return end
    local p_sel = st.items[st.sel]
    if not p_sel or p_sel.is_missing or not (p_sel.git and not p_sel.git.none) then return end

    local on = P.toggle_watch(p_sel.path, P.author_count(p_sel))
    notify(i18n.t(on and "watch_on" or "watch_off", p_sel.name), nil,
      on and "toggle" or "warn", on and "toggle_on" or "toggle_off")
    render_list(st)
    if (st.view_mode or "inspector") == "inspector" then render_preview(st) end
  end)

  map(all_bufs, "n", { "/", "f", "i" }, function()
    -- nel benvenuto non c'e' nulla da cercare: la ricerca resta disabilitata
    if st.welcome_mode and not st.dir_picker_mode then return end
    vim.api.nvim_set_current_win(st.input.win)
    local line = vim.api.nvim_buf_get_lines(st.input.buf, 0, 1, false)[1] or ""
    vim.api.nvim_win_set_cursor(st.input.win, { 1, #line })
    vim.cmd("startinsert!")
  end)

  -- Cancellazione istantanea della parola del linguaggio premendo Backspace
  vim.keymap.set({ "i", "n" }, "<BS>", function()
    local line = vim.api.nvim_buf_get_lines(st.input.buf, 0, 1, false)[1] or ""
    local cur = vim.api.nvim_win_get_cursor(st.input.win)
    local col = cur[2]
    if col > 0 then
      local prefix = line:sub(1, col)
      local tag = prefix:match("(%S+%s*)$")
      if tag then
        local clean = tag:gsub("%s", "")
        if LANG_TOKENS[clean:lower()] then
          local new_line = line:sub(1, col - #tag) .. line:sub(col + 1)
          vim.api.nvim_buf_set_lines(st.input.buf, 0, 1, false, { new_line })
          vim.api.nvim_win_set_cursor(st.input.win, { 1, math.max(0, col - #tag) })
          filter(st)
          return
        end
      end
    end
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<BS>", true, false, true), "n", false)
  end, { buffer = st.input.buf, nowait = true, silent = true })

  map(all_bufs, "n", { "j" }, move_down)
  map(all_bufs, "n", { "k" }, move_up)
  map(all_bufs, "n", { "l" }, move_right)
  map(all_bufs, "n", { "h", "<BS>" }, move_left)
  map(all_bufs, "n", { "gg", "<Home>" }, function()
    if #st.items > 0 then
      st.sel = 1
      refresh(st)
    end
  end)
  map(all_bufs, "n", { "G", "<End>" }, function()
    if #st.items > 0 then
      st.sel = #st.items
      refresh(st)
    end
  end)

  map(st.input.buf, { "i", "n" }, { "<Esc>" }, function()
    vim.cmd("stopinsert")
    vim.api.nvim_set_current_win(st.list.win)
  end)
  map({ st.list.buf, st.preview.buf }, "n", { "<Esc>", "<C-c>" }, function()
    vim.cmd("stopinsert")
    if st.dir_picker_mode then
      st.dir_picker_mode = false
      st.dir_picker_relocate = nil
      refresh(st)
      return
    end
    close()
  end)
  map(all_bufs, { "i", "n" }, { "<CR>" }, function()
    if st.dir_picker_mode then
      move_right()
    else
      open_sel()
    end
  end)

  -- Mouse: Click e Trascindamento continuo tenendo premuto il tasto sinistro (<LeftMouse> e <LeftDrag>)
  local is_dragging = false

  local function handle_mouse_click_or_drag()
    local m = vim.fn.getmousepos()
    if m.winid == st.list.win or m.winid == st.list.sb_win then
      local w = st.list.width
      local h = vim.api.nvim_win_get_height(st.list.win)
      if m.winid == st.list.sb_win or m.wincol >= w - 1 or m.wincol <= 0 then
        is_dragging = true
        local max_content = vim.api.nvim_buf_line_count(st.list.buf)
        if max_content <= 1 then max_content = 1 end
        if max_content > h then
          local ratio = math.min(1, math.max(0, (m.winrow - 1) / math.max(1, h - 1)))
          local target_top = math.floor(ratio * (max_content - h)) + 1
          target_top = math.max(1, math.min(max_content - h + 1, target_top))
          vim.api.nvim_win_call(st.list.win, function()
            -- Il cursore va portato con la vista: winrestview dà la precedenza
            -- a lnum, quindi lasciandolo indietro topline verrebbe riportato
            -- su per inquadrarlo, annullando il trascinamento.
            vim.fn.winrestview({ topline = target_top, lnum = target_top, col = 0 })
          end)
          sync_sel_with_scroll(st)
          return
        end
      end

      local idx = card_at_mouse(st)
      if idx and idx ~= st.sel then
        st.sel = idx
        st.web_preview_mode = false
        clear_kitty_graphics()
        refresh(st)
      end
    elseif m.winid == st.preview.win or m.winid == st.preview.sb_win then
      local pw = vim.api.nvim_win_get_width(st.preview.win)
      local ph = vim.api.nvim_win_get_height(st.preview.win)
      local pbuf = vim.api.nvim_win_get_buf(st.preview.win)
      local total_lines = vim.api.nvim_buf_line_count(pbuf)
      if (m.winid == st.preview.sb_win or m.wincol >= pw - 1 or m.wincol <= 0) and total_lines > ph then
        local ratio = math.min(1, math.max(0, (m.winrow - 1) / math.max(1, ph - 1)))
        local target_top = math.floor(ratio * (total_lines - ph)) + 1
        target_top = math.max(1, math.min(total_lines - ph + 1, target_top))
        vim.api.nvim_win_call(st.preview.win, function()
          vim.fn.winrestview({ topline = target_top, lnum = target_top, leftcol = 0 })
        end)
        render_preview_scrollbar(st)

        if target_top + ph >= total_lines - 3 and st.inspector_mode then
          local p_item = st.items[st.sel]
          local total_git_commits = (p_item and p_item.git and tonumber(p_item.git.commits)) or 0
          local cur_lim = st.commit_limit or 100
          if cur_lim < total_git_commits then
            st.commit_limit = cur_lim + 100
            render_inspector(st)
          end
        end
      end
    end
  end

  map(all_bufs, { "i", "n" }, { "<LeftMouse>", "<LeftDrag>" }, handle_mouse_click_or_drag)
  map(all_bufs, { "i", "n" }, { "<LeftRelease>" }, function()
    if is_dragging then
      is_dragging = false
      sync_sel_with_scroll(st)
    end
  end)
  map(all_bufs, { "i", "n" }, { "<2-LeftMouse>" }, function()
    local idx = card_at_mouse(st)
    if idx then open_sel(idx) end
  end)

  -- Rotella mouse: scorrimento rigorosamente verticale
  local function wheel(giu)
    local m = vim.fn.getmousepos()
    if m.winid == st.preview.win or m.winid == st.preview.sb_win then
      scroll_preview(st, giu and 3 or -3)
    elseif m.winid == st.list.win or m.winid == st.list.sb_win or m.winid == st.input.win then
      move(st, giu and st.cols or -st.cols)
    end
  end
  map(all_bufs, { "i", "n" }, { "<ScrollWheelDown>" }, function() wheel(true) end)
  map(all_bufs, { "i", "n" }, { "<ScrollWheelUp>" }, function() wheel(false) end)
  map(all_bufs, { "i", "n" }, { "<ScrollWheelLeft>", "<ScrollWheelRight>" }, function() end)

  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged", "CursorMovedI", "CursorMoved" }, {
    buffer = st.input.buf,
    callback = function() filter(st) end,
  })

  for _, b in ipairs(all_bufs) do
    pcall(vim.api.nvim_buf_create_user_command, b, "q", function()
      close()
    end, { force = true })
    pcall(vim.api.nvim_buf_create_user_command, b, "quit", function()
      close()
    end, { force = true })
    pcall(vim.api.nvim_buf_create_user_command, b, "qa", function()
      close()
    end, { force = true })
  end

  local grp = vim.api.nvim_create_augroup("CustomProjects_" .. st.input.buf, { clear = true })

  for _, b in ipairs(all_bufs) do
    -- Volutamente senza QuitPre. Chiudere le finestre da dentro QuitPre manda
    -- in stallo la sequenza di uscita di Neovim: con la dashboard aperta un
    -- `:qa` non terminava piu' il processo, e l'unico modo di uscire era
    -- chiuderla prima. La chiusura di una finestra cancella comunque il buffer
    -- - sono tutti scratch - quindi BufWipeout arriva lo stesso e `:q` continua
    -- a funzionare.
    vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
      group = grp,
      buffer = b,
      callback = function()
        close()
      end,
    })
  end

  vim.api.nvim_create_autocmd("WinEnter", {
    group = grp,
    callback = function()
      if closed then return true end
      local cur = vim.api.nvim_get_current_win()
      if cur ~= st.input.win and cur ~= st.list.win and cur ~= st.preview.win and cur ~= st.list.sb_win and cur ~= st.preview.sb_win then
        close()
      end
    end,
  })
  vim.api.nvim_create_autocmd("ColorScheme", { buffer = st.input.buf, callback = set_hl })

  local is_refreshing_git = false
  local last_type_time = 0

  -- Le scoperte rientrano una per repository e in ordine sparso, man mano che
  -- i fetch tornano: annunciarle appena arrivano riempiva lo schermo di
  -- notifiche all'apertura. Qui si accumulano e ne parte una sola, che dice
  -- quali progetti si sono mossi. Anche il ridisegno e' uno solo.
  local pending_incoming = {}
  local pending_render = false
  local incoming_notice_gen = 0

  local function flush_incoming_notice()
    local batch = pending_incoming
    local want_render = pending_render
    pending_incoming = {}
    pending_render = false
    if closed then return end

    if #batch == 1 then
      local e = batch[1]
      notify((e.added == 1)
        and i18n.t("notify_incoming_1", e.name, e.upstream)
        or i18n.t("notify_incoming", e.name, e.added, e.upstream), nil, "snap", "snap")
    elseif #batch > 1 then
      local parts, total = {}, 0
      for _, e in ipairs(batch) do
        parts[#parts + 1] = string.format("%s +%d", e.name, e.added)
        total = total + e.added
      end
      notify(i18n.t("notify_incoming_many", #batch, total),
        "   " .. table.concat(parts, "   "), "snap", "snap")
    end

    -- Un solo ridisegno per raffica, e comunque anche quando non c'e' niente
    -- da annunciare: i progetti silenziati mostrano il divider come gli altri.
    if want_render then
      render_list(st)
      if (st.view_mode or "inspector") == "inspector" then
        render_preview(st)
      end
    end
  end

  -- Commit spinti dai collaboratori su upstream. Quali repository siano
  -- scaduti, con che frequenza e chi meriti una notifica lo decide
  -- refresh_incoming_all: qui si raccoglie solo il risultato.
  local function refresh_incoming_now()
    if closed then return end
    -- Stessa precedenza assoluta alla digitazione che vale per il resto del
    -- polling: nessun processo git mentre l'utente sta cercando.
    if ((vim.uv or vim.loop).now() - last_type_time) < 800 then return end

    P.refresh_incoming_all(st.all, function(path, entry, added, notifiable)
      if closed then return end
      pending_render = true

      if notifiable and added > 0 then
        for _, it in ipairs(st.all) do
          if it.path == path then
            pending_incoming[#pending_incoming + 1] = {
              name = it.name,
              added = added,
              upstream = entry.upstream or "origin",
            }
            break
          end
        end
      end

      -- Finestra di raccolta: ogni nuova scoperta la riapre, cosi' l'annuncio
      -- parte quando la raffica di fetch si e' esaurita.
      incoming_notice_gen = incoming_notice_gen + 1
      local gen = incoming_notice_gen
      vim.defer_fn(function()
        if gen == incoming_notice_gen then flush_incoming_notice() end
      end, 1500)
    end)
  end

  -- Collegamento e scollegamento di un'unita' esterna. Sta fuori dal giro
  -- pesante e viene interrogato molto piu' spesso: costa uno `stat` per i soli
  -- progetti esterni - di solito uno o due - mentre il resto del polling deve
  -- lanciare processi git. Infilarlo li' dentro voleva dire accorgersi del
  -- disco fino a cinque secondi dopo averlo inserito.
  local function check_drives()
    if closed then return end
    local changed = false
    for _, it in ipairs(st.all) do
      if it.is_external or it.is_disconnected then
        local there = vim.fn.isdirectory(it.path) == 1
        if it.is_disconnected == there then
          changed = true
          break
        end
      end
    end
    if not changed then return end
    -- Il disco e' cambiato davvero, ma se l'utente sta scrivendo si aspetta:
    -- ricostruire la lista sotto le dita farebbe saltare la ricerca.
    if ((vim.uv or vim.loop).now() - last_type_time) < 800 then return end

    st.all = P.list(true)
    filter(st)
    P.load_git(st.all, function()
      if not closed then
        render_list(st)
        if (st.view_mode or "inspector") == "inspector" then
          render_preview(st)
        end
      end
    end, true)
    P.load_languages(st.all, function()
      if not closed then
        render_list(st)
        if (st.view_mode or "inspector") == "inspector" then
          render_preview(st)
        end
      end
    end, true)
  end

  local function live_refresh_git()
    if closed or is_refreshing_git then return end
    -- Priorità assoluta alla digitazione: se l'utente sta scrivendo nella ricerca,
    -- ritarda il polling di background per garantire 60 FPS e 0ms di latenza sui tasti.
    local now = (vim.uv or vim.loop).now()
    if (now - last_type_time) < 800 then return end

    local prev_git = {}
    for _, it in ipairs(st.all) do
      if it.git and not it.git.none then
        prev_git[it.path] = {
          commits = it.git.commits or 0,
          dirty = it.git.dirty or false,
        }
      end
    end

    is_refreshing_git = true
    P.load_git(st.all, function()
      is_refreshing_git = false
      if not closed then
        local grown = {}
        local any_changed = false
        for _, it in ipairs(st.all) do
          local old = prev_git[it.path]
          if old and it.git and not it.git.none then
            if (it.git.commits or 0) > (old.commits or 0) then
              grown[#grown + 1] = it
              any_changed = true
            elseif (it.git.commits or 0) ~= (old.commits or 0) or (it.git.dirty ~= old.dirty) then
              any_changed = true
            end
          end
        end

        -- Una notifica per ciascun progetto cresciuto: prima la variabile
        -- veniva sovrascritta nel ciclo e ne partiva una sola, per l'ultimo
        -- trovato, mentre gli altri cambiamenti sparivano in silenzio.
        for _, it in ipairs(grown) do
          notify(i18n.t("notify_git_update", it.name), nil, "snap", "snap")
          -- HEAD si e' mosso, tipicamente per un pull: cio' che risultava in
          -- arrivo e' appena atterrato. Il ricalcolo locale non tocca la rete
          -- e fa sparire il divider subito, invece che al fetch successivo.
          P.recount_incoming(it.path)
        end

        if any_changed then
          render_list(st)
          if (st.view_mode or "inspector") == "inspector" then
            render_preview(st)
          end
        end
      end
    end, true)

    refresh_incoming_now()
  end

  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    buffer = st.input.buf,
    callback = function()
      last_type_time = (vim.uv or vim.loop).now()
      sound.play("typing")
      filter(st)
    end,
  })

  -- Rete di sicurezza sull'uscita. Gli autocmd qui sopra sono legati ai buffer
  -- della dashboard, e con `:qa` Neovim non li percorre uno per uno: il timer
  -- della marquee restava aperto, e un handle libuv vivo impedisce al processo
  -- di terminare. Chi chiude Neovim non deve aspettare che un plugin si accorga
  -- che e' finita, in qualunque modo ci si arrivi.
  vim.api.nvim_create_autocmd({ "VimLeavePre", "VimLeave" }, {
    group = grp,
    callback = function()
      close()
    end,
  })

  vim.api.nvim_create_autocmd({ "FocusGained", "VimResume", "BufWritePost", "FileChangedShellPost" }, {
    group = grp,
    callback = function()
      check_drives()
      live_refresh_git()
    end,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = grp,
    callback = function()
      if closed then return end
      layout_windows()
      refresh(st)
    end,
  })

  vim.api.nvim_create_autocmd("WinScrolled", {
    group = grp,
    callback = function()
      if closed then return end
      if vim.api.nvim_win_is_valid(st.list.win) then render_scrollbar(st) end
      if vim.api.nvim_win_is_valid(st.preview.win) then render_preview_scrollbar(st) end
    end,
  })

  st.marquee_offset = 0
  local live_git_tick = 0
  local timer = (vim.uv or vim.loop).new_timer()
  st.marquee_timer = timer
  timer:start(500, 500, vim.schedule_wrap(function()
    if closed then
      pcall(function()
        timer:stop()
        timer:close()
      end)
      return
    end
    st.marquee_offset = st.marquee_offset + 1
    if st.list and vim.api.nvim_win_is_valid(st.list.win) and vim.api.nvim_buf_is_valid(st.list.buf) then
      render_list(st, true)
    end

    check_drives()

    live_git_tick = live_git_tick + 1
    if live_git_tick % 10 == 0 then
      live_refresh_git()
    end
  end))

  -- Caricamento Asincrono non bloccante 1: Stato Git
  P.load_git(st.all, function()
    if not closed then reapply(st) end
  end)

  -- Il primo giro di rete non parte insieme all'apertura: la finestra deve
  -- prima disegnarsi e accettare i primi tasti senza contendersi la CPU con
  -- una manciata di processi git.
  vim.defer_fn(function()
    if not closed then refresh_incoming_now() end
  end, 3000)

  -- Caricamento Asincrono non bloccante 2 (O(N) Lazy): Percentuali dei Linguaggi
  P.load_languages(st.all, function()
    if not closed then render_list(st) end
  end)

  M.active_st = st
  return st
end

--- Ri-renderizza la dashboard aperta. Ri-scansiona anche i progetti (non
--- solo il disegno a schermo): serve perche' alcuni campi come "oggi"/
--- "Mancante" sono calcolati una volta sola dentro P.list() e restano
--- nella vecchia lingua finche' non si forza un refresh dei dati, ad
--- esempio dopo un cambio lingua da fuori dalla dashboard (:ProjectHubLang).
function M.refresh()
  if not M.is_open() then return end
  local st = M.active_st
  st.all = P.list(true)
  filter(st)
  P.load_git(st.all, function() render_list(st) end, true)
  P.load_languages(st.all, function() render_list(st) end, true)
  refresh(st)
end

return M
