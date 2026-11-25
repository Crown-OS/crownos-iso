-- Neovim UI Status Configuration
--
-- This module simply defines the configuration table structure for `opts.status` used in:
--
--    require("crownui").setup(opts)
--
-- copyright 2023
-- license GNU General Public License v3.0

---@class CrownUIStatusPadding
---@field left integer? number of spaces to pad to the left
---@field right integer? number of spaces to pad to the right

---@class CrownUIStatusSurround
---@field separator string|string[]? the separator index to use in the `separators` table
---@field color (fun(self: table): string|table)|string|table? the color to use as the separator foreground/component background
---@field condition (boolean|fun(self: table): boolean?)? the condition for displaying the surrounded component
---@field update CrownUIUpdateEvents? control updating of separators, either a list of events or true to update freely

---@class CrownUIStatusIcon
---@field kind string? the icon name as set in the CrownUI icons
---@field padding CrownUIStatusPadding? padding settings to apply to the icon

---@class CrownUIStatusStylizeOpts
---@field padding CrownUIStatusPadding? padding settings to apply to the string
---@field separator { left: string?, right: string? }? the separator characters to the left and right of the string
---@field escape boolean? whether to escape the provided string for special character handling or to return the string as is
---@field show_empty boolean? whether to show empty strings with padding and separators or just return and empty string
---@field icon CrownUIStatusIcon? icon settings to prepend to the string

---@class CrownUIProviderSigncolumnOpts: CrownUIStatusStylizeOpts

---@class CrownUIProviderNumbercolumnOpts: CrownUIStatusStylizeOpts
---@field thousands string|false? a string separator for numbers >= 1,000
---@field culright boolean? whether to right align the current line number

---@class CrownUIProviderFoldcolumnOpts: CrownUIStatusStylizeOpts

---@class CrownUIProviderSpellOpts: CrownUIStatusStylizeOpts

---@class CrownUIProviderPasteOpts: CrownUIStatusStylizeOpts

---@class CrownUIProviderMacroRecordingOpts: CrownUIStatusStylizeOpts
---@field prefix string? a character to prefix before a register

---@class CrownUIProviderShowcmdOpts: CrownUIStatusStylizeOpts
---@field minwid integer? minimum width
---@field maxwid integer? maximum width

---@class CrownUIProviderSearchCountOpts: CrownUIStatusStylizeOpts
---@field recompute boolean? Always recompute when calculating search (default: True)
---@field pattern string? Specify a pattern (default: `@/`)
---@field timeout integer? timeout in milliseconds, negative or 0 is no timeout (default: 0)
---@field maxcount integer? limit of matches, negative or 0 is no limit (default: 0)
---@field pos integer[]? position list ([lnum, col, off]) see `:h cursor()` for details (default: current position)

---@class CrownUIProviderModeTextOpts: CrownUIStatusStylizeOpts
---@field pad_text "right"|"left"|"center"|false? alignment of mode text

---@class CrownUIProviderPercentageOpts: CrownUIStatusStylizeOpts
---@field edge_text boolean? whether to show "Top"/"Bot" when on the first/last line

---@class CrownUIProviderRulerOpts: CrownUIStatusStylizeOpts
---@field pad_ruler { line: integer?, char: integer? }? padding to apply to line and character values

---@class CrownUIProviderScrollbarOpts: CrownUIStatusStylizeOpts
---@field chars string[]? characters to use for the scrollbar, ordered from bottom to top

---@class CrownUIProviderCloseButtonOpts: CrownUIStatusStylizeOpts
---@field kind string? the icon kind to use for the close button as defined in CrownUI icons

---@class CrownUIProviderFiletypeOpts: CrownUIStatusStylizeOpts

---@class CrownUIProviderBufnrOpts: CrownUIStatusStylizeOpts
---@field suffix string? string to append after the buffer number

---@class CrownUIProviderFilenameOpts: CrownUIStatusStylizeOpts
---@field fname (fun(bufnr: integer): string)? function for calculating the buffer name
---@field modify string? modifiers to pass to `fnamemodify` on final path
---@field fallback string? Fallback string for when a buffer does not have a filename

---@class CrownUIProviderFileEncodingOpts: CrownUIStatusStylizeOpts

---@class CrownUIProviderFileFormatOpts: CrownUIStatusStylizeOpts

