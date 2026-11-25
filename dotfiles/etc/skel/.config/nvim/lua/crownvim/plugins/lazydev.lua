return {
  "folke/lazydev.nvim",
  ft = "lua",
  cmd = "LazyDev",
  opts_extend = { "library" },
  opts = {
    library = {
      { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      { path = "lazy.nvim", words = { "Lazy" } },
      { path = "crowncore", words = { "CrownCore" } },
      { path = "crownlsp", words = { "CrownLSP" } },
      { path = "crownui", words = { "CrownUI" } },
    },
  },
  specs = {
    {
      "saghen/blink.cmp",
      optional = true,
      opts = {
        sources = {
          default = { "lazydev" },
          providers = {
            lazydev = { name = "LazyDev", module = "lazydev.integrations.blink", score_offset = 100 },
          },
        },
      },
    },
  },
}
