-- Schermata progetti: ricerca in alto, schede su due colonne a sinistra,
-- anteprima del README (o albero delle cartelle) a destra.
local P = require("projecthub.projects")
local config = require("projecthub.config")

local M = {}
local ns = vim.api.nvim_create_namespace("projecthub")
local ns_html = vim.api.nvim_create_namespace("projecthub_html")
local ns_sb = vim.api.nvim_create_namespace("projecthub_scrollbar")
local ns_psb = vim.api.nvim_create_namespace("projecthub_preview_scrollbar")
local ns_input = vim.api.nvim_create_namespace("projecthub_input")
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
  markdown = { name = "Markdown", hl = "ProjectsPillMarkdown" },
  md = { name = "Markdown", hl = "ProjectsPillMarkdown" },
  shell = { name = "Shell", hl = "ProjectsPillShell" },
  bash = { name = "Shell", hl = "ProjectsPillShell" },
  android = { name = "Android", hl = "ProjectsType" },
  node = { name = "Node", hl = "ProjectsPillJS" },
}

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
    ProjectsGitClean = "DiagnosticOk",
    ProjectsTreeDir = "Directory",
    ProjectsScrollbarThumb = "DiagnosticWarn",
  }

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
    ProjectsCommitBranch = { fg = "#73daca" },
    ProjectsTagFeat = { fg = "#73daca", bold = true },
    ProjectsTagChange = { fg = "#ff9e64", bold = true },
    ProjectsTagFix = { fg = "#f7768e", bold = true },
    ProjectsTagChore = { fg = "#bb9af7", bold = true },
    ProjectsTagDocs = { fg = "#e0af68", bold = true },
    ProjectsTagRefactor = { fg = "#b4f9f8", bold = true },
    ProjectsCommitAuthor = { fg = "#2ac3de" },
    ProjectsCommitAuthorPill = { fg = "#7aa2f7", bg = "#273147", bold = true },
    ProjectsAuthorPill_1 = { fg = "#7aa2f7", bg = "#222a3d", bold = true },
    ProjectsAuthorPill_2 = { fg = "#73daca", bg = "#1d3331", bold = true },
    ProjectsAuthorPill_3 = { fg = "#bb9af7", bg = "#2b213b", bold = true },
    ProjectsAuthorPill_4 = { fg = "#ff9e64", bg = "#38271e", bold = true },
    ProjectsAuthorPill_5 = { fg = "#e0af68", bg = "#332b1b", bold = true },
    ProjectsAuthorPill_6 = { fg = "#f7768e", bg = "#382028", bold = true },
    ProjectsCommitDate = { fg = "#565f89" },
    ProjectsPostItText = { fg = "#e0af68", bold = true },
    ProjectsPostItMuted = { fg = "#565f89", italic = true },
    ProjectsHeaderPublic = { fg = "#73daca", bold = true },
    ProjectsHeaderPrivate = { fg = "#bb9af7", bold = true },
    ProjectsHeaderLocal = { fg = "#565f89", italic = true },
    ProjectsHeaderStars = { fg = "#e0af68", bold = true },
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
    vim.api.nvim_set_hl(0, "ProjectsScrollbarThumb", {
      fg = accent.fg or accent.sp,
      bold = true,
      default = false,
    })
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

local function get_author_pill_hl(author_name)
  local h = 0
  author_name = tostring(author_name or "user")
  for i = 1, #author_name do
    h = h + string.byte(author_name, i)
  end
  local idx = (h % 6) + 1
  return "ProjectsAuthorPill_" .. idx
end

