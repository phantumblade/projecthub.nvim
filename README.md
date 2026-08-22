# 🚀 projecthub.nvim

<p align="center">
  <strong>A fast, aesthetic, and visual project dashboard & switcher for Neovim.</strong>
</p>

<p align="center">
  <a href="https://neovim.io"><img src="https://img.shields.io/badge/Neovim-0.10+-57A143?logo=neovim&logoColor=white&style=flat-square" alt="Neovim 0.10+" /></a>
  <a href="https://www.lua.org"><img src="https://img.shields.io/badge/Lua-5.1%20%2F%20LuaJIT-000080?logo=lua&logoColor=white&style=flat-square" alt="Lua" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square" alt="License: MIT" /></a>
  <img src="https://img.shields.io/badge/i18n-English%20%7C%20Italian-purple?style=flat-square" alt="i18n: EN & IT" />
</p>

---

**`projecthub.nvim`** automatically scans the directories where you keep your code, presenting them as rich, interactive project cards. It displays real-time Git status, language breakdown progress bars, disk lines-of-code statistics, GitHub metadata, and lets you jump directly into any project with **Neo-tree** and `README.md` ready in a single keystroke.

![ProjectHub Demo](screenshots/demo.gif)

---

## ✨ Features

- ⚡ **Zero-Latency Startup & Scanning**: Background asynchronous parsing keeps your Neovim snappy without lag or UI freezes.
- 📊 **Rich Project Cards**:
  - **Language Breakdown**: Multi-color visual progress bars with animated legend marquee.
  - **Git Status**: Real-time branch, commit counts, ahead/behind sync status, and dirty/staged/untracked indicators.
  - **Metadata**: Folder path, project type badge, and human-readable last-modified time.
- 🔍 **Smart Live Filtering & Search Tokens**:
  - **Fuzzy Text Search**: Matches project name, folder path, and description.
  - **Language Tokens**: Type `lua`, `python`, `typescript`, `rust`, `go`, `kotlin`, `java`, `swift`, etc. to filter dynamically.
  - **Visibility Tags**: Type `PUBBLICO` (`PUBLIC`), `PRIVATO` (`PRIVATE`), or `LOCALE` (`LOCAL`, `untracked`) for instant classification.
- 🔎 **Deep Inspector Panel**:
  - **Codebase Stats**: Asynchronous Lines-of-Code (LOC) calculator and total project file counter.
  - **Conventional Commits Tagging**: Automatic badges for `[FEAT]`, `[FIX]`, `[CHANGE]`, `[DOCS]`, `[CHORE]`, `[REFACTOR]`.
  - **Infinite Scroll Git History (`c`)**: Auto-loads +100 commits dynamically as you scroll to browse repositories with hundreds of commits.
  - **Team & Collaborators**: Highlights contributors with role-based badges (`👑` Repo Owner, `🏢` Organization, `👤` Team Member).
- 🌐 **Persistent GitHub Cache**: Authenticated `gh api` queries retrieve stars, forks, visibility, and parent forks with instant `0ms` startup cache saved to disk.
- 📁 **Interactive Folder Browser (`a`)**: Add new projects directly from an in-editor file browser with duplicate detection.
- 🛠️ **Missing Project Self-Healing (`r` / `d`)**: Moved or renamed project folders are highlighted in red, allowing you to reconnect them in 1-click or untrack them.
- 📝 **Scratchpad Notes (`n`)**: Dedicated per-project persistent notes editor saved locally on disk.
- 📖 **README & Web Previews**: Embedded Markdown preview (`s`) or 1-click browser preview for web projects (`w`).
- 🌐 **Bilingual (English / Italian)**: Toggle UI language on the fly anytime (`L`) or configure statically.
- 🖱️ **Full Mouse & Keyboard Support**: Smooth scrolling with wheel, scrollbar dragging, and responsive single/two-column layouts.

---

## 📸 Screenshots Showcase

| 🗂️ Project Cards Overview | 🔍 Language & Tag Search |
|:---:|:---:|
| ![Project Overview](screenshots/overview.png) | ![Search & Filter](screenshots/search-filter.png) |

| 📜 Infinite-Scroll Commit History (`c`) | 📖 Markdown README Preview (`s`) |
|:---:|:---:|
| ![Commit History](screenshots/commit-history.png) | ![README Preview](screenshots/readme-preview.png) |

| 📁 Interactive Folder Browser (`a`) | 📝 Scratchpad Notes (`n`) |
|:---:|:---:|
| ![Folder Browser](screenshots/add-project.png) | ![Notes](screenshots/notes.png) |

| 🏷️ Smart Empty State with Tags | 🔎 Deep Inspector & Git Stats |
|:---:|:---:|
| ![Empty State](screenshots/empty-search.png) | ![Inspector](screenshots/inspector.png) |

---

## 📦 Requirements

