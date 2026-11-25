return {
  "windwp/nvim-autopairs",
  event = "User CrownFile",
  specs = {
    {
      "crowncore",
      opts = function(_, opts)
        local maps = opts.mappings
        maps.n["<Leader>ua"] = { function() require("crowncore.toggles").autopairs() end, desc = "Toggle autopairs" }
      end,
    },
  },
  opts_extend = { "disable_filetype" },
  opts = {
    check_ts = true,
    enabled = function(bufnr) return require("crowncore.buffer").is_valid(bufnr) end,
    ts_config = { java = false },
    fast_wrap = {
      map = "<M-e>",
      chars = { "{", "[", "(", '"', "'" },
      pattern = ([[ [%'%"%)%>%]%)%}%,] ]]):gsub("%s+", ""),
      offset = 0,
      end_key = "$",
      keys = "qwertyuiopzxcvbnmasdfghjkl",
      check_comma = true,
      highlight = "PmenuSel",
      highlight_grey = "LineNr",
    },
  },
  config = function(...) require "crownvim.plugins.configs.nvim-autopairs"(...) end,
}
