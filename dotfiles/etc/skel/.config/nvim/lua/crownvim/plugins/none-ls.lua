return {
  "nvimtools/none-ls.nvim",
  main = "null-ls",
  specs = {
    { "nvim-lua/plenary.nvim", lazy = true },
    {
      "crownlsp",
      opts = function(_, opts)
        local maps = opts.mappings
        maps.n["<Leader>lI"] = {
          "<Cmd>NullLsInfo<CR>",
          desc = "Null-ls information",
          cond = function() return vim.fn.exists ":NullLsInfo" > 0 end,
        }
      end,
    },
  },
  dependencies = {
    {
      "jay-babu/mason-null-ls.nvim",
      dependencies = { "mason-org/mason.nvim" },
      cmd = { "NullLsInstall", "NullLsUninstall" },
      opts_extend = { "ensure_installed" },
      opts = { ensure_installed = {}, handlers = {} },
      config = function(...) require "crownvim.plugins.configs.mason-null-ls"(...) end,
    },
  },
  event = "User CrownFile",
  opts = {},
}
