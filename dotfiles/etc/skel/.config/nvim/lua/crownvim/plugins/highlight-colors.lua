return {
  "brenoprata10/nvim-highlight-colors",
  event = { "User CrownFile", "InsertEnter" },
  cmd = "HighlightColors",
  specs = {
    {
      "crowncore",
      opts = function(_, opts)
        local maps = opts.mappings
        maps.n["<Leader>uz"] = { function() vim.cmd.HighlightColors "Toggle" end, desc = "Toggle color highlight" }
      end,
    },
  },
  opts = {
    enable_named_colors = false,
    virtual_symbol = "󱓻",
    exclude_buffer = function(bufnr)
      local buf_utils = require "crowncore.buffer"
      return buf_utils.is_large(bufnr) or not buf_utils.is_valid(bufnr)
    end,
  },
}
