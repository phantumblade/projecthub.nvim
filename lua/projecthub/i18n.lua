-- Testi dell'interfaccia in italiano e inglese.
-- require("projecthub").set_language("it"|"en") cambia lingua a runtime,
-- oppure si imposta una volta sola con l'opzione `language` di setup().
-- Le icone restano scritte nel codice chiamante: qui c'e' solo il testo,
-- cosi' non serve toccare i glifi Nerd Font per tradurre.
local M = {}

M.locales = {
  it = {
    list_title = " progetti  %d/%d ",
    list_title_filtered = " progetti  %s  %d/%d ",
    section_recent = "recenti (%d)",
    section_mine = "i tuoi progetti (%d)",
    section_others = "altri progetti (%d)",
    section_browse = "sfoglia cartelle (%s)",
    section_relocate = "riconnetti '%s' (%s)",
    filtered_count = "%d/%d filtrate",

    empty_title = "Nessun progetto trovato",
    empty_subtitle = "con i seguenti tag:",
    tree_empty = "(cartella vuota)",
    no_description = "nessuna descrizione",
    not_versioned = "non versionato",
    not_tracked = "non tracciato",
    unknown = "sconosciuta",
    today = "oggi",
    yesterday = "ieri",
    days_ago = "%d giorni fa",
    months_ago = "%d mesi fa",
    years_ago = "%d anni fa",
    missing_type = "Mancante",
    missing_desc = "Percorso non trovato sul disco.",
    missing_search_terms = "mancante spostato eliminato non trovato",

    btn_inspector = "Ispettore",
    btn_add = "Aggiungi",
    btn_add_project = "Aggiungi Progetto",
    btn_reconnect_here = "Riconnetti Qui",
    btn_note = "Note",
    btn_search = "Cerca",
    btn_navigate = "Naviga",
    btn_arrows = "Frecce",
    btn_enter_dir = "Entra",
    btn_back = "Indietro",
    btn_open = "Apri",
    btn_exit = "Esci",
    btn_commit = "Commit",
    btn_readme = "README",
    btn_tree = "Albero",
    btn_github = "GitHub",
    btn_web_preview = "Preview Web",
    btn_live = "Live",
    btn_reconnect = "Riconnetti",
    btn_remove = "Rimuovi",
    btn_lang = "Lingua",
    up_dir = ".. (Cartella Superiore)",
    already_registered_badge = "[GIÀ REGISTRATO]",
    generic_folder = "cartella",

    title_preview = "anteprima",
    title_tree = "albero",
    title_web_preview = "web preview",
    title_info = "informazioni",
    title_commits = "cronologia commit",
    title_browse = " Sfoglia Cartelle  %s ",
    title_reconnect = " Riconnetti '%s'  %s ",

    overview = "PANORAMICA",
    loc_lines = "Righe di Codice:    %s righe totali",
    loc_files = "File Sorgente:      %s file di progetto",
    loc_calculating_lines = "Righe di Codice:    (calcolo in corso...)",
    loc_calculating_files = "File Sorgente:      (calcolo in corso...)",
    git_history = "Cronologia Git:      %s",
    git_history_commits_branch = "%s commit %s",
    git_history_none = "non tracciato",
    last_modified = "Ultima Modifica:     %s",
    team = "TEAM & COLLABORATORI  (%d sviluppatori)",
    team_more = "... altri %d sviluppatori (Premi c per la lista completa)",
    commit_stat = "%d commit (%d%%)",
    commits_full = "CRONOLOGIA COMMIT GIT COMPLETA  (%d commit totali - Premi 'c' per comprimere)",
    commits_recent = "CRONOLOGIA COMMIT GIT  (I 5 commit più recenti)",
    commits_none = "(nessun commit git nel repository)",
    commits_more = "... altri %d commit (Premi c per la cronologia completa)",
    commits_load_more = "... mostrati %d commit su %s (Premi 'm' per caricarne altri 100)",
    press_c = "Premi c",
    press_n = "Premi n",
    notes_title = "NOTE & APPUNTI",
    notes_empty_1 = "Nessuna nota memorizzata per questo progetto.",
    notes_empty_2 = "Gli appunti sono locali e non occupano spazio nel repository.",
    notes_hint = "Premi n per aggiungere un appunto",
    notes_stats = "%d parole  •  %d caratteri",
    missing_box_title = "CARTELLA SPOSTATA O ELIMINATA",
    missing_box_line1 = "La cartella di questo progetto non è più presente",
    missing_box_line2 = "nella posizione originale memorizzata:",
    missing_box_actions = "AZIONI CONSIGLIATE:",
    missing_box_reconnect = "• Premi r per riconnettere la nuova posizione",
    missing_box_untrack = "• Premi d per rimuovere questo tracciamento",
    header_moved = "SPOSTATO / ELIMINATO",
    header_private = "PRIVATO",
    header_public = "PUBBLICO",
    header_local = "LOCALE",
    fork_of = "fork di %s",
    fork_of_original = "fork di repository originale",

    dirpicker_title = "ISPETTORE CARTELLA",
    dirpicker_path = "Percorso: %s",
    dirpicker_subdirs = "Sotto-cartelle:  %s cartelle",
    dirpicker_files = "File Contenuti:  %s file",
    dirpicker_already = "'%s' È GIÀ UN PROGETTO REGISTRATO",
    dirpicker_add = "PREMI  a  PER AGGIUNGERE '%s' COME PROGETTO",
    dirpicker_reconnect = "PREMI  a  PER RICONNETTERE '%s' QUI",
    relocate_title = "RICONNESSIONE PROGETTO: %s",
    relocate_old_path = "Vecchio percorso:  %s",
    relocate_new_path = "Nuovo percorso:    %s",

    missing_warning = "PROGETTO ELIMINATO O SPOSTATO",
    missing_explanation = "La cartella di questo progetto non è più presente nella posizione originale memorizzata su disco.",
    missing_press_keys = "premi i seguenti tasti:",
    missing_btn_reconnect = "Riconnetti",
    missing_btn_remove = "Rimuovi traccia",

    notify_no_projects = "Nessun progetto trovato: controlla 'roots' ed 'extra' passati a require('projecthub').setup({...})",
    notify_no_commits = "Nessun commit Git disponibile per '%s'",
    notify_opening_github = "Apertura %s nel browser...",
    notify_no_github = "Questo progetto non ha un repository GitHub collegato",
    notify_opening_web_preview = "Apertura anteprima web (%s) nel browser...",
    notify_no_html = "Nessun file HTML (index.html) trovato in questo progetto",
    notify_already_registered_title = "Già Registrato",
    notify_already_registered_body = "'%s' è già presente nei tuoi progetti.\nScegli un'altra cartella.",
    notify_reconnected_title = "Progetto Riconnesso Con Successo!",
    notify_reconnected_body = "Il nuovo percorso di '%s' è:\n%s",
    notify_reconnect_failed_title = "Riconnessione Fallita: %s",
    notify_reconnect_failed_body = "Motivo: %s",
    notify_removed_title = "Progetto Rimosso",
    notify_removed_body = "Il riferimento a '%s' è stato eliminato con successo dai tuoi progetti.",
    notify_note_saved = "Nota per '%s' salvata con successo!",
    notify_note_removed = "Nota per '%s' rimossa",
    notify_lang_switched = "Lingua impostata su italiano",
    prompt_note = " Nota per %s: ",

    err_empty_path_title = "Percorso Non Valido",
    err_empty_path_body = "Il percorso specificato è vuoto.",
    err_not_found_title = "Cartella Non Trovata",
    err_not_found_body = "Il percorso '%s' non esiste sul disco.",
    err_not_dir_title = "Tipo Non Valido",
    err_not_dir_body = "'%s' è un file e non una cartella.",
    err_already_title = "Già Registrato",
    err_already_body = "'%s' è già presente nei tuoi progetti.",
    err_write_title = "Errore Scrittura JSON",
    err_write_body = "Impossibile salvare la configurazione.",
    ok_added_title = "Progetto Aggiunto",
    ok_added_body = "La cartella '%s' è stata registrata con successo!",
    notify_op_failed_title = "Operazione Fallita: %s",
    notify_op_failed_body = "Motivo: %s",
  },

  en = {
    list_title = " projects  %d/%d ",
    list_title_filtered = " projects  %s  %d/%d ",
    section_recent = "recent (%d)",
    section_mine = "your projects (%d)",
    section_others = "other projects (%d)",
    section_browse = "browse folders (%s)",
    section_relocate = "reconnect '%s' (%s)",
    filtered_count = "%d/%d filtered",

    empty_title = "No project found",
    empty_subtitle = "with the following tags:",
    tree_empty = "(empty folder)",
    no_description = "no description",
    not_versioned = "not versioned",
    not_tracked = "not tracked",
    unknown = "unknown",
    today = "today",
    yesterday = "yesterday",
    days_ago = "%d days ago",
    months_ago = "%d months ago",
    years_ago = "%d years ago",
    missing_type = "Missing",
    missing_desc = "Path not found on disk.",
    missing_search_terms = "missing moved deleted not found",

    btn_inspector = "Inspector",
    btn_add = "Add",
    btn_add_project = "Add Project",
    btn_reconnect_here = "Reconnect Here",
    btn_note = "Note",
    btn_search = "Search",
    btn_navigate = "Navigate",
    btn_arrows = "Arrows",
    btn_enter_dir = "Enter",
    btn_back = "Back",
    btn_open = "Open",
    btn_exit = "Quit",
    btn_commit = "Commit",
    btn_readme = "README",
    btn_tree = "Tree",
    btn_github = "GitHub",
    btn_web_preview = "Web Preview",
    btn_live = "Live",
    btn_reconnect = "Reconnect",
    btn_remove = "Remove",
    btn_lang = "Language",
    up_dir = ".. (Parent Folder)",
    already_registered_badge = "[ALREADY TRACKED]",
    generic_folder = "folder",

    title_preview = "preview",
    title_tree = "tree",
    title_web_preview = "web preview",
    title_info = "info",
    title_commits = "commit history",
    title_browse = " Browse Folders  %s ",
    title_reconnect = " Reconnect '%s'  %s ",

    overview = "OVERVIEW",
    loc_lines = "Lines of Code:      %s total lines",
    loc_files = "Source Files:       %s project files",
    loc_calculating_lines = "Lines of Code:      (calculating...)",
    loc_calculating_files = "Source Files:       (calculating...)",
    git_history = "Git History:         %s",
    git_history_commits_branch = "%s commits %s",
    git_history_none = "not tracked",
    last_modified = "Last Modified:       %s",
    team = "TEAM & CONTRIBUTORS  (%d developers)",
    team_more = "... %d more contributors (press c for the full list)",
    commit_stat = "%d commits (%d%%)",
    commits_full = "FULL GIT COMMIT HISTORY  (%d total commits - press 'c' to collapse)",
    commits_recent = "GIT COMMIT HISTORY  (5 most recent)",
    commits_none = "(no git commits in this repository)",
    commits_more = "... %d more commits (press c for the full history)",
    commits_load_more = "... showing %d commits of %s (Press 'm' to load 100 more)",
    press_c = "press c",
    press_n = "press n",
    notes_title = "NOTES",
    notes_empty_1 = "No note saved for this project yet.",
    notes_empty_2 = "Notes are local and don't take up space in the repository.",
    notes_hint = "Press n to add a note",
    notes_stats = "%d words  •  %d characters",
    missing_box_title = "FOLDER MOVED OR DELETED",
    missing_box_line1 = "This project's folder is no longer present",
    missing_box_line2 = "at its originally recorded location:",
    missing_box_actions = "SUGGESTED ACTIONS:",
    missing_box_reconnect = "• Press r to reconnect it to its new location",
    missing_box_untrack = "• Press d to remove this tracking entry",
    header_moved = "MOVED / DELETED",
    header_private = "PRIVATE",
    header_public = "PUBLIC",
    header_local = "LOCAL",
    fork_of = "fork of %s",
    fork_of_original = "fork of the original repository",

    dirpicker_title = "FOLDER INSPECTOR",
    dirpicker_path = "Path: %s",
    dirpicker_subdirs = "Subfolders:  %s folders",
    dirpicker_files = "Contents:    %s files",
    dirpicker_already = "'%s' IS ALREADY A TRACKED PROJECT",
    dirpicker_add = "PRESS  a  TO ADD '%s' AS A PROJECT",
    dirpicker_reconnect = "PRESS  a  TO RECONNECT '%s' HERE",
    relocate_title = "RECONNECTING PROJECT: %s",
    relocate_old_path = "Old path:  %s",
    relocate_new_path = "New path:  %s",

    missing_warning = "PROJECT DELETED OR MOVED",
    missing_explanation = "This project's folder is no longer present at its originally recorded location on disk.",
    missing_press_keys = "press one of the following keys:",
    missing_btn_reconnect = "Reconnect",
    missing_btn_remove = "Remove tracking",

    notify_no_projects = "No projects found: check the 'roots' and 'extra' options passed to require('projecthub').setup({...})",
    notify_no_commits = "No Git commits available for '%s'",
    notify_opening_github = "Opening %s in the browser...",
    notify_no_github = "This project has no linked GitHub repository",
    notify_opening_web_preview = "Opening web preview (%s) in browser...",
    notify_no_html = "No HTML file (index.html) found in this project",
    notify_already_registered_title = "Already Tracked",
    notify_already_registered_body = "'%s' is already one of your tracked projects.\nPick another folder.",
    notify_reconnected_title = "Project Reconnected!",
    notify_reconnected_body = "The new path for '%s' is:\n%s",
    notify_reconnect_failed_title = "Reconnect Failed: %s",
    notify_reconnect_failed_body = "Reason: %s",
    notify_removed_title = "Project Removed",
    notify_removed_body = "The reference to '%s' was successfully removed from your projects.",
    notify_note_saved = "Note for '%s' saved successfully!",
    notify_note_removed = "Note for '%s' removed",
    notify_lang_switched = "Language set to English",
    prompt_note = " Note for %s: ",

    err_empty_path_title = "Invalid Path",
    err_empty_path_body = "The given path is empty.",
    err_not_found_title = "Folder Not Found",
    err_not_found_body = "The path '%s' does not exist on disk.",
    err_not_dir_title = "Invalid Type",
    err_not_dir_body = "'%s' is a file, not a folder.",
    err_already_title = "Already Tracked",
    err_already_body = "'%s' is already one of your tracked projects.",
    err_write_title = "Write Error",
    err_write_body = "Could not save the configuration.",
    ok_added_title = "Project Added",
    ok_added_body = "The folder '%s' was successfully registered!",
    notify_op_failed_title = "Operation Failed: %s",
    notify_op_failed_body = "Reason: %s",
  },
}