---@class CrownUIProviderUniquePathOpts: CrownUIStatusStylizeOpts
---@field bufnr integer? the buffer number to fallback to if not provided to provider function
---@field buf_name (fun(bufnr: integer): string)? function for calculating buffer name
---@field max_length integer? maximum length before truncating with ellipsis

---@class CrownUIProviderFileModifiedOpts: CrownUIStatusStylizeOpts
---@field str string? the string to display when file is modified

---@class CrownUIProviderFileReadOnlyOpts: CrownUIStatusStylizeOpts
---@field str string? the string to display when file is read only

---@class CrownUIProviderFileIconOpts: CrownUIStatusStylizeOpts

---@class CrownUIProviderGitBranchOpts: CrownUIStatusStylizeOpts

---@class CrownUIProviderGitDiffOpts: CrownUIStatusStylizeOpts
---@field type "added"|"changed"|"removed"? the type of diff to display

---@class CrownUIProviderDiagnosticsOpts: CrownUIStatusStylizeOpts
---@field severity "ERROR"|"WARN"|"INFO"|"HINT"? the diagnostic severity to display

---@class CrownUIProviderLspProgressOpts: CrownUIStatusStylizeOpts

---@class CrownUIProviderLspClientNamesOpts: CrownUIStatusStylizeOpts
---@field integrations { null_ls: boolean?, conform: boolean?, nvim-lint: boolean? }? enable or disable client name integrations
---@field mappings { [string]: false|string|fun(client: string): (false|string|nil) }? add custom client name mappings ("*" will apply to all as a fallback)
---@field truncate number? percentage of statusline of the maximum width before truncation with ellipsis

---@class CrownUIProviderVirtualEnvOpts: CrownUIStatusStylizeOpts
---@field env_names string[]? base environment names to replace with the project directory name
---@field conda { enabled: boolean?, ignore_base: boolean? }? enable/disable conda environments and base conda environment
---@field format (string|fun(env: string): string)? string or function to customize formatting of environment name

---@class CrownUIProviderTreesitterStatusOpts: CrownUIStatusStylizeOpts

---@class CrownUIProviderStrOpts: CrownUIStatusStylizeOpts
---@field str string the static string to display

---@class CrownUIProviders
---@field signcolumn CrownUIProviderSigncolumnOpts? default options for the `signcolumn` provider
---@field numbercolumn CrownUIProviderNumbercolumnOpts? default options for the `numbercolumn` provider
---@field foldcolumn CrownUIProviderSigncolumnOpts? default options for the `foldcolumn` provider
---@field spell CrownUIProviderSpellOpts? default options for the `spell` provider
---@field paste CrownUIProviderSpellOpts? default options for the `paste` provider
---@field macro_recording CrownUIProviderMacroRecordingOpts? default options for the `macro_recording` provider
---@field showcmd CrownUIProviderShowcmdOpts? default options for the `showcmd` provider
---@field search_count CrownUIProviderSearchCountOpts? default options for the `search_count` provider
---@field mode_text CrownUIProviderModeTextOpts? default options for the `mode_text` provider
---@field percentage CrownUIProviderPercentageOpts? default options for the `percentage` provider
---@field ruler CrownUIProviderRulerOpts? default options for the `ruler` provider
---@field scrollbar CrownUIProviderScrollbarOpts? default options for the `scrollbar` provider
---@field close_button CrownUIProviderCloseButtonOpts? default options for the `close_button` provider
---@field filetype CrownUIProviderFiletypeOpts? default options for the `filetype` provider
---@field bufnr CrownUIProviderBufnrOpts? default options for the `bufnr` provider
---@field filename CrownUIProviderFilenameOpts? default options for the `filename` provider
---@field file_encoding CrownUIProviderFileEncodingOpts? default options for the `file_encoding` provider
---@field file_format CrownUIProviderFileFormatOpts? default options for the `file_format` provider
---@field unique_path CrownUIProviderUniquePathOpts? default options for the `unique_path` provider
---@field file_modified CrownUIProviderFileModifiedOpts? default options for the `file_modified` provider
---@field file_read_only CrownUIProviderFileReadOnlyOpts? default options for the `file_read_only` provider
---@field file_icon CrownUIProviderFileIconOpts? default options for the `file_icon` provider
---@field git_branch CrownUIProviderGitBranchOpts? default options for the `git_branch` provider
---@field git_diff CrownUIProviderGitDiffOpts? default options for the `git_diff` provider
---@field diagnostics CrownUIProviderDiagnosticsOpts? default options for the `diagnostics` provider
---@field lsp_progress CrownUIProviderLspProgressOpts? default options for the `lsp_progress` provider
---@field lsp_client_names CrownUIProviderLspClientNamesOpts? default options for the `lsp_client_names` provider
---@field virtual_env CrownUIProviderVirtualEnvOpts? default options for the `virtual_env` provider
---@field treesitter_status CrownUIProviderTreesitterStatusOpts? default options for the `treesitter_status` provider
---@field str CrownUIProviderStrOpts? default options for the `str` provider

