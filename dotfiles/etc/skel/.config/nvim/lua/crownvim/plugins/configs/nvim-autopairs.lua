return function(_, opts)
  local npairs = require "nvim-autopairs"
  npairs.setup(opts)

  local crowncore = require "crowncore"
  if not crowncore.config.features.autopairs then npairs.disable() end
end
