return {
  "mason-org/mason-lspconfig.nvim",
  dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig" },
  event = "User CrownFile",
  cmd = { "LspInstall", "LspUninstall" },
  opts_extend = { "ensure_installed" },
  opts = {
    ensure_installed = {},
  },
  config = function(...) require "crownvim.plugins.configs.mason-lspconfig"(...) end,
}