---@class CrownUIInitBreadcrumbsOpts
---@field max_depth integer? the maximum depth of breadcrumbs to show moving upwards
---@field separator string? the string to use when separating breadcrumbs
---@field icon { enabled: boolean?, hl: boolean? }? enable/disable icon and it's semantic highlighting
---@field padding CrownUIStatusPadding? padding options for the component

---@class CrownUIInitSeparatedPathOpts
---@field max_depth integer? the maximum depth of breadcrumbs to show moving upwards
---@field path_func (fun(self: table): string)? the function for calculating the path to separate
---@field delimiter string? the string used when splitting the path into pieces
---@field separator string? the string to use for the path separator
---@field prefix boolean? whether or not to apply a prefix of the separator at the start of the path
---@field suffix boolean? whether or not to apply a suffix of the separator at the end of the path
---@field padding CrownUIStatusPadding? padding options for the component

---@class CrownUIComponentBuilderProviderOpts
---@field provider (fun(self: table): string?)|string a statusline provider function or the name of an CrownUI status provider
---@field opts table? a table of options to provide to the provider if the provider is an CrownUI status provider

---Configuration of the component building. Other keys are supported which are all keys which are allowed inside of a Heirline statusline component. See the `heirline` documentation for more details
---@class CrownUIComponentBuilderOpts
---@field padding CrownUIStatusPadding|false? padding options for final component
---@field surround CrownUIStatusSurround|false? surround options for final component
---@field [integer] CrownUIComponentBuilderProviderOpts? table of providers to include in the final component in an ordered list. Must provide a `provider` key

---@class CrownUIComponentFileInfoOpts: CrownUIComponentBuilderOpts
---@field file_icon CrownUIProviderFileIconOpts|false? `file_icon` provider options
---@field unique_path CrownUIProviderUniquePathOpts|false? `unique_path` provider options
---@field filename CrownUIProviderFilenameOpts|false? `filename` provider options
---@field filetype CrownUIProviderFiletypeOpts|false? `filetype` provider options
---@field file_modified CrownUIProviderFileModifiedOpts|false? `file_modified` provider options
---@field file_read_only CrownUIProviderFileReadOnlyOpts|false? `file_read_only` provider options
---@field close_button CrownUIProviderCloseButtonOpts|false? `close_button` provider options

---@class CrownUIComponentTablineFileInfoOpts: CrownUIComponentFileInfoOpts

---@class CrownUIComponentNavOpts: CrownUIComponentBuilderOpts
---@field ruler CrownUIProviderRulerOpts|false? `ruler` provider options
---@field percentage CrownUIProviderPercentageOpts|false? `percentage` provider options
---@field scrollbar CrownUIProviderScrollbarOpts|false? `scrollbar` provider options

---@class CrownUIComponentCmdInfoOpts: CrownUIComponentBuilderOpts
---@field macro_recording CrownUIProviderMacroRecordingOpts|false? `macro_recording` provider options
---@field search_count CrownUIProviderSearchCountOpts|false? `search_count` provider options
---@field showcmd CrownUIProviderShowcmdOpts|false? `showcmd` provider options

---@class CrownUIComponentModeOpts: CrownUIComponentBuilderOpts
---@field mode_text CrownUIProviderModeTextOpts|false? `mode_text` provider options
---@field str CrownUIProviderStrOpts|false? `str` provider options
---@field paste CrownUIProviderPasteOpts|false? `paste` provider options
---@field spell CrownUIProviderSpellOpts|false? `spell` provider options

