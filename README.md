# projecthub.nvim

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

**`projecthub.nvim`** scans your repository folders and displays them as rich, interactive project cards with real-time Git status, language breakdown bars, disk lines-of-code statistics, GitHub metadata, and instant project jumping with **Neo-tree** and `README.md` in one keystroke.

![ProjectHub Demo](screenshots/demo.gif)

---

## Features

- **Guided First Run**: With no projects configured yet, the dashboard opens a welcome screen offering either an automatic folder scan (`s`) or manual picking (`a`) — no config editing needed to get started.
- **Zero-Latency Startup**: Background asynchronous scanning without UI blocking.
- **Project Cards**: Language breakdown progress bars, branch, dirty/staged/untracked indicators, sync status (ahead/behind), and last modified time.
- **Smart Live Filtering**:
  - Fuzzy text search by project name, path, or description.
  - Exact language matching: `lua`, `python`, `typescript`, `rust`, `go`, `kotlin`, `java`, `swift`, `c`, `cpp`, etc.
  - Visibility tags: `PUBBLICO` (`PUBLIC`), `PRIVATO` (`PRIVATE`), `LOCALE` (`LOCAL`, `untracked`).
- **Deep Inspector Panel**:
  - Asynchronous Lines-of-Code (LOC) calculator and file counter.
  - Conventional Commits badges (`[FEAT]`, `[FIX]`, `[CHANGE]`, `[DOCS]`, `[CHORE]`, `[REFACTOR]`).
  - Infinite-scroll Git commit timeline (`c`) with automatic pagination (+100 commits).
  - Contributor breakdown with role icons (Owner, Organization, Member).
- **Persistent GitHub Cache**: Authenticated `gh api` queries retrieve stars, forks, visibility, and parent forks with instant `0ms` startup cache saved to disk.
- **Folder Browser (`a`)**: Add new projects on the fly with duplicate detection.
- **Missing Project Self-Healing (`r` / `d`)**: Highlights moved/renamed folders and offers a 1-click reconnect flow.
- **External Drive Awareness (SSD / USB)**: Projects living on removable volumes are detected and labelled with their volume name. When the drive is unplugged the card stays in the list in a *disconnected* state, showing the cached name, description, type and language breakdown instead of vanishing. Plug the drive back in and the dashboard picks it up on its own, with no manual refresh.
- **Scratchpad Notes (`n`)**: Dedicated per-project persistent notes editor.
- **README & Web Previews**: Embedded Markdown preview (`s`) or browser preview (`w`).
- **UI Sound Effects**: Subtle audio feedback on typing, selection and notifications, bundled with the plugin (no downloads, no external player to install beyond what your OS already provides). Toggle at runtime with `:ProjectHubSound`, or set `sound.enabled = false`. Volume is configurable and the choice is remembered across restarts.
- **Bilingual (EN / IT)**: Switch language at runtime (`L` / `:ProjectHubLang`) or via config.
- **Full Mouse & Keyboard Support**: Smooth scrolling with wheel, scrollbar dragging, and responsive single/two-column layouts.

---

## Screenshots

**First run** — with nothing configured yet, the dashboard explains itself and offers both routes:

![Welcome Screen](screenshots/welcome-screen.png)

| Project Cards Overview | Language & Tag Search |
|:---:|:---:|
| ![Project Overview](screenshots/overview.png) | ![Search & Filter](screenshots/search-filter.png) |

| Infinite-Scroll Commit History (`c`) | Markdown README Preview (`s`) |
|:---:|:---:|
| ![Commit History](screenshots/commit-history.png) | ![README Preview](screenshots/readme-preview.png) |

| Interactive Folder Browser (`a`) | Scratchpad Notes (`n`) |
|:---:|:---:|
| ![Folder Browser](screenshots/add-project.png) | ![Notes](screenshots/notes.png) |

| Smart Empty State with Tags | Deep Inspector & Git Stats |
|:---:|:---:|
| ![Empty State](screenshots/empty-search.png) | ![Inspector](screenshots/inspector.png) |

