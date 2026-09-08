-- =============================================================================
-- init.lua — Neovim config for the linux-rice.
--
-- IDE profile managed by lazy.nvim, colors owned by pywal16.
-- The rice's editors: Zed (GUI IDE, $EDITOR), Emacs (opt-in), and this —
-- nvim as a real terminal IDE: treesitter highlighting, LSP, completion,
-- telescope, file tree.
--
-- Editor plugin rule (this file is the rule's reference implementation):
--   * lazy.nvim is the ONLY plugin manager here, specs inline below —
--     keep this config single-file.
--   * NO colorscheme/theme plugins. Color comes exclusively from
--     ~/.cache/wal/colors-wal.vim: the sourced color0..15 drive every
--     nvim_set_hl call, and plugin UIs (cmp/telescope/nvim-tree) link
--     into those same groups so one palette owns the whole screen.
--   * NO mason: LSP servers are plain $PATH binaries installed by
--     scripts/00-base.sh (pyright, rust-analyzer, clangd, lua_ls,
--     bashls, gopls, ts_ls) and 10-aur.sh (html, cssls, jsonls, eslint
--     via vscode-langservers-extracted). nvim-lspconfig only wires them.
--   * FATS/SUPER mode (F2) and the hand-rolled statusline are rice
--     features — plugins must not replace them.
--
-- First launch bootstraps lazy.nvim from upstream (git clone,
-- branch=stable) and installs the specs — needs network, once. The
-- resolved versions land in this machine's lazy-lock.json afterwards.
-- =============================================================================

-- ---- leader = space, vim-style -----------------------------------------------
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- ---- Quality of life ---------------------------------------------------------
vim.opt.number = true          -- show line numbers
vim.opt.relativenumber = true  -- relative for easier j/k jumps
vim.opt.signcolumn = "yes"     -- always show sign column (no scrolloff jitter)
vim.opt.cursorline = true
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.smartindent = true
vim.opt.autoindent = true
vim.opt.termguicolors = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.scrolloff = 4
vim.opt.sidescrolloff = 8
vim.opt.showmode = false       -- mode shown in statusline below
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true        -- highlight matches; <leader>/ clears them
vim.opt.inccommand = "split"
vim.opt.updatetime = 250
vim.opt.timeoutlen = 400
vim.opt.clipboard = "unnamedplus"  -- wayland clipboard via wl-clipboard
vim.opt.undofile = true
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.mouse = "a"
vim.opt.wildmode = { "longest", "full" }

-- ---- Filetype detection ------------------------------------------------------
vim.filetype.add({
  extension = {
    rs = "rust",
    py = "python",
    c = "c",
    h = "c",
    cpp = "cpp",
    cc = "cpp",
    cxx = "cpp",
    hpp = "cpp",
    hh = "cpp",
    lua = "lua",
    java = "java",
    json = "json",
    toml = "toml",
    yaml = "yaml",
    yml = "yaml",
    md = "markdown",
  },
})

-- ---- Try pywal16 colors first; fall back to built-in palette --------------
-- pywal16 ships a template at pywal/templates/colors-wal.vim that, when
-- rendered by `wal -i <wallpaper>`, writes ~/.cache/wal/colors-wal.vim.
-- (Note the filename: "colors-wal.vim", NOT "colors.vim" — earlier
-- versions of this file used the wrong path.)
--
-- The template DOES NOT define a colorscheme named "pywal" or any other
-- name — it has no `g:colors_name` registration, no `highlight` calls.
-- It just defines `color0..15`, `background`, `foreground`, `cursor`
-- vim variables. So calling `colorscheme pywal` (as earlier code did)
-- would fail with E185 "Cannot find color scheme". Instead, we source
-- the file and use the variables it defines to drive our own
-- `nvim_set_hl` calls below — same code path as the fallback, just with
-- a different palette table. (Verified against pywal16 upstream at
-- https://github.com/eylles/pywal16/blob/master/pywal/templates/colors-wal.vim)

local wal_vim_path = vim.fn.expand("~/.cache/wal/colors-wal.vim")
local wal_enabled = false

if vim.fn.filereadable(wal_vim_path) == 1 then
  vim.cmd("source " .. wal_vim_path)
  wal_enabled = true
end

-- Baked fallback palette (Catppuccin Mocha approximation) used as the
-- highlight basis when wal hasn't run yet, so cold-first-boot render is
-- still coherent. When pywal HAS run, we use the sourced `color0..15`
-- vim variables instead — see the palette switch below.
local mocha = {
  bg        = "#1e1e2e",
  bg_alt    = "#181825",
  fg        = "#cdd6f4",
  red       = "#f38ba8",
  green     = "#a6e3a1",
  yellow    = "#f9e2af",
  blue      = "#89b4fa",
  magenta   = "#f5c2e7",
  cyan      = "#94e2d5",
  comment   = "#6c7086",
  selection = "#585b70",
  border    = "#313244",
}

-- Pick which palette to drive highlights from.
-- pywal16's colors-wal.vim defines: background, foreground, cursor, color0..15.
local P
if wal_enabled then
  -- Map pywal's color0..15 onto the slots our highlight table uses.
  -- color0  = bg-alt-ish (often near-black)
  -- color1  = red
  -- color2  = green
  -- color3  = yellow
  -- color4  = blue
  -- color5  = magenta
  -- color6  = cyan
  -- color7  = fg-light
  -- color8  = comment/dim
  -- color9..15 = bright variants of 1..7
  P = {
    bg        = vim.g.background or mocha.bg,
    bg_alt    = vim.g.color0     or mocha.bg_alt,
    fg        = vim.g.foreground or mocha.fg,
    red       = vim.g.color1     or mocha.red,
    green     = vim.g.color2     or mocha.green,
    yellow    = vim.g.color3     or mocha.yellow,
    blue      = vim.g.color4     or mocha.blue,
    magenta   = vim.g.color5     or mocha.magenta,
    cyan      = vim.g.color6     or mocha.cyan,
    comment   = vim.g.color8     or mocha.comment,
    selection = vim.g.color8     or mocha.selection,
    border    = vim.g.color0     or mocha.border,
  }
else
  P = mocha
end

-- Apply highlights. Same code regardless of which palette we picked.
vim.cmd("highlight clear")
vim.cmd("syntax on")

local hl = vim.api.nvim_set_hl
hl(0, "Normal",       { bg = P.bg, fg = P.fg })
hl(0, "NormalNC",     { bg = P.bg, fg = P.fg })
hl(0, "Comment",      { fg = P.comment, italic = true })
hl(0, "Constant",     { fg = P.yellow })
hl(0, "String",       { fg = P.green })
hl(0, "Identifier",   { fg = P.blue })
hl(0, "Function",     { fg = P.blue, bold = true })
hl(0, "Statement",    { fg = P.magenta })
hl(0, "Operator",     { fg = P.fg })
hl(0, "PreProc",      { fg = P.blue })
hl(0, "Type",         { fg = P.cyan })
hl(0, "Special",      { fg = P.red })
hl(0, "Error",        { fg = P.red, bg = P.bg, bold = true })
hl(0, "Todo",         { fg = P.yellow, bg = P.bg, bold = true })
hl(0, "MatchParen",   { bg = P.selection })
hl(0, "LineNr",       { fg = P.comment })
hl(0, "CursorLine",   { bg = P.bg_alt })
hl(0, "CursorLineNr", { fg = P.yellow, bold = true })
hl(0, "Visual",       { bg = P.selection })
hl(0, "Search",       { bg = P.blue, fg = P.bg })
hl(0, "IncSearch",    { bg = P.yellow, fg = P.bg })
hl(0, "Pmenu",        { bg = P.bg_alt, fg = P.fg })
hl(0, "PmenuSel",     { bg = P.blue, fg = P.bg })
hl(0, "VertSplit",    { fg = P.border })
hl(0, "SignColumn",   { bg = P.bg })
hl(0, "StatusLine",   { bg = P.bg_alt, fg = P.fg, bold = true })
hl(0, "StatusLineNC", { bg = P.bg_alt, fg = P.comment })
hl(0, "TabLine",      { bg = P.bg_alt, fg = P.comment })
hl(0, "TabLineSel",   { bg = P.bg_alt, fg = P.fg, bold = true })
hl(0, "TabLineFill",  { bg = P.bg_alt })
hl(0, "NormalFloat",  { bg = P.bg_alt, fg = P.fg })
hl(0, "FloatBorder",  { fg = P.border, bg = P.bg_alt })

-- Plugin UI groups link into the palette above so the IDE layer follows
-- wal without shipping theme plugins (rule: no colorscheme plugins).
hl(0, "TelescopeNormal",   { link = "Normal" })
hl(0, "TelescopeBorder",   { link = "FloatBorder" })
hl(0, "TelescopeSelection",{ link = "CursorLine" })
hl(0, "NvimTreeNormal",    { link = "Normal" })
hl(0, "NvimTreeFolderName",{ fg = P.blue })
hl(0, "CmpItemAbbrMatch",  { fg = P.blue, bold = true })
hl(0, "CmpItemAbbrMatchFuzzy", { fg = P.blue, bold = true })
hl(0, "CmpItemKind",       { fg = P.cyan })

-- ---- Statusline (no plugin) ------------------------------------------------
local function statusline()
  local mode_map = {
    n   = " NORMAL ",
    i   = " INSERT ",
    v   = " VISUAL ",
    V   = " V-LINE ",
    ["\22"] = " V-BLOCK ",
    c   = " CMD ",
    R   = " REPLACE ",
    s   = " SELECT ",
    S   = " S-LINE ",
    t   = " TERM ",
  }
  local m = mode_map[vim.fn.mode()] or " " .. vim.fn.mode() .. " "
  local km = (_G.rice_fats_mode) and " FATS " or " SUPER "
  local file = "%f"
  local mod  = "%m"
  local line = "  %l/%L:%c"
  return m .. km .. " " .. file .. mod .. line .. "%=" .. (wal_enabled and " [pywal] " or " [mocha] ") .. "%y "
end

vim.opt.statusline = "%!v:lua.statusline()"
_G.statusline = statusline

-- ---- Keymaps (sensible defaults + a couple of nicities) -------------------
local map = function(lhs, rhs, desc, mode)
  vim.keymap.set(mode or "n", lhs, rhs, { desc = desc, silent = true })
end
map("<leader>w", ":write<CR>",       "write")
map("<leader>q", ":quit<CR>",        "quit")
map("<leader>x", ":x<CR>",            "write+quit")
map("<leader>e", ":NvimTreeToggle<CR>", "file tree (nvim-tree)")
map("<leader>/", ":nohlsearch<CR>",  "clear search")
map("<leader>t", ":terminal<CR>",    "open terminal split")
map("<leader>n", "<cmd>set number! relativenumber!<CR>", "toggle line numbers")
map("<Esc>",     "<C-\\><C-n>",      "exit terminal mode", "t")

-- Telescope
map("<leader>ff", ":Telescope find_files<CR>", "find files")
map("<leader>fg", ":Telescope live_grep<CR>",  "live grep")
map("<leader>fb", ":Telescope buffers<CR>",    "buffers")

-- Buffer nav
map("<S-h>", ":bprev<CR>", "previous buffer")
map("<S-l>", ":bnext<CR>", "next buffer")

-- ---- fats mode <-> supermode (F2) ------------------------------------------
-- fats mode is this file's DEFAULT (Zed also starts with vim mode off):
-- supermode — plain vim modal editing — is what F2 switches you into.
-- fats mode is for people who hate modes: nvim stays in Insert
-- "permanently" — Esc stops leaving it (mapped to a no-op) and every
-- buffer re-enters Insert when you land on it. Ctrl-O still runs one
-- Normal command and drops you back. The Ctrl-S save / Ctrl-Z undo maps
-- give it the GUI-app feel (Ctrl-C/Ctrl-V already work via
-- clipboard=unnamedplus above). The active mode shows in the statusline
-- (FATS / SUPER), driven by the _G.rice_fats_mode flag.
--
-- NOTE: this is hand-rolled because Neovim REMOVED Vim's 'insertmode'
-- option (setting it dies with E519 "Option not supported" — verified on
-- nvim 0.11). The Esc-noop + startinsert-on-BufEnter pair below is the
-- same user-facing contract, not a fallback hack. The startinsert hook
-- skips non-file buffers (telescope prompts, nvim-tree, terminal) — the
-- re-enter behavior is only meaningful where you can type text.
local fats_group = vim.api.nvim_create_augroup("RiceFatsMode", { clear = true })
_G.rice_fats_mode = false
_G.rice_toggle_fats = function()
  _G.rice_fats_mode = not _G.rice_fats_mode
  if _G.rice_fats_mode then
    vim.keymap.set("i", "<Esc>", "<Nop>", { desc = "fats mode: stay in Insert" })
    vim.api.nvim_create_autocmd("BufEnter", {
      group = fats_group,
      callback = function()
        if vim.bo.buftype == "" then vim.cmd("startinsert") end
      end,
    })
    if vim.bo.buftype == "" then vim.cmd("startinsert") end
    print("fats mode — always Insert; Ctrl-O one-shot Normal, F2 back to supermode")
  else
    pcall(vim.keymap.del, "i", "<Esc>")
    vim.api.nvim_clear_autocmds({ group = fats_group })
    print("supermode — plain modal vim")
  end
end
map("<F2>",  _G.rice_toggle_fats, "toggle fats/supermode", { "n", "i" })
-- Start in fats mode: call the toggle itself rather than only setting
-- _G.rice_fats_mode = true — the Esc-noop map and the startinsert autocmd
-- only exist after this function has run, so flipping the bare flag would
-- give the FATS label with supermode behavior.
_G.rice_toggle_fats()
map("<C-s>", "<C-o>:write<CR>", "save (fats mode; harmless in normal Insert)", "i")
map("<C-z>", "<C-o>u", "undo from Insert (fats mode)", "i")

-- Window nav like Hyprland (mod + h/j/k/l)
map("<C-h>", "<C-w>h", "window left")
map("<C-j>", "<C-w>j", "window down")
map("<C-k>", "<C-w>k", "window up")
map("<C-l>", "<C-w>l", "window right")

-- Auto-reload on external file change (used by wal + zed + ghostty cross-edits)
vim.opt.autoread = true
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
  pattern = "*",
  command = "checktime",
})