---@class CrownUIComponentBreadcrumbsOpts: CrownUIInitBreadcrumbsOpts

---@class CrownUIComponentSeparatedPathOpts: CrownUIInitSeparatedPathOpts

---@class CrownUIComponentGitBranchOpts: CrownUIComponentBuilderOpts
---@field git_branch CrownUIProviderGitBranchOpts|false? `git_branch` provider options

---@class CrownUIComponentGitDiffOpts: CrownUIComponentBuilderOpts
---@field added CrownUIProviderGitDiffOpts|false? `git_diff` provider options for added git differences
---@field changed CrownUIProviderGitDiffOpts|false? `git_diff` provider options for changed git differences
---@field removed CrownUIProviderGitDiffOpts|false? `git_diff` provider options for removed git differences

---@class CrownUIComponentDiagnosticsOpts: CrownUIComponentBuilderOpts
---@field ERROR CrownUIProviderDiagnosticsOpts|false? `diagnostics` provider options for errors
---@field WARN CrownUIProviderDiagnosticsOpts|false? `diagnostics` provider options for warnings
---@field INFO CrownUIProviderDiagnosticsOpts|false? `diagnostics` provider options for information
---@field HINT CrownUIProviderDiagnosticsOpts|false? `diagnostics` provider options for hints

---@class CrownUIComponentTreesitterOpts: CrownUIComponentBuilderOpts
---@field str CrownUIProviderStrOpts|false? `str` provider options for when treesitter is available

---@class CrownUIComponentLspOpts: CrownUIComponentBuilderOpts
---@field lsp_progress CrownUIProviderLspProgressOpts|false? `lsp_progress` provider options
---@field lsp_client_names CrownUIProviderLspClientNamesOpts|false? `lsp_client_names` provider options

---@class CrownUIComponentVirtualEnvOpts: CrownUIComponentBuilderOpts
---@field virtual_env CrownUIProviderVirtualEnvOpts|false? `virtual_env` provider options

---@class CrownUIComponentFoldcolumnOpts: CrownUIComponentBuilderOpts
---@field foldcolumn CrownUIProviderFoldcolumnOpts|false? `foldcolumn` provider options

---@class CrownUIComponentNumbercolumnOpts: CrownUIComponentBuilderOpts
---@field numbercolumn CrownUIProviderNumbercolumnOpts|false? `numbercolumn` provider options

---@class CrownUIComponentSigncolumnOpts: CrownUIComponentBuilderOpts
---@field signcolumn CrownUIProviderSigncolumnOpts|false? `signcolumn` provider options

---@class CrownUIComponents
---@field file_info CrownUIComponentFileInfoOpts? default options for the `file_info` component
---@field tabline_file_info CrownUIComponentTablineFileInfoOpts? default options for the `tabline_file_info` component
---@field nav CrownUIComponentNavOpts? default options for the `nav` component
---@field cmd_info CrownUIComponentCmdInfoOpts? default options for the `cmd_info` component
---@field mode CrownUIComponentModeOpts? default options for the `mode` component
---@field breadcrumbs CrownUIComponentBreadcrumbsOpts? default options for the `breadcrumbs` component
---@field separated_path CrownUIComponentSeparatedPathOpts? default options for the `separated_path` component
---@field git_branch CrownUIComponentGitBranchOpts? default options for the `git_branch` component
---@field git_diff CrownUIComponentGitDiffOpts? default options for the `git_diff` component
---@field diagnostics CrownUIComponentDiagnosticsOpts? default options for the `diagnostics` component
---@field treesitter CrownUIComponentTreesitterOpts? default options for the `treesitter` component
---@field lsp CrownUIComponentLspOpts? default options for the `lsp` component
---@field virtual_env CrownUIComponentVirtualEnvOpts? default options for the `virtual_env` component
---@field foldcolumn CrownUIComponentFoldcolumnOpts? default options for the `foldcolumn` component
---@field numbercolumn CrownUIComponentNumbercolumnOpts? default options for the `numbercolumn` component
---@field signcolumn CrownUIComponentSigncolumnOpts? default options for the `signcolumn` component

