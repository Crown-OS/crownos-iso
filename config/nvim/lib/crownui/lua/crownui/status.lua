-- CrownVim Status Utilities
--
-- Status utility functions to use within CrownVim and user configurations.
--
-- This module can be loaded with `local crown = require "crownui.status"`
--
-- copyright 2023
-- license GNU General Public License v3.0

return {
  --- @see crownui.status.component
  component = require "crownui.status.component",
  --- @see crownui.status.condition
  condition = require "crownui.status.condition",
  --- @see crownui.status.heirline
  heirline = require "crownui.status.heirline",
  --- @see crownui.status.hl
  hl = require "crownui.status.hl",
  --- @see crownui.status.init
  init = require "crownui.status.init",
  --- @see crownui.status.provider
  provider = require "crownui.status.provider",
  --- @see crownui.status.utils
  utils = require "crownui.status.utils",
}
