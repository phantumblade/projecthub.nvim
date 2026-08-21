# projecthub.nvim

A fast, visual project dashboard for Neovim. Scans the folders where you keep
your repos, shows them as cards with git status, language breakdown and
GitHub metadata, and lets you jump into any of them in a couple of
keystrokes — with a built-in fix-up flow for projects you moved or renamed
on disk.

![overview](screenshots/overview.png)

## Features

- **Recent + all projects**, grouped and sorted, with a live fuzzy/tag search
  bar (type a language name like `python` or `swift` to filter by it).
- **Project cards**: git branch, dirty/staged/untracked/ahead/behind counts,
  language bar with percentages, last-modified time.
- **Inspector panel**: lines of code, file count, full commit history with
  conventional-commit tags, contributor breakdown, GitHub stars/forks/
  visibility (via `gh`), and a per-project notes pad.
- **Add a project** by browsing folders from inside the dashboard.
- **Missing-project recovery**: if a tracked project's folder was moved,
  renamed or deleted, its card turns red. Reconnect it to its new location
  using the same folder browser (works even if the folder was renamed), or
  untrack it — all without leaving Neovim.
- **README preview** (with `render-markdown.nvim` if installed) or a file
  tree when there's no README.
- **Italian / English UI**, switchable live from inside the dashboard (`L`)
  or fixed via the `language` option.
- Mouse support, scrollbars, responsive single/two-column layout.

| | |
|---|---|
| ![search](screenshots/search-filter.png) | ![inspector](screenshots/inspector.png) |
| ![add project](screenshots/add-project.png) | ![commit history](screenshots/commit-history.png) |

## Requirements

- Neovim >= 0.10
- [git](https://git-scm.com/) on your `$PATH`
- A [Nerd Font](https://www.nerdfonts.com/) for the icons

Optional, used if present (everything degrades gracefully without them):

- [`gh`](https://cli.github.com/) — GitHub stars/forks/visibility/owner in the inspector
- [folke/snacks.nvim](https://github.com/folke/snacks.nvim) — to add a dashboard entry that opens projecthub
- [echasnovski/mini.icons](https://github.com/echasnovski/mini.icons) — file/folder icons in the tree preview
- [MeanderingProgrammer/render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) — rendered README preview
- [folke/persistence.nvim](https://github.com/folke/persistence.nvim) — restores your last session when you open a project

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "phantumblade/projecthub.nvim",
  keys = {
    { "<leader>fp", function() require("projecthub").open() end, desc = "Projects" },
  },
  opts = {
    -- container folders to scan: { path, scan_depth }
    roots = {
      { "~/Projects", 1 },
      { "~/Work", 2 },
    },
    -- individual project folders outside the roots above
    extra = {
      "~/.config/nvim",
    },
    -- your GitHub usernames, to tell "mine" apart from cloned repos
    me = {
      owners = { "your-github-username" },
    },
  },
}
```

Nothing is scanned until you open the dashboard, so `opts` alone is enough —
no explicit `setup()` call needed with lazy.nvim's `opts` field.

## Configuration

Defaults (everything is optional):

```lua
require("projecthub").setup({
  language = "en", -- "en" or "it" — switch anytime with the L key, or
                    -- require("projecthub").set_language("it"|"en")
  roots = {},   -- { { "~/Projects", depth }, ... }
  extra = {},   -- { "~/some/single/project", ... }
  me = {
    owners = {}, -- GitHub usernames considered "yours"
  },
  icons = {
    owner = "\u{edeb} ",  -- crown, shown next to the repo owner
    org = "\u{f42b} ",    -- shown next to an organization
    member = "\u{f0009} ", -- shown next to other contributors
    fork = "\u{ea63} ",   -- shown next to the fork count
  },
  window = {
    width = 0.90,
    height = 0.85,
    left_ratio = 0.48, -- card list vs preview panel split
    min_card = 34,      -- below this width, cards stack in a single column
  },
  -- Called with the absolute path when you open a project (<CR>). If nil,
  -- the default is: `:tcd` into it, then restore the session with
  -- persistence.nvim if there is one, otherwise open Neo-tree.
  on_open = nil,
})
```

Projects you add from inside the dashboard, your notes, and your recents
list are stored as JSON under `stdpath("data") .. "/projecthub/"` — nothing
touches your dotfiles.

## Keymaps (inside the dashboard)

| Key | Action |
|---|---|
| `↑↓←→` / `hjkl` / `Tab` `S-Tab` | move between cards |
| `Enter` | open the selected project |
| `/` | focus the search bar |
| `a` | add a project (browse folders) / confirm in the folder browser |
| `r` | reconnect a missing project to a new location (browse folders) |
| `d` | untrack the selected project |
| `s` | toggle the inspector panel |
| `n` / `e` | edit the project's note |
| `c` | expand/collapse full commit history |
| `g` | open the project on GitHub |
| `L` | switch the UI language (Italian ⇄ English) |
| `q` / `Esc` | close (or cancel the folder browser) |

## License

[MIT](LICENSE)