---@class CrownUISeparators
---@field none string[]? placeholder separator for elements with "no" separator, typically two empty strings
---@field left string[]? Separators used for elements designated as being on the left of the statusline
---@field right string[]? Separators used for elements designated as being on the right of the statusline
---@field center string[]? Separators used for elements designated as being in the center of the statusline
---@field tab string[]? Separators used for tabs rendered in the tabline
---@field breadcrumbs string? Separator used in between symbols in the breadcrumbs
---@field path string? Separator used in between symbols in a file path

---@class CrownUIWinbar
---@field enabled table<BufMatcherKinds, BufMatcherPattern[]>? Buffer matching patterns for whitelisting buffers to enable winbar
---@field disabled table<BufMatcherKinds, BufMatcherPattern[]>? Buffer matching patterns for blacklisting buffers from enabling winbar

---@class CrownUIStatusOpts
---Configure attributes of components defined in the `status` API. Check the Neovim documentation for a complete list of color names, this applies to colors that have `_fg` and/or `_bg` names with the suffix removed (ex. `git_branch_fg` as attributes from `git_branch`).
---Example:
---
---```lua
---attributes = {
---  git_branch = { bold = true },
---}
---```
---@field attributes table<string,table>?
---Configure colors of components defined in the `status` API. Check the Neovim documentation for a complete list of color names.
---Example:
---
---```lua
---colors = {
---  git_branch_fg = "#ABCDEF",
---}
---```
---@field colors (StringMap|(fun(colors:StringMap):StringMap?))?
---Set up the default configuration options for the provided statusline components.
---TODO: this field still needs to add strong typing
---Example:
---```lua
---components = {
---  file_info = {
---    file_read_only = false
---  }
---}
---```
---@field components CrownUIComponents?
---**MEANT FOR INTERNAL USE ONLY**
---A table of fallback colors if a colorscheme used by the user does not have a highlight group, the entry point to this are typically through the `status.colors` option.
---@field fallback_colors StringMap?
---Configure which icons that are highlighted based on context
---Example:
---
---```lua
---icon_highlights = {
---  breadcrumbs = false,
---  file_icon = {
---    tabline = function(self) return self.is_active or self.is_visible end,
---    statusline = true,
---  }
---}
---```
---@field icon_highlights CrownUIIconHighlights?
---**MEANT FOR INTERNAL USE ONLY**
---Conversion table of vim mode text to readable text and color name to be used
---Example:
---
---```lua
---modes = {
---  ["n"] = {
---    "NORMAL", -- readable name
---    "normal", -- color name
---  },
---  ["no"] = {
---    "OP",     -- readable name
---    "normal", -- color name
---  }
---}
---```
---@field modes table<string,string[]>?
---Set up the default configuration options for the provided statusline providers.
---TODO: this field still needs to add strong typing
---Example:
---```lua
---providers = {
---  lsp_client_names = {
---    mappings = {
---      ruff_organize_imports = "ruff"
---    }
---  }
---}
---```
---@field providers CrownUIProviders?
---Configure characters used as separators for various elements
---Example:
---
---```lua
---separators = {
---  none = { "", "" },
---  left = { "", "  " },
---  right = { "  ", "" },
---  center = { "  ", "  " },
---  tab = { "", "" },
---  breadcrumbs = "  ",
---  path = "  ",
---}
---```
---@field separators CrownUISeparators?
---Configure when winbar is enabled/disabled
---@field winbar CrownUIWinbar?
---**MEANT FOR INTERNAL USE ONLY**
---Function used for setting up colors in Heirline, the entry point to this are typically through the `status.colors` option.
---@field setup_colors (fun():StringMap)?
---**MEANT FOR INTERNAL USE ONLY**
---A collection of click handlers for internal heirline components such as `gitsigns`, `diagnostics`, and `dap`
---@field sign_handlers table<string,fun(args:table)>?

local function handle_sign_click(args)
  if not args.sign then return false end
  local config = assert(require("crownui").config.status)
  local handler = args.sign.name ~= "" and config.sign_handlers[args.sign.name]
  if not handler then handler = config.sign_handlers[args.sign.namespace] end
  if not handler then handler = config.sign_handlers[args.sign.texthl] end
  if handler then
    handler(args)
    return true
  end
  return false
end

