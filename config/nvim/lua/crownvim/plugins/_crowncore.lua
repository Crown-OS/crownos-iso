return {
  { import = "crownvim.lazy_snapshot" },
  {
    "crowncore",
    dir = require("crownvim").library "crowncore",
    dependencies = { "crownui" },
    opts_extend = {
      "treesitter.ensure_installed",
      "rooter.ignore.servers",
      "rooter.ignore.dirs",
      "sessions.ignore.buftypes",
      "sessions.ignore.dirs",
      "sessions.ignore.filetypes",
      "git_worktrees",
    },
    lazy = false,
    priority = 10000,
    opts = function(_, opts)
      local get_icon = require("crownui").get_icon
      local can_compile_parsers = vim.fn.executable "cc" == 1
      return require("crowncore").extend_tbl(opts, {
        features = {
          large_buf = {
            enabled = function(bufnr) return require("crowncore.buffer").is_valid(bufnr) end,
            notify = true,
            size = 1.5 * 1024 * 1024,
            lines = 100000,
            line_length = 1000,
          },
          autopairs = true, -- enable autopairs at start
          cmp = true, -- enable completion at start
          diagnostics = true, -- enable diagnostics by default
          highlighturl = true, -- highlight URLs by default
          notifications = true, -- enable notifications
        },
        diagnostics = {
          virtual_text = true,
          signs = {
            text = {
              [vim.diagnostic.severity.ERROR] = get_icon "DiagnosticError",
              [vim.diagnostic.severity.HINT] = get_icon "DiagnosticHint",
              [vim.diagnostic.severity.WARN] = get_icon "DiagnosticWarn",
              [vim.diagnostic.severity.INFO] = get_icon "DiagnosticInfo",
            },
          },
          update_in_insert = false,
          underline = true,
          severity_sort = true,
          float = {
            source = "if_many",
            header = "",
            prefix = "",
          },
          jump = {
            -- TODO: remove when dropping support for Neovim v0.11
            float = vim.fn.has "nvim-0.12" == 0 and true or nil,
            on_jump = function(_, bufnr) vim.diagnostic.open_float { bufnr = bufnr, scope = "cursor", focus = false } end,
          },
        },
        rooter = {
          enabled = true,
          detector = { "lsp", { ".git", "_darcs", ".hg", ".bzr", ".svn" }, { "lua", "Makefile", "package.json" } },
          ignore = {
            servers = {},
            dirs = {},
          },
          autochdir = false,
          scope = "global",
          notify = false,
        },
        sessions = {
          autosave = { last = true, cwd = true },
          ignore = {
            dirs = {},
            filetypes = { "gitcommit", "gitrebase" },
            buftypes = { "nofile" },
          },
        },
        treesitter = {
          enabled = function(_, bufnr) return not require("crowncore.buffer").is_large(bufnr) end,
          highlight = true,
          indent = true,
          auto_install = can_compile_parsers,
          auto_install_cli = can_compile_parsers,
          ensure_installed = {
            "bash",
            "c",
            "css",
            "html",
            "javascript",
            "json",
            "lua",
            "markdown",
            "markdown_inline",
            "python",
            "query",
            "ron",
            "rust",
            "toml",
            "tsx",
            "typescript",
            "vim",
            "vimdoc",
            "yaml",
          },
          textobjects = {
            select = {
              select_textobject = {
                ["ak"] = { query = "@block.outer", desc = "around block" },
                ["ik"] = { query = "@block.inner", desc = "inside block" },
                ["ac"] = { query = "@class.outer", desc = "around class" },
                ["ic"] = { query = "@class.inner", desc = "inside class" },
                ["a?"] = { query = "@conditional.outer", desc = "around conditional" },
                ["i?"] = { query = "@conditional.inner", desc = "inside conditional" },
                ["af"] = { query = "@function.outer", desc = "around function" },
                ["if"] = { query = "@function.inner", desc = "inside function" },
                ["ao"] = { query = "@loop.outer", desc = "around loop" },
                ["io"] = { query = "@loop.inner", desc = "inside loop" },
                ["aa"] = { query = "@parameter.outer", desc = "around argument" },
                ["ia"] = { query = "@parameter.inner", desc = "inside argument" },
              },
            },
            move = {
              goto_next_start = {
                ["]k"] = { query = "@block.outer", desc = "Next block start" },
                ["]f"] = { query = "@function.outer", desc = "Next function start" },
                ["]a"] = { query = "@parameter.inner", desc = "Next argument start" },
              },
              goto_next_end = {
                ["]K"] = { query = "@block.outer", desc = "Next block end" },
                ["]F"] = { query = "@function.outer", desc = "Next function end" },
                ["]A"] = { query = "@parameter.inner", desc = "Next argument end" },
              },
              goto_previous_start = {
                ["[k"] = { query = "@block.outer", desc = "Previous block start" },
                ["[f"] = { query = "@function.outer", desc = "Previous function start" },
                ["[a"] = { query = "@parameter.inner", desc = "Previous argument start" },
              },
              goto_previous_end = {
                ["[K"] = { query = "@block.outer", desc = "Previous block end" },
                ["[F"] = { query = "@function.outer", desc = "Previous function end" },
                ["[A"] = { query = "@parameter.inner", desc = "Previous argument end" },
              },
            },
            swap = {
              swap_next = {
                [">K"] = { query = "@block.outer", desc = "Swap next block" },
                [">F"] = { query = "@function.outer", desc = "Swap next function" },
                [">A"] = { query = "@parameter.inner", desc = "Swap next argument" },
              },
              swap_previous = {
                ["<K"] = { query = "@block.outer", desc = "Swap previous block" },
                ["<F"] = { query = "@function.outer", desc = "Swap previous function" },
                ["<A"] = { query = "@parameter.inner", desc = "Swap previous argument" },
              },
            },
          },
        },
      } --[[@as CrownCoreOpts]])
    end,
  },
}
