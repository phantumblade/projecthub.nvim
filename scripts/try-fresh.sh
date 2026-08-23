#!/usr/bin/env bash
# Avvia ProjectHub in una sandbox usa-e-getta, come lo vedrebbe un utente nuovo.
#
# I dati veri (progetti aggiunti, note, cache GitHub, preferenze) vivono in
# $XDG_DATA_HOME/nvim/projecthub. Qui XDG_* punta a una cartella temporanea,
# quindi la sessione di prova non legge ne' scrive nulla di tuo.
#
#   ./scripts/try-fresh.sh          prova con questo repo
#   ./scripts/try-fresh.sh --keep   riusa la sandbox precedente
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX="${TMPDIR:-/tmp}/projecthub-sandbox"

if [[ "${1:-}" != "--keep" ]]; then
  rm -rf "$SANDBOX"
fi
mkdir -p "$SANDBOX"/{config/nvim,data,state,cache}

# Se hai un tema installato lo si riusa, cosi' l'anteprima somiglia a un setup
# reale invece del nero pieno di Neovim spoglio. I colori del plugin sono
# agganciati ai gruppi del tema attivo, quindi senza tema si vedono slavati.
THEME_DIR="${XDG_DATA_HOME_REAL:-$HOME/.local/share}/nvim/lazy"

cat > "$SANDBOX/config/nvim/init.lua" <<LUA
-- Installazione minima: solo il plugin, nessuna opzione.
-- E' il caso peggiore, quello di chi installa senza leggere il README.
vim.opt.rtp:append("$PLUGIN_DIR")

-- Tema solo per rendere l'anteprima realistica: non fa parte del plugin.
for _, t in ipairs({ "tokyonight.nvim", "catppuccin" }) do
  local dir = "$THEME_DIR/" .. t
  if vim.fn.isdirectory(dir) == 1 then
    vim.opt.rtp:append(dir)
    pcall(vim.cmd.colorscheme, (t:gsub("%..*$", "")))
    break
  end
end

require("projecthub").setup({})
vim.keymap.set("n", "<leader>p", "<cmd>ProjectHub<cr>", { desc = "ProjectHub" })
LUA

echo "Sandbox: $SANDBOX   (i tuoi dati reali non vengono toccati)"
echo "Dentro Neovim:  :ProjectHub     per uscire:  :qa"
echo

# GH_CONFIG_DIR resta quello vero: XDG_CONFIG_HOME e' rediretto per isolare la
# configurazione di Neovim, ma senza questa riga anche `gh` perderebbe le
# credenziali e stelle/fork/visibilita' non verrebbero mai caricate.
XDG_CONFIG_HOME="$SANDBOX/config" \
XDG_DATA_HOME="$SANDBOX/data" \
XDG_STATE_HOME="$SANDBOX/state" \
XDG_CACHE_HOME="$SANDBOX/cache" \
GH_CONFIG_DIR="${GH_CONFIG_DIR:-$HOME/.config/gh}" \
  nvim -c 'ProjectHub'