function M.detect_system_lang()
  local env = os.getenv("LANG") or os.getenv("LC_ALL") or os.getenv("LC_MESSAGES") or ""
  if env:lower():find("^it") then
    return "it"
  end
  return "en"
end

function M.get_lang()
  local ok, config = pcall(require, "projecthub.config")
  local lang = ok and config.options.language or nil
  if not lang or lang == "auto" then
    lang = M.detect_system_lang()
  end
  if not M.locales[lang] then lang = "en" end
  return lang
end

--- Traduce `key` nella lingua corrente. Argomenti extra vengono passati a
--- string.format se la stringa contiene dei segnaposto (%s, %d, ...).
function M.t(key, ...)
  local locale = M.locales[M.get_lang()] or M.locales.en
  local str = locale[key] or M.locales.en[key] or key
  if select("#", ...) > 0 then
    local ok, formatted = pcall(string.format, str, ...)
    if ok then return formatted end
  end
  return str
end

--- Converte le date relative di Git (es. "2 minutes ago", "5 hours ago")
--- nella lingua dell'interfaccia corrente.
function M.format_relative_time(raw_str)
  if not raw_str or raw_str == "" then return "" end
  local lang = M.get_lang()
  if lang == "en" then
    return raw_str
  end

  local s = vim.trim(raw_str:lower())
  if s == "just now" or s:find("second") then
    return "pochi secondi fa"
  end

  local num, unit = s:match("^(%d+)%s+([%a]+)%s+ago$")
  if num and unit then
    local n = tonumber(num) or 1
    if unit:find("^min") then
      return (n == 1) and "1 minuto fa" or string.format("%d minuti fa", n)
    elseif unit:find("^hour") then
      return (n == 1) and "1 ora fa" or string.format("%d ore fa", n)
    elseif unit:find("^day") then
      return (n == 1) and "1 giorno fa" or string.format("%d giorni fa", n)
    elseif unit:find("^week") then
      return (n == 1) and "1 settimana fa" or string.format("%d settimane fa", n)
    elseif unit:find("^month") then
      return (n == 1) and "1 mese fa" or string.format("%d mesi fa", n)
    elseif unit:find("^year") then
      return (n == 1) and "1 anno fa" or string.format("%d anni fa", n)
    end
  end

  return raw_str
end

return M