---

## Requirements

- **Neovim >= 0.10**
- **[git](https://git-scm.com/)** available on `$PATH`
- A **[Nerd Font](https://www.nerdfonts.com/)** for terminal icons

### Optional Integrations
- **[`gh` (GitHub CLI)](https://cli.github.com/)**: GitHub stars, forks, and visibility metadata.
- **An audio player, for the sound effects**: macOS already ships `afplay`, so nothing to install. On Linux any one of `pw-play`, `paplay`, `mpv` or `ffplay` is used, whichever is found first. On Windows `ffplay`, falling back to PowerShell. Without any of them the plugin simply stays silent.
- **[`nvim-neo-tree/neo-tree.nvim`](https://github.com/nvim-neo-tree/neo-tree.nvim)**: Opened automatically on the left when opening a project.
- **[`MeanderingProgrammer/render-markdown.nvim`](https://github.com/MeanderingProgrammer/render-markdown.nvim)**: Formatted Markdown preview.
- **[`folke/snacks.nvim`](https://github.com/folke/snacks.nvim)**: Dashboard button integration.
- **[`echasnovski/mini.icons`](https://github.com/echasnovski/mini.icons)**: Enhanced file/folder icons.

---

## Installation & Setup

### 1. Where to put the configuration

Create a new plugin file in your Neovim config (e.g. `~/.config/nvim/lua/plugins/projecthub.lua`):

#### With [lazy.nvim](https://github.com/folke/lazy.nvim) (Recommended)

```lua
return {
  "phantumblade/projecthub.nvim",
  cmd = { "ProjectHub", "PH", "ProjectHubLang", "PHLang" },
  keys = {
    { "<leader>p", "<cmd>ProjectHub<cr>", desc = "ProjectHub Dashboard" },
  },
  opts = {
    language = "en", -- "en" or "it" (switchable anytime with 'L' or :ProjectHubLang)
    -- Folders to scan: { path, search_depth }
    roots = {
      { "~/Projects", 1 },
      { "~/Work", 2 },
    },
    -- Individual project folders outside roots
    extra = {
      "~/.config/nvim",
    },
    -- Your GitHub/GitLab usernames (for owner badge & author filtering)
    me = {
      owners = { "your-github-username" },
    },
    -- UI Sound Effects (uisfx minimal preset)
    sound = {
      enabled = true, -- set false to disable all sounds
      volume = 0.5,   -- volume level (0.0 to 1.0)
    },
  },
}
```

#### With [pckr.nvim](https://github.com/lewis6991/pckr.nvim) / [packer.nvim](https://github.com/wbthomason/packer.nvim)

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

## How to Run ProjectHub

You can start ProjectHub using any of the following methods:

1. **User Commands**:
   - `:ProjectHub` (or `:PH`) — Open dashboard.
   - `:ProjectHubLang` (or `:PHLang`, `:PHl`) — Switch language between Italian and English.
2. **Keybinding**:
   - Press `<leader>p` (or your configured keymap).
3. **Lua API**:
   ```lua
   require("projecthub").open()
   ```
4. **Snacks Dashboard Integration** *(Optional)*:
   ```lua
   { icon = "P ", key = "p", desc = "Projects", action = ":ProjectHub" }
   ```

---

## Configuration Reference

All settings with their default values:

```lua
require("projecthub").setup({
  -- Interface language: "en" (English) or "it" (Italian)
  language = "en",

  -- Directories to automatically scan: { path, search_depth }
  roots = {},

  -- Standalone project directories
  extra = {},

  -- GitHub usernames considered "yours" (to highlight owner badges)
  me = {
    owners = {},
  },

  -- Custom icons (Nerd Font unicode characters)
  icons = {
    owner = "\u{edeb} ",  -- Crown icon (repo owner)
    org = "\u{f42b} ",    -- Organization icon
    member = "\u{f0009} ", -- Member/contributor icon
    fork = "\u{ea63} ",   -- Fork icon
  },

  -- Window layout and responsive split
  window = {
    width = 0.90,       -- Window width ratio (0.1 - 1.0)
    height = 0.85,      -- Window height ratio (0.1 - 1.0)
    left_ratio = 0.48,  -- Ratio between left list and right inspector panel
    min_card = 34,      -- Minimum card width before switching to single column
  },

  -- Sound effects (bundled out-of-the-box, zero external downloads needed)
  sound = {
    enabled = true,     -- Set to false to disable all audio feedback
    volume = 0.5,       -- Volume level (0.0 to 1.0)
  },

  -- Custom open callback. If nil, defaults to:
  -- changing cwd (`cd`), opening README.md in main buffer, and opening Neo-tree.
  on_open = nil,
})
```

---

## Commands & Keybindings

### User Commands
- `:ProjectHub` (or `:PH`) — Open the ProjectHub dashboard.
- `:ProjectHubLang [it|en]` (or `:PHLang`) — Switch interface language.
- `:ProjectHubSound` (or `:PHSound`) — Toggle UI sound effects ON / OFF.

### Dashboard Keybindings

| Key | Action | Description |
|:---|:---|:---|
| `↑` `↓` `←` `→` / `h` `j` `k` `l` | **Navigate** | Move selection between project cards |
| `<CR>` (`Enter`) | **Open Project** | Changes `cwd`, opens `README.md` and displays Neo-tree |
| `/` | **Search** | Focus the live search and filter input bar |
| `<Tab>` | **Autocomplete** | Expand grey ghost-text suggestions for languages, tags, authors |
| `c` | **Commit History** | Toggle full-screen infinite-scroll commit timeline |
| `s` | **README Preview** | Toggle embedded Markdown / tree inspector preview *(on the first-run welcome screen: scan a folder for projects)* |
| `w` | **Web Preview** | Open project `index.html` in default web browser |
| `g` | **Git Remote** | Open repository URL (GitHub / GitLab / Bitbucket) in browser |
| `n` / `e` | **Notes** | Open scratchpad note editor for the selected project |
| `a` | **Add Project** | Open interactive folder browser to track a new project |
| `r` | **Reconnect** | Reconnect a missing/moved project to its new directory |
| `d` | **Untrack** | Remove project tracking from custom extras |
| `L` | **Language** | Switch UI language instantly between English and Italian |
| `q` / `<Esc>` | **Quit** | Close the dashboard or dismiss the current modal |
| `<ScrollWheel>` | **Mouse Scroll** | Scroll cards list or inspector preview with inertia |

---

## Trying It Out Safely

To see the plugin exactly as a new user would, without touching your own
projects, notes or caches:

```bash
./scripts/try-fresh.sh
```

It starts Neovim in a throwaway sandbox (config, data, state and cache all
redirected to a temp folder), so the first-run welcome screen appears and
anything you add there is discarded. Your real data in
`~/.local/share/nvim/projecthub/` is never read or written.

Pass `--keep` to reuse the previous sandbox instead of starting clean.

---

## Data Storage

ProjectHub stores custom projects, persistent notes, recents, and Git metadata cache in:
```
~/.local/share/nvim/projecthub/
  ├── custom_projects.json
  ├── github_meta.json
  ├── notes.json
  └── recents.json
```
Nothing is ever written into your dotfiles or repository folders.

---

## Credits & Acknowledgements

- **[uisfx](https://github.com/romainsimon/uisfx)** by [Romain Simon](https://github.com/romainsimon) — For the beautiful, lightweight open-source UI sound effects library. The *Minimal* audio preset is bundled directly inside `sounds/minimal/` for instantaneous 0ms audio feedback.

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## Support

If you find `projecthub.nvim` helpful and it makes your workflow faster, consider giving it a ⭐ on GitHub!

<p align="center">
  Crafted with ❤️ in Italy 🇮🇹 by <a href="https://github.com/phantumblade"><strong>phantumblade</strong></a>
</p>
