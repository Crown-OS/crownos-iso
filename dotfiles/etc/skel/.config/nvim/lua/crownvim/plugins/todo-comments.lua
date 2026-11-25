return {
  "folke/todo-comments.nvim",
  dependencies = { { "folke/snacks.nvim", optional = true } },
  cmd = { "TodoTrouble", "TodoLocList", "TodoQuickFix" },
  event = "User CrownFile",
  specs = {
    { "nvim-lua/plenary.nvim", lazy = true },
    {
      "crowncore",
      opts = function(_, opts)
        local maps = opts.mappings
        local crowncore = require "crowncore"
        if
          crowncore.is_available "snacks.nvim"
          and vim.tbl_get(crowncore.plugin_opts "snacks.nvim", "picker", "enabled") ~= false
        then
          maps.n["<Leader>fT"] = {
            function()
              if not package.loaded["todo-comments"] then -- make sure to load todo-comments
                require("lazy").load { plugins = { "todo-comments.nvim" } }
              end
              require("snacks").picker.todo_comments()
            end,
            desc = "Find TODOs",
          }
        end
        maps.n["]T"] = { function() require("todo-comments").jump_next() end, desc = "Next TODO comment" }
        maps.n["[T"] = { function() require("todo-comments").jump_prev() end, desc = "Previous TODO comment" }
      end,
    },
    {
      "nvim-telescope/telescope.nvim",
      optional = true,
      specs = {
        { "folke/todo-comments.nvim", cmd = { "TodoTelescope" } },
        {
          "crowncore",
          opts = { mappings = { n = { ["<Leader>fT"] = { "<Cmd>TodoTelescope<CR>", desc = "Find TODOs" } } } },
        },
      },
    },
    {
      "ibhagwan/fzf-lua",
      optional = true,
      specs = {
        { "folke/todo-comments.nvim", cmd = { "TodoFzfLua" } },
        {
          "crowncore",
          opts = { mappings = { n = { ["<Leader>fT"] = { "<Cmd>TodoFzfLua<CR>", desc = "Find TODOs" } } } },
        },
      },
    },
  },
  opts = {},
}
