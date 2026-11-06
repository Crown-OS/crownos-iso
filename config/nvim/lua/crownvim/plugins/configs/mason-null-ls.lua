return function(_, opts)
  if require("crowncore").is_available "mason-tool-installer.nvim" then opts.ensure_installed = nil end
  require("mason-null-ls").setup(opts)
end
