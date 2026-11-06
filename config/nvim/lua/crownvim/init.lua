local M = {}

M.config = require "crownvim.config"

---@param name string a library bundled under `lib/` of the Neovim config
---@return string
function M.library(name) return vim.fn.stdpath "config" .. "/lib/" .. name end

function M.init()
  if vim.fn.has "nvim-0.11" == 0 then
    vim.api.nvim_echo({
      { "CrownVim requires Neovim >= 0.11.0\n", "ErrorMsg" },
      { "Press any key to exit", "MoreMsg" },
    }, true, {})
    vim.fn.getchar()
    vim.cmd.quit()
  end

  require("crownvim.notify").defer_startup()
  vim.g.mapleader = vim.g.mapleader or M.config.mapleader
  vim.g.maplocalleader = vim.g.maplocalleader or M.config.maplocalleader
  if M.config.icons_enabled == false then vim.g.icons_enabled = false end
end

return M