-- ---- Diagnostics -------------------------------------------------------------
vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})
-- Plain-letter signs: readable without a nerd-font fallback dance.
for _, s in ipairs({ { "Error", "E" }, { "Warn", "W" }, { "Hint", "H" }, { "Info", "I" } }) do
  vim.fn.sign_define("DiagnosticSign" .. s[1], { text = s[2], texthl = "DiagnosticSign" .. s[1] })
end

-- ---- IDE plugins (lazy.nvim — see the editor plugin rule in this header) ----
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- File tree (hijacks netrw; <leader>e toggles)
  { "nvim-tree/nvim-tree.lua", opts = {} },

  -- Fuzzy finder (uses ripgrep/fd from 00-base.sh when present)
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
  },

  -- Syntax trees. Pinned to the frozen legacy `master` branch on
  -- purpose: the rewritten `main` branch needs per-plugin migration
  -- (vim.treesitter autocmds) — a deliberate follow-up, not drift.
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "python", "c", "cpp", "lua", "java", "rust", "json",
          "toml", "yaml", "markdown", "bash", "vim", "vimdoc",
        },
        highlight = { enable = true },
      })
    end,
  },

  -- Completion
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      cmp.setup({
        snippet = {
          expand = function(args) require("luasnip").lsp_expand(args.body) end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"]      = cmp.mapping.confirm({ select = true }),
          ["<C-e>"]     = cmp.mapping.abort(),
          ["<Tab>"]     = cmp.mapping.select_next_item(),
          ["<S-Tab>"]   = cmp.mapping.select_prev_item(),
        }),
        sources = {
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer" },
        },
      })
    end,
  },

  -- LSP wiring. Servers come from 00-base.sh (pacman) and 10-aur.sh
  -- (vscode-langservers-extracted) — nvim-lspconfig just connects them;
  -- no mason, nothing downloaded into nvim's data dir.
  {
    "neovim/nvim-lspconfig",
    dependencies = { "hrsh7th/cmp-nvim-lsp" },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local lspconfig = require("lspconfig")
      -- pacman (00-base.sh step 4):
      for _, name in ipairs({
        "pyright", "rust_analyzer", "clangd", "lua_ls",
        "bashls", "gopls", "ts_ls",
      }) do
        lspconfig[name].setup({ capabilities = capabilities })
      end
      -- AUR vscode-langservers-extracted (10-aur.sh):
      for _, name in ipairs({ "html", "cssls", "jsonls", "eslint" }) do
        lspconfig[name].setup({ capabilities = capabilities })
      end
      -- This repo is full of `vim.` calls; keep lua_ls quiet about them.
      lspconfig.lua_ls.setup({
        capabilities = capabilities,
        settings = { Lua = { diagnostics = { globals = { "vim" } } } },
      })
    end,
  },
})
