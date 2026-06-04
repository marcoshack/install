-- Neovim configuration
-- Managed by https://github.com/marcoshack/install
--
-- Plugins are managed with lazy.nvim and pinned via lazy-lock.json (committed
-- alongside this file). Installs honor the lockfile (:Lazy restore); upgrades
-- only happen on an explicit `:Lazy update` so you can review the lockfile diff.

-- Leader keys must be set before plugins load
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- nvim-tree recommends disabling netrw at startup
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.opt.termguicolors = true

-- Bootstrap lazy.nvim (https://github.com/folke/lazy.nvim)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
  if vim.v.shell_error ~= 0 then
    error("Error cloning lazy.nvim:\n" .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    {
      "nvim-tree/nvim-tree.lua",
      version = "*",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = function()
        require("nvim-tree").setup({})
      end,
    },
    {
      -- Fuzzy finder: <leader>p = find files (VSCode Cmd+P), <leader>g = grep contents
      "nvim-telescope/telescope.nvim",
      branch = "0.1.x",
      dependencies = { "nvim-lua/plenary.nvim" },
      config = function()
        local builtin = require("telescope.builtin")
        vim.keymap.set("n", "<leader>p", builtin.find_files, { desc = "Find files (Cmd+P)" })
        vim.keymap.set("n", "<leader>g", builtin.live_grep, { desc = "Live grep file contents" })
        vim.keymap.set("n", "<leader>b", builtin.buffers, { desc = "Find open buffers" })
        vim.keymap.set("n", "<leader>h", builtin.help_tags, { desc = "Search help tags" })
      end,
    },
  },
  -- Don't auto-check for plugin updates; upgrades are explicit (:Lazy update)
  checker = { enabled = false },
})

-- Toggle the file explorer with <leader>e (space + e)
vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "Toggle file explorer" })