---@type CrownUIStatusOpts
return {
  attributes = {},
  colors = {},
  components = {
    file_info = {
      file_icon = {
        hl = function(self) return require("crownui.status.hl").file_icon "statusline"(self) end,
        padding = { left = 1, right = 1 },
      },
      bufnr = false,
      filename = false,
      filetype = {},
      file_modified = {
        padding = { left = 1 },
        condition = function(...) return require("crownui.status.condition").is_file(...) end,
      },
      file_read_only = {
        padding = { left = 1 },
        condition = function(...) return require("crownui.status.condition").is_file(...) end,
      },
      surround = {
        separator = "left",
        color = "file_info_bg",
        condition = function(...) return require("crownui.status.condition").has_filetype(...) end,
      },
      hl = function() return require("crownui.status.hl").get_attributes "file_info" end,
    },
    tabline_file_info = {
      file_icon = {
        condition = function(self) return not self._show_picker end,
        hl = function(self) return require("crownui.status.hl").file_icon "tabline"(self) end,
      },
      filename = {},
      filetype = false,
      unique_path = {
        hl = function(self) return require("crownui.status.hl").get_attributes(self.tab_type .. "_path") end,
      },
      close_button = {
        hl = function(self) return require("crownui.status.hl").get_attributes(self.tab_type .. "_close") end,
        padding = { left = 1, right = 1 },
        on_click = {
          callback = function(_, minwid) require("crowncore.buffer").close(minwid) end,
          minwid = function(self) return self.bufnr end,
          name = "heirline_tabline_close_buffer_callback",
        },
      },
      padding = { right = 1 },
      hl = function(self)
        local tab_type = self.tab_type
        if self._show_picker and self.tab_type ~= "buffer_active" then tab_type = "buffer_visible" end
        return require("crownui.status.hl").get_attributes(tab_type)
      end,
      surround = false,
    },
    nav = {
      ruler = {},
      percentage = { padding = { left = 1 } },
      scrollbar = { padding = { left = 1 }, hl = { fg = "scrollbar" } },
      surround = { separator = "right", color = "nav_bg" },
      hl = function() return require("crownui.status.hl").get_attributes "nav" end,
      update = { "CursorMoved", "CursorMovedI", "BufEnter" },
    },
    cmd_info = {
      macro_recording = {
        icon = { kind = "MacroRecording", padding = { right = 1 } },
        condition = function() return require("crownui.status.condition").is_macro_recording() end,
        update = { "RecordingEnter", "RecordingLeave" },
      },
      search_count = {
        icon = { kind = "Search", padding = { right = 1 } },
        padding = { left = 1 },
        condition = function() return require("crownui.status.condition").is_hlsearch() end,
      },
      showcmd = {
        padding = { left = 1 },
        condition = function() return require("crownui.status.condition").is_statusline_showcmd() end,
      },
      surround = {
        separator = "center",
        color = "cmd_info_bg",
        condition = function()
          local condition = require "crownui.status.condition"
          return condition.is_hlsearch() or condition.is_macro_recording() or condition.is_statusline_showcmd()
        end,
      },
      condition = function() return vim.opt.cmdheight:get() == 0 end,
      hl = function() return require("crownui.status.hl").get_attributes "cmd_info" end,
    },
    mode = {
      mode_text = false,
      paste = false,
      spell = false,
      surround = {
        separator = "left",
        color = function() return require("crownui.status.hl").mode_bg() end,
        update = { "ModeChanged", pattern = "*:*" },
      },
      hl = function() return require("crownui.status.hl").get_attributes "mode" end,
      update = {
        "ModeChanged",
        pattern = "*:*",
        callback = function() vim.schedule(vim.cmd.redrawstatus) end,
      },
    },
    breadcrumbs = {
      padding = { left = 1 },
      condition = function() return require("crownui.status.condition").aerial_available() end,
      update = "CursorMoved",
    },
    separated_path = { padding = { left = 1 }, update = { "BufEnter", "DirChanged" } },
    git_branch = {
      git_branch = { icon = { kind = "GitBranch", padding = { right = 1 } } },
      surround = {
        separator = "left",
        color = "git_branch_bg",
        condition = function(...) return require("crownui.status.condition").is_git_repo(...) end,
      },
      hl = function() return require("crownui.status.hl").get_attributes "git_branch" end,
      on_click = {
        name = "heirline_branch",
        callback = function()
          local fzf_lua_avail, fzf_lua = pcall(require, "fzf-lua")
          if fzf_lua_avail then
            fzf_lua.git_branches()
            return
          end

          local telescope_avail, telescope_builtin = pcall(require, "telescope.builtin")
          if telescope_avail then
            telescope_builtin.git_branches { use_file_path = true }
            return
          end

          local snacks_avail, snacks = pcall(require, "snacks")
          if snacks_avail then
            snacks.picker.git_branches()
            return
          end
        end,
      },
      update = {
        "User",
        pattern = { "GitSignsUpdate", "GitSignsChanged" },
        callback = function() vim.schedule(vim.cmd.redrawstatus) end,
      },
      init = function(...) return require("crownui.status.init").update_events { "BufEnter" }(...) end,
    },
    git_diff = {
      added = { icon = { kind = "GitAdd", padding = { left = 1, right = 1 } } },
      changed = { icon = { kind = "GitChange", padding = { left = 1, right = 1 } } },
      removed = { icon = { kind = "GitDelete", padding = { left = 1, right = 1 } } },
      hl = function() return require("crownui.status.hl").get_attributes "git_diff" end,
      on_click = {
        name = "heirline_git",
        callback = function()
          local fzf_lua_avail, fzf_lua = pcall(require, "fzf-lua")
          if fzf_lua_avail then
            fzf_lua.git_status()
            return
          end

          local telescope_avail, telescope_builtin = pcall(require, "telescope.builtin")
          if telescope_avail then
            telescope_builtin.git_status { use_file_path = true }
            return
          end

          local snacks_avail, snacks = pcall(require, "snacks")
          if snacks_avail then
            snacks.picker.git_status()
            return
          end
        end,
      },
      surround = {
        separator = "left",
        color = "git_diff_bg",
        condition = function(...) return require("crownui.status.condition").git_changed(...) end,
      },
      update = {
        "User",
        pattern = { "GitSignsUpdate", "GitSignsChanged", "MiniDiffUpdated" },
        callback = function() vim.schedule(vim.cmd.redrawstatus) end,
      },
      init = function(...) return require("crownui.status.init").update_events { "BufEnter" }(...) end,
    },
    diagnostics = {
      ERROR = { icon = { kind = "DiagnosticError", padding = { left = 1, right = 1 } } },
      WARN = { icon = { kind = "DiagnosticWarn", padding = { left = 1, right = 1 } } },
      INFO = { icon = { kind = "DiagnosticInfo", padding = { left = 1, right = 1 } } },
      HINT = { icon = { kind = "DiagnosticHint", padding = { left = 1, right = 1 } } },
      surround = {
        separator = "left",
        color = "diagnostics_bg",
        condition = function(...) return require("crownui.status.condition").has_diagnostics(...) end,
      },
      hl = function() return require("crownui.status.hl").get_attributes "diagnostics" end,
      on_click = {
        name = "heirline_diagnostic",
        callback = function()
          local fzf_lua_avail, fzf_lua = pcall(require, "fzf-lua")
          if fzf_lua_avail then
            fzf_lua.diagnostics_document()
            return
          end

          local telescope_avail, telescope_builtin = pcall(require, "telescope.builtin")
          if telescope_avail then
            telescope_builtin.diagnostics { bufnr = 0 }
            return
          end

          local snacks_avail, snacks = pcall(require, "snacks")
          if snacks_avail then
            snacks.picker.diagnostics_buffer()
            return
          end
        end,
      },
      update = { "DiagnosticChanged", "BufEnter" },
    },
    treesitter = {
      str = { str = "TS", icon = { kind = "ActiveTS", padding = { right = 1 } } },
      surround = {
        separator = "right",
        color = "treesitter_bg",
        condition = function(...) return require("crownui.status.condition").treesitter_available(...) end,
      },
      hl = function() return require("crownui.status.hl").get_attributes "treesitter" end,
      update = { "OptionSet", pattern = "syntax" },
      init = function(...) return require("crownui.status.init").update_events { "BufEnter" }(...) end,
    },
    lsp = {
      lsp_progress = {
        str = "",
        padding = { right = 1 },
        update = {
          "User",
          pattern = "CrownLspProgress",
          callback = function() vim.schedule(vim.cmd.redrawstatus) end,
        },
      },
      lsp_client_names = {
        str = "LSP",
        update = {
          "LspAttach",
          "LspDetach",
          "BufEnter",
          "FileType",
          "VimResized",
          callback = function() vim.schedule(vim.cmd.redrawstatus) end,
        },
        icon = { kind = "ActiveLSP", padding = { right = 2 } },
      },
      hl = function() return require("crownui.status.hl").get_attributes "lsp" end,
      surround = {
        separator = "right",
        color = "lsp_bg",
        condition = function(...) return require("crownui.status.condition").lsp_attached(...) end,
      },
      on_click = {
        name = "heirline_lsp",
        callback = function()
          vim.schedule(function() vim.cmd.checkhealth "vim.lsp" end)
        end,
      },
    },
    virtual_env = {
      virtual_env = { icon = { kind = "Environment", padding = { right = 1 } } },
      surround = {
        separator = "right",
        color = "virtual_env_bg",
      },
      hl = function() return require("crownui.status.hl").get_attributes "virtual_env" end,
      on_click = {
        name = "heirline_virtual_env",
        callback = function()
          if vim.fn.exists ":VenvSelect" > 0 then vim.schedule(vim.cmd.VenvSelect) end
        end,
      },
    },
    foldcolumn = {
      foldcolumn = { padding = { right = 1 } },
      condition = function() return require("crownui.status.condition").foldcolumn_enabled() end,
      on_click = {
        name = "fold_click",
        callback = function(...)
          local get_icon = require("crownui").get_icon
          local char = require("crownui.status.utils").statuscolumn_clickargs(...).char
          local fillchars = vim.opt_local.fillchars:get()
          if char == (fillchars.foldopen or get_icon "FoldOpened") then
            vim.cmd "norm! zc"
          elseif char == (fillchars.foldclose or get_icon "FoldClosed") then
            vim.cmd "norm! zo"
          end
        end,
      },
    },
    numbercolumn = {
      numbercolumn = { padding = { right = 1 } },
      condition = function() return require("crownui.status.condition").numbercolumn_enabled() end,
      on_click = {
        name = "line_click",
        callback = function(...)
          local args = require("crownui.status.utils").statuscolumn_clickargs(...)
          if args.mods:find "c" then
            local dap_avail, dap = pcall(require, "dap")
            if dap_avail then dap.toggle_breakpoint() end
          else
            handle_sign_click(args)
          end
        end,
      },
    },
    signcolumn = {
      signcolumn = {},
      condition = function() return require("crownui.status.condition").signcolumn_enabled() end,
      on_click = {
        name = "sign_click",
        callback = function(...)
          local args = require("crownui.status.utils").statuscolumn_clickargs(...)
          handle_sign_click(args)
        end,
      },
    },
  },
  fallback_colors = {},
  icon_highlights = {},
  modes = {},
  providers = {
    signcolumn = { escape = false },
    numbercolumn = { thousands = false, culright = true, escape = false },
    foldcolumn = { escape = false },
    spell = { str = "", icon = { kind = "Spellcheck" }, show_empty = true },
    paste = { str = "", icon = { kind = "Paste" }, show_empty = true },
    macro_recording = { prefix = "@" },
    showcmd = { minwid = 0, maxwid = 5, escape = false },
    search_count = {},
    mode_text = { pad_text = false },
    percentage = { escape = false, fixed_width = true, edge_text = true },
    ruler = { pad_ruler = { line = 3, char = 2 } },
    scrollbar = { chars = { "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" } },
    close_button = { kind = "BufferClose" },
    bufnr = { suffix = "." },
    filename = {
      fallback = "Untitled",
      fname = function(bufnr) return vim.api.nvim_buf_get_name(bufnr) end,
      modify = ":t",
    },
    unique_path = {
      buf_name = function(bufnr) return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t") end,
      bufnr = 0,
      max_length = 16,
    },
    file_modified = { str = "", icon = { kind = "FileModified" }, show_empty = true },
    file_read_only = { str = "", icon = { kind = "FileReadOnly" }, show_empty = true },
    lsp_client_names = {
      mappings = {},
      integrations = { null_ls = true, conform = true, ["nvim-lint"] = true },
      truncate = 0.25,
    },
    virtual_env = { env_names = { "env", ".env", "venv", ".venv" }, conda = { enabled = true, ignore_base = true } },
    str = { str = " " },
  },
  separators = {},
  setup_colors = nil,
  sign_handlers = {},
  winbar = {},
}
