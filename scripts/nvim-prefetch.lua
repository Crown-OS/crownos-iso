-- Run by nvim-prefetch.sh inside a headless Neovim that loaded config/nvim.
-- Installs every plugin at its lazy-lock.json commit, every treesitter parser
-- and blink.cmp's fuzzy library into the data directory and exits non-zero if
-- any of them is missing.

local timeout_ms = 600000

local function fail(message)
  io.stderr:write(message, "\n")
  vim.cmd.cquit()
end

local function prefetch()
  require("lazy").restore { wait = true, show = false }
  require("lazy").clean { wait = true, show = false }

  local parsers = require("crowncore").config.treesitter.ensure_installed
  require("lazy").load { plugins = { "nvim-treesitter", "blink.cmp" } }
  require("nvim-treesitter").install(parsers):wait(timeout_ms)
  local installed = require("nvim-treesitter").get_installed "parsers"
  local missing_parsers = vim.tbl_filter(function(lang) return not vim.list_contains(installed, lang) end, parsers)
  if #missing_parsers > 0 then return fail("missing treesitter parsers: " .. table.concat(missing_parsers, ", ")) end

  local blink_version_path = require("blink.cmp.fuzzy.download.files").version_path
  local function blink_library_ready()
    local read, lines = pcall(vim.fn.readfile, blink_version_path)
    return read and lines[1] ~= nil and lines[1] ~= "v0.0.0" and pcall(require, "blink.cmp.fuzzy.rust")
  end
  if not vim.wait(timeout_ms, blink_library_ready, 500) then
    return fail "blink.cmp did not download its fuzzy library"
  end

  vim.cmd.quitall { bang = true }
end

local ok, err = pcall(prefetch)
if not ok then fail(tostring(err)) end
