-- Neovim LSP Configuration
--
-- This module simply defines the configuration table structure for `opts` used in:
--
--    require("crownlsp").setup(opts)
--
-- copyright 2023
-- license GNU General Public License v3.0

---@alias CrownLSPCondition string|boolean|fun(client:vim.lsp.Client,bufnr:integer):boolean conditional for doing something when attaching a language server

---@class CrownLSPMapping: vim.api.keyset.keymap
---@field [1] string|function? rhs of keymap
---@field mode? string|string[] mode(s) for the mapping
---@field name string? optional which-key mapping name
---@field group? string|fun():string optional which-key mapping group
---@field cond CrownLSPCondition? condition for whether or not to set the mapping during language server attachment

---@alias CrownLSPMappings table<string,table<string,(CrownLSPMapping|string|false)?>?>

---@class CrownLSPCommand: vim.api.keyset.user_command
---@field [1] string|function the command to execute
---@field cond CrownLSPCondition? condition for whether or not to create the user command during language server attachment

---@class CrownLSPAutocmd: vim.api.keyset.create_autocmd
---@field event string|string[] Event(s) that will trigger the handler
---@field callback? fun(args:vim.api.keyset.create_autocmd.callback_args,client:vim.lsp.Client,bufnr:integer): boolean?

---@class CrownLSPAutocmds
---@field cond CrownLSPCondition? condition for whether or not to create the auto commands during language server attachment
---@field [integer] CrownLSPAutocmd an autocommand definition

---@class CrownLSPFeatureOpts
---@field codelens boolean? enable/disable codelens refresh on start (boolean; default = true)
---@field inlay_hints boolean? enable/disable inlay hints on start (boolean; default = false)
---@field inline_completion boolean? enable/disable inline completion (boolean; default = false)
---@field linked_editing_range boolean? enable/disable linked editing range (boolean; default = false)
---@field semantic_tokens boolean? enable/disable global semantic token highlighting at startup (boolean; default = true)
---@field signature_help boolean? enable/disable automatic signature help (boolean; default = false)

---@class CrownLSPFormatOnSaveOpts
---@field enabled boolean? enable or disable format on save globally
---@field allow_filetypes string[]? a list like table of filetypes to whitelist formatting on save
---@field ignore_filetypes string[]? a list like table of filetypes to blacklist formatting on save
---@field filter (fun(bufnr):boolean)? a function for doing a custom format on save filter based on buffer number

---@class CrownLSPFormatOpts: vim.lsp.buf.format.Opts
---@field format_on_save boolean|CrownLSPFormatOnSaveOpts? control formatting on save options
---@field disabled true|string[]? true to disable all or a list like table of language server names to disable formatting
---@field filter (fun(client):boolean)? a function for doing a custom formatting filter based on LSP client name

---@class CrownLSPFileOperationsOperationsOpts
---@field dynamicRegistration boolean? enable/disable dynamic file operation registration
---@field willCreate boolean? enable/disable pre-create file requests
---@field willDelete boolean? enable/disable pre-delete file requests
---@field willRename boolean? enable/disable pre-rename file requests
---@field didCreate boolean? enable/disable post-create file notifications
---@field didDelete boolean? enable/disable post-delete file notifications
---@field didRename boolean? enable/disable post-rename file notifications

---@class CrownLSPFileOperationsOpts
---@field timeout integer? timeout length in ms when executing LSP client file operations
---@field operations CrownLSPFileOperationsOperationsOpts? enable/disable file operations

---@class CrownLSPDefaultOpts
---@field hover vim.lsp.buf.hover.Opts|false? control the default options for `vim.lsp.buf.hover()` (`:h vim.lsp.buf.hover.Opts`)
---@field signature_help vim.lsp.buf.signature_help.Opts|false? control the default options for `vim.lsp.buf.signature_help()` (`:h vim.lsp.buf.signature_help.Opts`)