local function join(chunks)
  local text, hls = "", {}
  for _, c in ipairs(chunks) do
    local from = #text
    text = text .. c[1]
    if c[2] then hls[#hls + 1] = { from, #text, c[2] } end
  end
  return text, hls
end

local function chunks_width(chunks)
  local n = 0
  for _, c in ipairs(chunks) do n = n + dw(c[1]) end
  return n
end

local function git_chunks(g)
  if not g then return { { "…", "ProjectsMeta" } }, {} end
  if g.none then return { { "non versionato", "ProjectsMeta" } }, {} end

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
    add("  ✓", "ProjectsGitClean")
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

  local badge = " " .. (p.type and p.type:upper() or "MANCANTE") .. " "

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

local function card(p, w, sel)
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

  local ptype = p.type and (" " .. p.type .. " ") or ""
  local name = fit(p.name, iw - dw(ptype) - 2)
  local desc = p.desc and fit(p.desc, iw) or "nessuna descrizione"
  local age = p.ago or ""
  local dir = fit(p.dir, iw - dw(age) - 2)
  local gl, gr = git_chunks(p.git)

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
        if idx <= 4 then
          if idx > 1 then
            legend_chunks[#legend_chunks + 1] = { "  " }
          end
          legend_chunks[#legend_chunks + 1] = { "● ", lang.hl }
          legend_chunks[#legend_chunks + 1] = { lang.name .. " ", "ProjectsMeta" }
          legend_chunks[#legend_chunks + 1] = { lang.pct .. "%", "ProjectsMeta" }
        end
      end
    end
  else
    bar_chunks = { { string.rep("━", iw), "ProjectsLangTrack" } }
    legend_chunks = { { "analizzando linguaggi...", "ProjectsMeta" } }
  end

  local rows_out = {
    { { "╭" .. string.rep("─", w - 2) .. "╮", bhl } },
    row({ { name, nhl } }, { { ptype, "ProjectsType" } }),
    row({ { desc, p.desc and "ProjectsDesc" or "ProjectsMeta" } }, {}),
    row({ { dir, "ProjectsDir" } }, { { age, "ProjectsMeta" } }),
    row(gl, gr),
  }

  if #bar_chunks > 0 then
    rows_out[#rows_out + 1] = row(bar_chunks, {})
    rows_out[#rows_out + 1] = row(legend_chunks, {})
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
  if #out == 0 then out = { "(cartella vuota)" } end
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
local function highlight_input_languages(st)
  local buf = st.input.buf
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end
  vim.api.nvim_buf_clear_namespace(buf, ns_input, 0, -1)

  local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
  if line == "" then return end

  for start_pos, word in line:gmatch("()(%S+)") do
    local info = LANG_TOKENS[word:lower()]
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
  if st.dir_picker_mode then
    max_content = #(st.dir_entries or {}) + 3
  elseif st.pos then
    for _, lnum in pairs(st.pos) do
      if lnum + CARD_ROWS - 1 > max_content then
        max_content = lnum + CARD_ROWS - 1
      end
    end
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
  end)
  render_preview_scrollbar(st)
end

local function render_inspector(st)
  if not (st.preview and vim.api.nvim_win_is_valid(st.preview.win)) then return end

  local p = st.items[st.sel]
  if not p then return end

  if not (st.preview.buf and vim.api.nvim_buf_is_valid(st.preview.buf)) then
    st.preview.buf = vim.api.nvim_create_buf(false, true)
  end
  local buf = st.preview.buf

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
  local commits = P.get_commit_details(p.path, 30)

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
    vis_text = "󰅖 SPOSTATO / ELIMINATO"
    vis_hl = "ProjectsHeaderMissing"
  elseif gh_meta then
    if gh_meta.is_private then
      vis_text = "󰌾 PRIVATO"
      vis_hl = "ProjectsHeaderPrivate"
    else
      vis_text = "󰖟 PUBBLICO"
      vis_hl = "ProjectsHeaderPublic"

      if (gh_meta.stars or 0) > 0 then
        star_text = "  ★ " .. gh_meta.stars
      end
      if (gh_meta.forks or 0) > 0 then
        fork_text = "  " .. M.FORK_ICON .. gh_meta.forks
      end
    end

    if gh_meta.owner and gh_meta.owner:lower() ~= current_user:lower() then
      show_owner_pill = true
      owner_pill_str = " [" .. M.ORG_ICON .. gh_meta.owner .. "]"
    end
  else
    vis_text = "󰌾 LOCALE"
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

  add("   " .. p.path, "ProjectsDir")

  add("")
  add("  \u{e66a} PANORAMICA", "ProjectsTitleSpecial")

  if p.is_missing then
    add("   ┌─ 󰅖 CARTELLA SPOSTATA O ELIMINATA ───────────────────┐", "ProjectsHeaderMissing")
    add("   │                                                       │", "ProjectsHeaderMissing")
    add("   │  La cartella di questo progetto non è più presente    │", "ProjectsHeaderMissing")
    add("   │  nella posizione originale memorizzata:               │", "ProjectsDesc")
    add("   │  " .. fit(p.path, pw - 10) .. string.rep(" ", math.max(0, pw - 10 - dw(fit(p.path, pw - 10)))) .. " │", "ProjectsMeta")
    add("   │                                                       │", "ProjectsHeaderMissing")
    add("   │  AZIONI CONSIGLIATE:                                  │", "ProjectsName")
    add("   │  • Premi r per riconnettere la nuova posizione        │", "ProjectsGitBranch")
    add("   │  • Premi d per rimuovere questo tracciamento           │", "ProjectsGitBranch")
    add("   └───────────────────────────────────────────────────────┘", "ProjectsHeaderMissing")
  else
    if p.loc_lines then
      add("   󰈙 Righe di Codice:    " .. fmt_num(p.loc_lines) .. " righe totali", "ProjectsGitBranch")
      add("   󰉏 File Sorgente:      " .. fmt_num(p.loc_files) .. " file di progetto", "ProjectsGitBranch")
    else
      add("   󰈙 Righe di Codice:    (calcolo in corso...)", "ProjectsDesc")
      add("   󰉏 File Sorgente:      (calcolo in corso...)", "ProjectsDesc")
    end

    local sel_idx = st.sel
    local limit = st.show_all_commits and 100 or 50
    local commits, author_stats = P.get_commit_details(p.path, limit)

    if not P.has_gh_cache(p.path) then
      P.async_load_github_meta(p.path, function()
        if vim.api.nvim_win_is_valid(st.preview.win) and st.sel == sel_idx and st.inspector_mode then
          render_preview(st)
        end
      end)
    end

    local branch_str = (p.git and p.git.branch) and ("[" .. tostring(p.git.branch) .. "]") or "[main]"
    local git_num_commits = (p.git and p.git.commits) and tostring(p.git.commits) or "0"
    add("   󰊢 Cronologia Git:      " .. (p.git and (git_num_commits .. " commit " .. branch_str) or "non tracciato"), "ProjectsGitStaged")
    add("   󰃭 Ultima Modifica:     " .. tostring(p.ago or "sconosciuta"), "ProjectsMeta")
  end

  if author_stats and #author_stats > 1 then
    add("")
    add(string.format("  󰓓 TEAM & COLLABORATORI  (%d sviluppatori)", #author_stats), "ProjectsName")

    local tot_c = 0
    for _, ast in ipairs(author_stats) do
      tot_c = tot_c + (ast.count or 0)
    end
    if tot_c == 0 then tot_c = 1 end

    local max_authors = st.show_all_commits and #author_stats or math.min(3, #author_stats)
    for i = 1, max_authors do
      local ast = author_stats[i]
      if ast and ast.name then
        local a_name = tostring(ast.name)
        local c_num = ast.count or 0
        local pct = math.floor((c_num / tot_c) * 100 + 0.5)
        local role_icon = ast.is_owner and M.OWNER_ICON or M.MEMBER_ICON
        local pill_str = "[" .. role_icon .. a_name .. "]"
        local indent = "   "
        local stat_str = string.format("%d commit (%d%%)", c_num, pct)

        local line_left = indent .. pill_str .. "  "
        local fill_w = math.max(1, pw - 6 - vim.api.nvim_strwidth(line_left) - vim.api.nvim_strwidth(stat_str))
        local full_line = line_left .. string.rep(" ", fill_w) .. stat_str

        lines[#lines + 1] = full_line
        local r_idx = #lines - 1

        local p_start = #indent
        local p_end = p_start + #pill_str
        local a_hl = get_author_pill_hl(a_name)
        hls[#hls + 1] = { r_idx, p_start, p_end, a_hl }

        local s_start = #full_line - #stat_str
        hls[#hls + 1] = { r_idx, s_start, #full_line, "ProjectsGitStaged" }
      end
    end

    if not st.show_all_commits and #author_stats > 3 then
      local a_more = string.format("   ... altri %d sviluppatori (Premi c per la lista completa)", #author_stats - 3)
      add(a_more, "ProjectsMeta")
      local l_idx = #lines - 1
      local c_pos = a_more:find("Premi c")
      if c_pos then
        hls[#hls + 1] = { l_idx, c_pos + 6, c_pos + 7, "ProjectsKeyText" }
      end
    end
  end

  local function add_commit_row(c, b_name, max_w)
    if not c then return end
    local subject = tostring(c.subject or "")
    local tag_prefix = ""
    local tag_hl = "ProjectsGitBranch"

    local tag_word, rest = subject:match("^(%A*%a+)%s+(.*)$")
    if tag_word then
      local tag_u = tag_word:upper()
      if tag_u == "FEAT" then tag_prefix = "[FEAT] "; tag_hl = "ProjectsTagFeat"; subject = rest
      elseif tag_u == "CHANGE" or tag_u == "CHANGED" then tag_prefix = "[CHANGE] "; tag_hl = "ProjectsTagChange"; subject = rest
      elseif tag_u == "FIX" or tag_u == "FIXED" then tag_prefix = "[FIX] "; tag_hl = "ProjectsTagFix"; subject = rest
      elseif tag_u == "CHORE" then tag_prefix = "[CHORE] "; tag_hl = "ProjectsTagChore"; subject = rest
      elseif tag_u == "DOCS" or tag_u == "DOC" then tag_prefix = "[DOCS] "; tag_hl = "ProjectsTagDocs"; subject = rest
      elseif tag_u == "REFACTOR" then tag_prefix = "[REFACTOR] "; tag_hl = "ProjectsTagRefactor"; subject = rest
      end
    end

    local indent = "   "
    local hash_str = tostring(c.hash or "???") .. " "
    local b_clean = tostring(b_name or "main"):gsub("^%[", ""):gsub("%]$", "")
    local b_str = "󰘬 " .. b_clean .. "  "
    local date_str = tostring(c.age or "")
    local author_name = tostring(c.author or "")
    local role_icon = c.is_owner and M.OWNER_ICON or M.MEMBER_ICON
    local author_pill = (c.show_author and author_name ~= "") and (" [" .. role_icon .. author_name .. "] ") or ""
    local gap = (#author_pill > 0) and "  " or ""
    local right_block = date_str .. gap .. author_pill

    local fixed_w = dw(indent) + dw(hash_str) + dw(b_str) + dw(tag_prefix) + dw(right_block)
    local avail_for_subj = max_w - fixed_w

    subject = subject:gsub("[%s%.…]+$", "")

    if dw(subject) > avail_for_subj then
      subject = fit(subject, avail_for_subj)
    end

    local left_line = indent .. hash_str .. b_str .. tag_prefix .. subject
    local space_fill = math.max(0, max_w - dw(left_line) - dw(right_block))
    local full_line = left_line .. string.rep(" ", space_fill) .. right_block

    lines[#lines + 1] = full_line
    local row_idx = #lines - 1

    local c0 = 0
    c0 = c0 + #indent

    local c_hash_end = c0 + #hash_str
    hls[#hls + 1] = { row_idx, c0, c_hash_end, "ProjectsCommitHash" }
    c0 = c_hash_end

    local c_branch_end = c0 + #b_str
    hls[#hls + 1] = { row_idx, c0, c_branch_end, "ProjectsCommitBranch" }
    c0 = c_branch_end

    if #tag_prefix > 0 then
      local c_tag_end = c0 + #tag_prefix
      hls[#hls + 1] = { row_idx, c0, c_tag_end, tag_hl }
      c0 = c_tag_end
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
      local author_hl = get_author_pill_hl(author_name)
      hls[#hls + 1] = { row_idx, pill_start, #full_line, author_hl }
    end
  end

  add("")
  if st.show_all_commits then
    add("  󰋚 CRONOLOGIA COMMIT GIT COMPLETA  (" .. #commits .. " commit totali - Premi 'c' per comprimere)", "ProjectsName")

    if #commits > 0 then
      for _, c in ipairs(commits) do
        add_commit_row(c, branch_str, pw - 4)
      end
    else
      add("   (nessun commit git nel repository)", "ProjectsDesc")
    end
  else
    add("  󰋚 CRONOLOGIA COMMIT GIT  (I 5 commit più recenti)", "ProjectsName")

    local visible_commits = math.min(5, #commits)
    if visible_commits > 0 then
      for i = 1, visible_commits do
        add_commit_row(commits[i], branch_str, pw - 4)
      end

      if #commits > 5 then
        local c_more = string.format("   ... altri %d commit (Premi c per la cronologia completa)", #commits - 5)
        add(c_more, "ProjectsMeta")
        local l_idx = #lines - 1
        local c_pos = c_more:find("Premi c")
        if c_pos then
          hls[#hls + 1] = { l_idx, c_pos + 6, c_pos + 7, "ProjectsKeyText" }
        end
      end
    else
      add("   (nessun commit git nel repository)", "ProjectsDesc")
    end

    -- Boxed Post-It Card in Bottom 1/3
    add("")
    local max_box_dw = pw - 4
    local top_head = "  ┌─ 󰠮 NOTE & APPUNTI "
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

      if txt:find("Premi n") then
        local k_start = line_str:find("Premi n")
        if k_start then
          hls[#hls + 1] = { r_idx, k_start + 6, k_start + 7, "ProjectsKeyText" }
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
        "󰠮 Nessuna nota memorizzata per questo progetto.",
        "Gli appunti sono locali e non occupano spazio nel repository.",
        "",
        "Premi n per aggiungere un appunto",
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
      local stats_str = w_cnt .. " parole  •  " .. c_cnt .. " caratteri"
      add_box_row(stats_str, "ProjectsMeta", true)
    end

    for _ = 1, bot_pad do
      add_box_row("", "ProjectsDesc", true)
    end

    local bot_fill = math.max(0, max_box_dw - 4)
    local bot_border = "  └" .. string.rep("─", bot_fill) .. "┘"
    add(bot_border, "ProjectsName")
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

  local gh_url = P.get_github_url(p.path)
  local has_git = p.git and not p.git.none

  local footer_preview = {
    { " Note ", "ProjectsLazyBtnLabel" },
    { " n ", "ProjectsLazyBtnKey" },
  }

  if has_git then
    footer_preview[#footer_preview + 1] = { "  ", "NormalFloat" }
    footer_preview[#footer_preview + 1] = { " Commit ", "ProjectsLazyBtnLabel" }
    footer_preview[#footer_preview + 1] = { " c ", "ProjectsLazyBtnKey" }
  end

  footer_preview[#footer_preview + 1] = { "  ", "NormalFloat" }
  footer_preview[#footer_preview + 1] = { " README ", "ProjectsLazyBtnLabel" }
  footer_preview[#footer_preview + 1] = { " s ", "ProjectsLazyBtnKey" }

  if gh_url and gh_url ~= "" then
    footer_preview[#footer_preview + 1] = { "  ", "NormalFloat" }
    footer_preview[#footer_preview + 1] = { " 󰊤 GitHub ", "ProjectsLazyBtnLabel" }
    footer_preview[#footer_preview + 1] = { " g ", "ProjectsLazyBtnKey" }
  end

  if p.is_missing then
    footer_preview[#footer_preview + 1] = { "  ", "NormalFloat" }
    footer_preview[#footer_preview + 1] = { " Riconnetti ", "ProjectsLazyBtnLabel" }
    footer_preview[#footer_preview + 1] = { " r ", "ProjectsLazyBtnKey" }
  end

  footer_preview[#footer_preview + 1] = { "  ", "NormalFloat" }
  footer_preview[#footer_preview + 1] = { " 󰩹 Rimuovi ", "ProjectsLazyBtnLabel" }
  footer_preview[#footer_preview + 1] = { " d ", "ProjectsLazyBtnKey" }

  pcall(vim.api.nvim_win_set_config, st.preview.win, {
    title = { { " \u{e66a} " .. (st.show_all_commits and "cronologia commit" or "informazioni") .. " ", "ProjectsTitleSpecial" } },
    title_pos = "right",
    footer = footer_preview,
    footer_pos = "center",
  })
  pcall(vim.api.nvim_win_set_cursor, st.preview.win, { 1, 0 })
  render_preview_scrollbar(st)
end

render_preview = function(st)
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
      add("  󰋜 RICONNESSIONE PROGETTO: " .. relocate_p.name, "ProjectsTitleSpecial")
      add("   Vecchio percorso:  " .. relocate_p.path, "ProjectsMissingPathPlain")
      add("   Nuovo percorso:    " .. target_path, "ProjectsDir")
    else
      add("  󰋜 ISPETTORE CARTELLA", "ProjectsTitleSpecial")
      add("   Percorso: " .. target_path, "ProjectsDir")
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
    if not sel_name or sel_name == "" or sel_name == "/" then sel_name = "cartella" end

    local pw = vim.api.nvim_win_is_valid(st.preview.win) and vim.api.nvim_win_get_width(st.preview.win) or 50
    local ph = vim.api.nvim_win_is_valid(st.preview.win) and vim.api.nvim_win_get_height(st.preview.win) or 20

    add("   󰉏 Sotto-cartelle:  " .. fmt_num(sub_dirs_cnt) .. " cartelle", "ProjectsGitBranch")
    add("   󰈙 File Contenuti:  " .. fmt_num(files_cnt) .. " file", "ProjectsGitBranch")
    -- Vertical centering for Callout Box inside preview panel
    local cur_cnt = #lines
    local top_pad_lines = math.max(2, math.floor((ph - cur_cnt - 3) / 2))
    for _ = 1, top_pad_lines do add("") end

    local is_already = P.is_project(target_path)

    local raw_inner
    if is_already then
      raw_inner = "󰄬 '" .. sel_name .. "' È GIÀ UN PROGETTO REGISTRATO"
    elseif relocate_p then
      raw_inner = "󰏔 PREMI  a  PER RICONNETTERE '" .. relocate_p.name .. "' QUI"
    else
      raw_inner = "󰏔 PREMI  a  PER AGGIUNGERE '" .. sel_name .. "' COME PROGETTO"
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
    pcall(vim.api.nvim_win_set_config, st.preview.win, { title = "" })
    return
  end
  if st.inspector_mode then
    render_inspector(st)
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

    local art = {
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

    local top_pad = math.max(1, math.floor((ph - #art) / 2))
    local p_lines = {}
    local p_hls = {}

    for _ = 1, top_pad do p_lines[#p_lines + 1] = "" end

    for _, art_line in ipairs(art) do
      local pad_left = string.rep(" ", math.max(0, math.floor((pw - dw(art_line)) / 2)))
      p_lines[#p_lines + 1] = pad_left .. art_line
      local line_idx = #p_lines - 1
      p_hls[#p_hls + 1] = { line_idx, #pad_left, #pad_left + #art_line, "ProjectsDesc" }
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, p_lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for _, h in ipairs(p_hls) do
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, h[1], h[2], { end_col = h[3], hl_group = h[4] })
    end
    vim.api.nvim_win_set_buf(st.preview.win, buf)
    pcall(vim.api.nvim_win_set_config, st.preview.win, { title = "", title_pos = "right" })
    render_preview_scrollbar(st)
    return
  end

  local p = st.items[st.sel]
  if not (p and vim.api.nvim_win_is_valid(st.preview.win)) then return end

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

    local desc_lines = wrap_text(
      "La cartella di questo progetto non è più presente nella posizione originale memorizzata su disco.",
      text_w
    )
    local path_lines = wrap_text(p.path, text_w)

    local key_r = { { " r ", "ProjectsMissingKeyBadge" }, { " Riconnetti", "ProjectsMissingBtnLabel" } }
    local key_d = { { " d ", "ProjectsMissingKeyBadge" }, { " Rimuovi traccia", "ProjectsMissingBtnLabel" } }
    local key_w = dw(" ") -- gap tra i due badge
    for _, c in ipairs(key_r) do key_w = key_w + dw(c[1]) end
    for _, c in ipairs(key_d) do key_w = key_w + dw(c[1]) end
    local key_rows = key_w <= text_w and 1 or 2

    local body_rows = 2 + #path_lines + 1 + #desc_lines + 2 + key_rows
    local top_pad = math.max(1, math.floor((ph - body_rows) / 2))
    for _ = 1, top_pad do lines[#lines + 1] = "" end

    centered_text("⚠ PROGETTO ELIMINATO O SPOSTATO", "ProjectsMissingMsg")
    lines[#lines + 1] = ""
    for _, l in ipairs(path_lines) do centered_text(l, "ProjectsMissingPathPlain") end
    lines[#lines + 1] = ""
    for _, l in ipairs(desc_lines) do centered_text(l, "ProjectsMissingHint") end
    lines[#lines + 1] = ""
    centered_text("premi i seguenti tasti:", "ProjectsMissingHint")

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

  local readme = P.readme_path(p.path)
  local title = "albero"
  local buf

  local w = st.preview.win
  if vim.api.nvim_win_is_valid(w) then
    pcall(vim.api.nvim_set_option_value, "spell", false, { win = w })
    pcall(vim.api.nvim_set_option_value, "number", false, { win = w })
    pcall(vim.api.nvim_set_option_value, "wrap", true, { win = w })
    pcall(vim.api.nvim_set_option_value, "linebreak", true, { win = w })
    pcall(vim.api.nvim_set_option_value, "conceallevel", readme and 3 or 0, { win = w })
    pcall(vim.api.nvim_set_option_value, "concealcursor", "nvic", { win = w })
  end

  if readme then
    if not (st.preview.buf and vim.api.nvim_buf_is_valid(st.preview.buf)) then
      st.preview.buf = vim.api.nvim_create_buf(false, true)
    end
    buf = st.preview.buf
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

    vim.api.nvim_win_set_buf(st.preview.win, buf)
    pcall(vim.api.nvim_set_option_value, "conceallevel", 3, { win = st.preview.win })
    pcall(vim.api.nvim_set_option_value, "concealcursor", "nvic", { win = st.preview.win })
    pcall(vim.api.nvim_set_option_value, "spell", false, { win = st.preview.win })

    st.preview.shown = buf
    title = vim.fn.fnamemodify(readme, ":t")

    conceal_html_tags(buf)

    local ok_rm_ui, rm_ui = pcall(require, "render-markdown.core.ui")
    if ok_rm_ui and rm_ui.update then
      pcall(rm_ui.update, buf, st.preview.win)
    end
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

  pcall(vim.api.nvim_win_set_config, st.preview.win, { title = { { " " .. title .. " ", "ProjectsName" } }, title_pos = "right" })
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

render_list = function(st)
  local w = st.list.width
  local cols = w >= (M.config.min_card * 2 + 2) and 2 or 1
  local cw = math.floor((w - (cols - 1) * 2) / cols)
  st.cols, st.card_width = cols, cw

  local lines, hls, pos, rows = {}, {}, {}, {}

  local function push(text, chunk_hls)
    lines[#lines + 1] = text
    for _, h in ipairs(chunk_hls or {}) do
      hls[#hls + 1] = { #lines - 1, h[1], h[2], h[3], priority = 200 }
    end
  end

  local function divider(label)
    local text, lhls = join({
      { "── ", "ProjectsMeta" },
      { label, "ProjectsGitBranch" },
      { " " .. string.rep("─", math.max(0, w - 5 - dw(label))), "ProjectsMeta" },
    })
    push("")
    push(text, lhls)
    push("")
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
        st.dir_entries[#st.dir_entries + 1] = { type = "dir", name = s, full = curr_dir .. "/" .. s }
      end
    end
    st.dir_sel = math.max(1, math.min(#st.dir_entries, st.dir_sel or 1))

    local count_label = query ~= "" and ("%d/%d filtrate"):format(#st.dir_entries - 1, #subdirs) or tostring(#subdirs)
    if st.dir_picker_relocate then
      divider("󰛒 riconnetti '" .. st.dir_picker_relocate.name .. "' (" .. count_label .. ")")
    else
      divider("󰋜 sfoglia cartelle (" .. count_label .. ")")
    end

    for idx, item in ipairs(st.dir_entries) do
      local is_sel = (idx == st.dir_sel)
      local is_already = (item.type == "dir") and P.is_project(item.full)
      local content = (item.type == "up") and "󰁝 .. (Cartella Superiore)" or (" " .. item.name)
      local badge = is_already and "  󰄬 [GIÀ REGISTRATO]" or ""

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
          and (" 󰛒 Riconnetti '" .. st.dir_picker_relocate.name .. "'  " .. curr_dir .. " ")
        or (" 󰋜 Sfoglia Cartelle  " .. curr_dir .. " "),
      title_pos = "left",
    })

    local footer_chunks = {
      { " Naviga ", "ProjectsLazyBtnLabel" },
      { " Frecce ", "ProjectsLazyBtnKey" },
      { "  ", "NormalFloat" },
      { " Entra ", "ProjectsLazyBtnLabel" },
      { " Enter ", "ProjectsLazyBtnKey" },
      { "  ", "NormalFloat" },
      { " Indietro ", "ProjectsLazyBtnLabel" },
      { " Backspace ", "ProjectsLazyBtnKey" },
      { "  ", "NormalFloat" },
      st.dir_picker_relocate and { " Riconnetti Qui ", "ProjectsLazyBtnLabel" } or { " Aggiungi Progetto ", "ProjectsLazyBtnLabel" },
      { " a ", "ProjectsLazyBtnKey" },
      { "  ", "NormalFloat" },
      { " Esci ", "ProjectsLazyBtnLabel" },
      { " Esc ", "ProjectsLazyBtnKey" },
    }

    pcall(vim.api.nvim_win_set_config, st.list.win, {
      footer = footer_chunks,
      footer_pos = "center",
    })
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
      if group == 1 and recents_n > 0 then
        divider(("󰋚 recenti (%d)"):format(recents_n))
      elseif group == 2 and mine_n > 0 then
        divider(("i tuoi progetti (%d)"):format(mine_n))
      elseif group == 3 and others_n > 0 then
        divider(("altri progetti (%d)"):format(others_n))
      end
    end

    local built, placed = {}, 0
    for c = 0, cols - 1 do
      local idx = i + c
      if st.items[idx] and item_group(st.items[idx]) == group then
        built[c + 1] = card(st.items[idx], cw, idx == st.sel)
        pos[idx] = #lines + 1
        placed = placed + 1
      end
    end
    for r = 1, CARD_ROWS do
      local chunks = {}
      for c = 1, cols do
        if built[c] then
          if c > 1 then chunks[#chunks + 1] = { "  " } end
          vim.list_extend(chunks, built[c][r])
        end
      end
      local text, lhls = join(chunks)
      push(text, lhls)
      rows[#lines] = i
    end
    push("")
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
        local info = LANG_TOKENS[w_str:lower()]
        local hl = info and info.hl or "ProjectsName"
        local label = info and info.name or w_str
        if #tags_chunks > 0 then tags_chunks[#tags_chunks + 1] = { "  " } end
        tags_chunks[#tags_chunks + 1] = { label, hl }
      end
    end

    local title_text = "Nessun progetto trovato"
    local pad_title = string.rep(" ", math.max(0, math.floor((w - dw(title_text)) / 2)))
    push(pad_title .. title_text, { { #pad_title, #pad_title + #title_text, "ProjectsNameSel" } })

    if #tags_chunks > 0 then
      push("")
      local sub_text = "con i seguenti tag:"
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

  st.pos, st.rows = pos, rows
  ensure_visible(st)

  local title_text = (" ❯ progetti  %d/%d "):format(#st.items, #st.all)
  if st.filter_query and st.filter_query ~= "" then
    title_text = (" ❯ progetti  %s  %d/%d "):format(st.filter_query, #st.items, #st.all)
  end

  pcall(vim.api.nvim_win_set_config, st.input.win, {
    title = title_text,
    title_pos = "left",
  })

  local footer_chunks = {
    { " Ispettore ", "ProjectsLazyBtnLabel" },
    { " s ", "ProjectsLazyBtnKey" },
    { "  ", "NormalFloat" },
    { " Aggiungi ", "ProjectsLazyBtnLabel" },
    { " a ", "ProjectsLazyBtnKey" },
    { "  ", "NormalFloat" },
    { " Note ", "ProjectsLazyBtnLabel" },
    { " n ", "ProjectsLazyBtnKey" },
    { "  ", "NormalFloat" },
    { " Cerca ", "ProjectsLazyBtnLabel" },
    { " / ", "ProjectsLazyBtnKey" },
    { "  ", "NormalFloat" },
    { " Naviga ", "ProjectsLazyBtnLabel" },
    { " Tab ", "ProjectsLazyBtnKey" },
    { "  ", "NormalFloat" },
    { " Apri ", "ProjectsLazyBtnLabel" },
    { " Enter ", "ProjectsLazyBtnKey" },
  }

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
  st.sel = math.min(#st.items, math.max(1, st.sel + delta))
  refresh(st)
end

filter = function(st)
  local q = vim.api.nvim_buf_get_lines(st.input.buf, 0, 1, false)[1] or ""
  st.filter_query = q
  highlight_input_languages(st)

  local trimmed = vim.trim(q)
  if trimmed == "" then
    st.items = st.all
  else
    local words = vim.split(trimmed, "%s+")
    local lang_specs = {}
    local text_words = {}

    for _, w in ipairs(words) do
      local info = LANG_TOKENS[w:lower()]
      if info then
        lang_specs[#lang_specs + 1] = info.name:lower()
      else
        text_words[#text_words + 1] = w:lower()
      end
    end

    local text_q = table.concat(text_words, " ")

    local scored_matches = {}
    for _, it in ipairs(st.all) do
      local matches_langs = true
      if #lang_specs > 0 then
        local p_search = (it.search or ""):lower()
        for _, req_lang in ipairs(lang_specs) do
          if not p_search:find(vim.pesc(req_lang)) then
            matches_langs = false
            break
          end
        end
      end

      if matches_langs then
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
  if #all == 0 then
    vim.notify("Nessun progetto trovato: controlla 'roots' ed 'extra' passati a require('projecthub').setup({...})", vim.log.levels.WARN)
    return
  end

  local TW = math.floor(vim.o.columns * M.config.width)
  local TH = math.floor((vim.o.lines - 2) * M.config.height)
  local SC = math.floor((vim.o.columns - TW) / 2)
  local SR = math.floor((vim.o.lines - TH) / 2)
  local LWf = math.floor(TW * M.config.left_ratio)
  local LW, RW = LWf - 2, TW - LWf - 2

  local st = { all = all, items = all, sel = 1 }

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
    title = " anteprima ",
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
    if vim.api.nvim_win_is_valid(backdrop_win) then
      pcall(vim.api.nvim_win_close, backdrop_win, true)
    end
    if st.list and vim.api.nvim_win_is_valid(st.list.sb_win) then
      pcall(vim.api.nvim_win_close, st.list.sb_win, true)
    end
    if st.preview and vim.api.nvim_win_is_valid(st.preview.sb_win) then
      pcall(vim.api.nvim_win_close, st.preview.sb_win, true)
    end
    for _, k in ipairs({ "input", "list", "preview" }) do
      if st[k] and vim.api.nvim_win_is_valid(st[k].win) then
        pcall(vim.api.nvim_win_close, st[k].win, true)
      end
    end
  end
  st.close = close

  local function open_sel(idx)
    local p = st.items[idx or st.sel]
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
  map(all_bufs, { "i", "n" }, { "<Right>", "<Tab>" }, move_right)
  map(nav_bufs, "i", { "l" }, move_right)
  map(all_bufs, { "i", "n" }, { "<Left>", "<S-Tab>", "<BS>" }, move_left)
  map(nav_bufs, "i", { "h" }, move_left)
  map(all_bufs, { "i", "n" }, { "<PageDown>" }, function() move(st, st.cols * 3) end)
  map(all_bufs, { "i", "n" }, { "<PageUp>" }, function() move(st, -st.cols * 3) end)
  map(all_bufs, { "i", "n" }, { "<C-f>" }, function() scroll_preview(st, 10) end)
  map(all_bufs, { "i", "n" }, { "<C-b>" }, function() scroll_preview(st, -10) end)
  map(all_bufs, { "i", "n" }, { "<C-r>" }, function()
    P.load_git(st.all, function() render_list(st) end, true)
  end)

  map(all_bufs, "n", { "s" }, function()
    st.inspector_mode = not st.inspector_mode
    st.show_all_commits = false
    refresh(st)
  end)

  map(all_bufs, "n", { "c" }, function()
    st.inspector_mode = true
    st.show_all_commits = not st.show_all_commits
    refresh(st)
  end)

  map(all_bufs, "n", { "g" }, function()
    local p = st.items[st.sel]
    if p then
      local gh_url = P.get_github_url(p.path)
      if gh_url and gh_url ~= "" then
        vim.notify("󰖟 Apertura " .. gh_url .. " nel browser...", vim.log.levels.INFO)
        if vim.ui and vim.ui.open then
          vim.ui.open(gh_url)
        else
          vim.fn.jobstart({ "open", gh_url }, { detach = true })
        end
      else
        vim.notify("󰅖 Questo progetto non ha un repository GitHub collegato", vim.log.levels.WARN)
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
          vim.notify("󰄬 Già Registrato\n'" .. vim.fn.fnamemodify(target_path, ":t") .. "' è già presente nei tuoi progetti.\nScegli un'altra cartella.", vim.log.levels.WARN)
          return
        else
          P.remove_custom_extra(old_p.path)
          P.remove_recent(old_p.path)

          local ok, title, reason = P.add_custom_extra(target_path)
          if ok then
            P.add_recent(target_path)
            vim.notify("󰄬 Progetto Riconnesso Con Successo!\nIl nuovo percorso di '" .. old_p.name .. "' è:\n" .. target_path, vim.log.levels.INFO)
          else
            vim.notify("󰅖 Riconnessione Fallita: " .. title .. "\nMotivo: " .. reason, vim.log.levels.ERROR)
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

      local ok, title, reason = P.add_custom_extra(target_path)
      if ok then
        P.add_recent(target_path)
        vim.notify("󰄬 " .. title .. "\n" .. reason, vim.log.levels.INFO)
      else
        if title == "Già Registrato" then
          vim.notify("󰄬 " .. title .. "\n" .. reason, vim.log.levels.WARN)
        else
          vim.notify("󰅖 Operazione Fallita: " .. title .. "\nMotivo: " .. reason, vim.log.levels.ERROR)
        end
      end

      st.dir_picker_mode = false
      st.all = P.list(true)
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
      vim.notify("󰄬 Progetto Rimosso\nIl riferimento a '" .. p.name .. "' è stato eliminato con successo dai tuoi progetti.", vim.log.levels.INFO)
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

  local function prompt_note()
    local p = st.items[st.sel]
    if not p then return end
    local current_note = P.get_note(p.path)

    st.inspector_mode = true
    refresh(st)

    vim.ui.input({
      prompt = " 󰠮 Nota per " .. p.name .. ": ",
      default = current_note,
    }, function(input)
      if input ~= nil and vim.trim(input) ~= "" then
        P.save_note(p.path, vim.trim(input))
        vim.notify("󰄬 Nota per '" .. p.name .. "' salvata con successo!", vim.log.levels.INFO)
      elseif input == "" then
        P.save_note(p.path, "")
        vim.notify("󰅖 Nota per '" .. p.name .. "' rimossa", vim.log.levels.WARN)
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

  map(all_bufs, "n", { "/", "f", "i" }, function()
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
        local max_content = 1
        if st.pos then
          for _, lnum in pairs(st.pos) do
            if lnum + CARD_ROWS - 1 > max_content then
              max_content = lnum + CARD_ROWS - 1
            end
          end
        end
        if max_content > h then
          local ratio = (m.winrow - 1) / math.max(1, h - 1)
          local target_top = math.floor(ratio * (max_content - h)) + 1
          target_top = math.max(1, math.min(max_content - h + 1, target_top))
          vim.api.nvim_win_call(st.list.win, function()
            vim.fn.winrestview({ topline = target_top })
          end)
          render_scrollbar(st)
          return
        end
      end

      local idx = card_at_mouse(st)
      if idx and idx ~= st.sel then
        st.sel = idx
        refresh(st)
      end
    elseif m.winid == st.preview.win or m.winid == st.preview.sb_win then
      local pw = vim.api.nvim_win_get_width(st.preview.win)
      local ph = vim.api.nvim_win_get_height(st.preview.win)
      local pbuf = vim.api.nvim_win_get_buf(st.preview.win)
      local total_lines = vim.api.nvim_buf_line_count(pbuf)
      if (m.winid == st.preview.sb_win or m.wincol >= pw - 1 or m.wincol <= 0) and total_lines > ph then
        local ratio = (m.winrow - 1) / math.max(1, ph - 1)
        local target_top = math.floor(ratio * (total_lines - ph)) + 1
        target_top = math.max(1, math.min(total_lines - ph + 1, target_top))
        vim.api.nvim_win_call(st.preview.win, function()
          vim.fn.winrestview({ topline = target_top, lnum = target_top, leftcol = 0 })
        end)
        render_preview_scrollbar(st)
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

  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    buffer = st.input.buf,
    callback = function() filter(st) end,
  })

  local grp = vim.api.nvim_create_augroup("CustomProjects", { clear = true })
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

  -- Caricamento Asincrono non bloccante 1: Stato Git
  P.load_git(st.all, function()
    if not closed then reapply(st) end
  end)

  -- Caricamento Asincrono non bloccante 2 (O(N) Lazy): Percentuali dei Linguaggi
  P.load_languages(st.all, function()
    if not closed then render_list(st) end
  end)

  return st
end

return M