- **Neovim >= 0.10**
- **[git](https://git-scm.com/)** installed and available on your `$PATH`
- A **[Nerd Font](https://www.nerdfonts.com/)** for icons

### Optional Integrations (Graceful Fallback)
- **[`gh` (GitHub CLI)](https://cli.github.com/)**: Enables authenticated GitHub metadata (stars, forks, visibility).
- **[`nvim-neo-tree/neo-tree.nvim`](https://github.com/nvim-neo-tree/neo-tree.nvim)**: Automatically opened on the left when opening a project.
- **[`folke/snacks.nvim`](https://github.com/folke/snacks.nvim)**: For Snacks dashboard entry & snacks explorer fallback.
- **[`echasnovski/mini.icons`](https://github.com/echasnovski/mini.icons)**: Enhanced file/folder icons in tree views.
- **[`MeanderingProgrammer/render-markdown.nvim`](https://github.com/MeanderingProgrammer/render-markdown.nvim)**: Formatted Markdown rendering in README preview.

---

## 🚀 Installation

### With [lazy.nvim](https://github.com/folke/lazy.nvim) (Recommended)

```lua
{
  "phantumblade/projecthub.nvim",
  keys = {
    { "<leader>p", function() require("projecthub").open() end, desc = "Projects Dashboard" },
  },
  opts = {
    language = "en", -- "en" or "it" (switchable live anytime with 'L')
    -- Directories to scan: { path, scan_depth }
    roots = {
      { "~/Projects", 1 },
      { "~/Work", 2 },
      { "~/AndroidStudioProjects", 1 },
    },
    -- Individual projects outside the root directories above
    extra = {
      "~/.config/nvim",
      "~/my-special-project",
    },
    -- Your GitHub usernames (used to highlight owner badges & your repos)
    me = {
      owners = { "your-github-username" },
    },
  },
}
```

### With [pckr.nvim](https://github.com/lewis6991/pckr.nvim) / [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use({
  "phantumblade/projecthub.nvim",
  config = function()
    require("projecthub").setup({
      roots = { { "~/Projects", 1 } },
      extra = { "~/.config/nvim" },
    })
  end,
})
```

---

## ⚙️ Configuration Reference

All settings are optional with sensible defaults:

```lua
require("projecthub").setup({
  -- Default interface language: "en" (English) or "it" (Italian)
  -- You can also switch languages on the fly inside the dashboard by pressing 'L'
  language = "en",

  -- Folders to automatically scan: { path, search_depth }
  roots = {
    { "~/Projects", 1 },
    { "~/Personale/Progetti_Personali", 1 },
  },

  -- Standalone project directories
  extra = {
    "~/.config/nvim",
  },

  -- User identification for owner badges and personal repository classification
  me = {
    owners = { "phantumblade" },
  },

  -- Customizable icons (Nerd Font unicode characters)
  icons = {
    owner = "👑 ",  -- Shown next to the repository owner
    org = "🏢 ",    -- Shown next to an organization
    member = "👤 ", -- Shown next to team members / contributors
    fork = "󰘬 ",   -- Shown next to fork counts
  },

  -- Floating window layout and responsiveness
  window = {
    width = 0.90,       -- Window width ratio (0.1 - 1.0)
    height = 0.85,      -- Window height ratio (0.1 - 1.0)
    left_ratio = 0.48,  -- Ratio between left list and right inspector panel
    min_card = 34,      -- Minimum card width before switching to single column
  },

  -- Custom callback executed when pressing Enter on a project.
  -- Defaults to: changing directory (`cd`), opening README.md in main buffer,
  -- and opening Neo-tree on the left side.
  on_open = nil,
})
```

---

## ⌨️ Keybindings

Inside the dashboard:

| Key | Action | Description |
|:---|:---|:---|
| `↑` `↓` `←` `→` / `h` `j` `k` `l` | **Navigate** | Move selection between project cards |
| `<CR>` (`Enter`) | **Open Project** | Changes `cwd`, opens `README.md` and displays Neo-tree |
| `/` | **Search** | Focus the live search and filter input bar |
| `c` | **Commit History** | Toggle full-screen infinite-scroll commit timeline |
| `s` | **README Preview** | Toggle embedded Markdown / tree inspector preview |
| `w` | **Web Preview** | Open project `index.html` in default web browser |
| `g` | **GitHub** | Open repository URL on GitHub in default browser |
| `n` / `e` | **Notes** | Open scratchpad note editor for the selected project |
| `a` | **Add Project** | Open interactive folder browser to track a new project |
| `r` | **Reconnect** | Reconnect a missing/moved project to its new directory |
| `d` | **Untrack** | Remove project tracking from custom extras |
| `L` | **Language** | Switch UI language instantly between English and Italian |
| `q` / `<Esc>` | **Quit** | Close the dashboard or dismiss the current modal |
| `<ScrollWheel>` | **Mouse Scroll** | Scroll cards list or inspector preview with inertia |

---

## 📂 Data Storage

ProjectHub stores custom-added projects, persistent notes, recents history, and GitHub metadata cache cleanly in:
```
~/.local/share/nvim/projecthub/
  ├── custom_projects.json
  ├── github_meta.json
  ├── notes.json
  └── recents.json
```
Nothing is ever written into your dotfiles or repository folders.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/phantumblade">phantumblade</a>
</p>