---@class CrownLSPOpts
---Configuration of auto commands
---The key into the table is the group name for the auto commands (`:h augroup`) and the value
---is a list of autocmd tables where `event` key is the event(s) that trigger the auto command
---and the rest are auto command options (`:h nvim_create_autocmd`). A `cond` key can also be
---added to control when an `augroup` is added and whether its callbacks run for the currently attached clients
---Example:
---
---```lua
---autocmds = {
---  -- first key is the `augroup` (:h augroup)
---  lsp_document_highlight = {
---    -- condition to create the auto command group and run its callbacks
---    cond = "textDocument/documentHighlight",
---    -- list of auto commands to set
---    {
---      -- events to trigger
---      event = { "CursorHold", "CursorHoldI" },
---      -- the rest of the autocmd options (:h nvim_create_autocmd)
---      desc = "Document Highlighting",
---      callback = function() vim.lsp.buf.document_highlight() end
---    },
---    {
---      event = { "CursorMoved", "CursorMovedI", "BufLeave" },
---      desc = "Document Highlighting Clear",
---      callback = function() vim.lsp.buf.clear_references() end
---    }
---  }
---}
---```
---@field autocmds table<string,CrownLSPAutocmds|false>?
---Configuration of user commands
---The key into the table is the name of the user command and the value is a table of command options. A `cond` key
---be added to control whether or not the user command is created when the language server is created.
---Example:
---
---```lua
---commands = {
---  -- key is the command name
---  Format = {
---    -- first element with no key is the command (string or function)
---    function() vim.lsp.buf.format() end,
---    -- condition to create the user command
---    cond = "textDocument/formatting",
---    -- the rest are options for creating user commands (:h nvim_create_user_command)
---    desc = "Format file with LSP",
---  }
---}
---```
---@field commands table<string,CrownLSPCommand|false>?
---Configuration table of features provided by CrownLSP
---Example:
--
---```lua
---features = {
---  codelens = true,
---  inlay_hints = false,
---  semantic_tokens = true,
---}
---```
---@field features CrownLSPFeatureOpts?
---Configure options for language servers passed to `vim.lsp.config(key, config)` (`:h vim.lsp.config`)
---Example
--
---```lua
---config = {
---  ["*"] = {
---    capabilities = {
---      textDocument = {
---        foldingRange = { dynamicRegistration = false }
---      }
---    },
---    exit_timeout = 5000, -- Neovim v0.12+
---    flags = { exit_timeout = 5000 }, -- Neovim v0.11
---  },
---}
---```
---@field config table<string,vim.lsp.Config>?
---Configure default options passed to `vim.lsp.buf` functions
---Example:
---
---```lua
---defaults = {
---  hover = {
---    border = "rounded",
---    silent = true,
---  },
---  signature_help = {
---    border = "rounded",
---    silent = true,
---    focusable = false,
---  },
---}
---```
---@field defaults CrownLSPDefaultOpts?
---Configure LSP based file operations
---Example:
--
---```lua
---file_operations = {
---  -- the timeout when executing LSP client operations
---  timeout = 10000,
---  -- fully disable/enable file-operation methods and dynamic registration
---  operations = {
---   dynamicRegistration = true,
---   willRename = true,
---   didRename = true,
---   willCreate = true,
---   didCreate = true,
---   willDelete = true,
---   didDelete = true,
---  }
--- }
---```
---@field file_operations CrownLSPFileOperationsOpts|false?
---Configuration options for controlling formatting with language servers
---Example:
--
---```lua
---formatting = {
---  -- control auto formatting on save
---  format_on_save = {
---    -- enable or disable format on save globally
---    enabled = true,
---    -- enable format on save for specified filetypes only
---    allow_filetypes = {
---      "go",
---    },
---    -- disable format on save for specified filetypes
---    ignore_filetypes = {
---      "python",
---    },
---  },
---  -- disable formatting capabilities for specific language servers
---  disabled = {
---    "lua_ls",
---  },
---  -- default format timeout
---  timeout_ms = 1000,
---  -- filter the language server clients used for formatting
---  filter = function(client)
---    return true
---  end
---}
---```
---@field formatting CrownLSPFormatOpts?
---Configure how language servers get set up
---Example:
--
---```lua
---handlers = {
---  -- default handler
---  ["*"] = vim.lsp.enable,
---  -- custom function handler for pyright
---  pyright = function()
---    -- some custom logic
---  end,
---  -- set to false to disable the setup of a language server
---  rust_analyzer = false,
---}
---```
---@field handlers table<string,fun(server:string)|boolean?>?
---Configure global LSP handlers, set a method to `false` to use the Neovim default (`:h vim.lsp.handlers`)
---Example:
--
---```lua
---lsp_handlers = {
---  ["textDocument/publishDiagnostics"] = my_custom_diagnostics_handler,
---}
---```
---@field lsp_handlers table<string,lsp.Handler|false>|false?
---Configuration of mappings added when attaching a language server during the core `on_attach` function
---The first key into the table is the vim map mode (`:h map-modes`), and the value is a table of entries to be passed to `vim.keymap.set` (`:h vim.keymap.set`):
---  - The key is the first parameter or the vim mode (only a single mode supported) and the value is a table of keymaps within that mode:
---    - The first element with no key in the table is the action (the 2nd parameter) and the rest of the keys/value pairs are options for the third parameter. There is also a special `cond` key which can either be a string of a language server capability or a function with `client` and `bufnr` parameters that returns a boolean of whether or not the mapping is added.
---Example:
--
---```lua
---mappings = {
---  -- map mode (:h map-modes)
---  n = {
---    -- a binding with no condition and therefore is always added
---    gl = {
---      function() vim.diagnostic.open_float() end,
---      desc = "Hover diagnostics"
---    },
---    -- condition for only server with declaration capabilities
---    gD = {
---      function() vim.lsp.buf.declaration() end,
---      desc = "Declaration of current symbol",
---      cond = "textDocument/declaration",
---    },
---    -- condition with a full function with `client` and `bufnr`
---    ["<leader>uY"] = {
---      function()
---        require("crownlsp.toggles").buffer_semantic_tokens()
---      end,
---      desc = "Toggle LSP semantic highlight (buffer)",
---      cond = function(client, bufnr)
---        return client.server_capabilities.semanticTokensProvider
---           and vim.lsp.semantic_tokens
---      end,
---    },
---  }
---}
---```
---@field mappings CrownLSPMappings?
---A list like table of servers that should be setup, useful for enabling language servers not installed with Mason.
---Example:
--
---```lua
---servers = { "dartls" }
---```
---@field servers string[]?
---A custom `on_attach` function to be run after the default `on_attach` function, takes two parameters `client` and `bufnr`  (`:h lspconfig-setup`)
---Example:
--
---```lua
---on_attach = function(client, bufnr)
---  client.server_capabilities.semanticTokensProvider = nil
---end
---```
---@field on_attach fun(client:vim.lsp.Client,bufnr:integer)?

---@type CrownLSPOpts
local M = {
  autocmds = {},
  commands = {},
  features = {
    codelens = true,
    inlay_hints = false,
    inline_completion = false,
    linked_editing_range = false,
    semantic_tokens = true,
    signature_help = false,
  },
  config = {},
  defaults = {},
  file_operations = { timeout = 10000, operations = {} },
  formatting = { format_on_save = { enabled = true }, disabled = {} },
  handlers = {},
  lsp_handlers = {},
  mappings = {},
  servers = {},
  on_attach = nil,
}

return M
