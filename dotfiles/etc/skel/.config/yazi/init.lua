-- Plugin setup. Plugins live in ~/.config/yazi/plugins, pinned in package.toml;
-- `ya pkg add owner/repo` adds more and `ya pkg upgrade` updates them.
-- Learn more: https://yazi-rs.github.io/docs/plugins/overview

require("full-border"):setup()
require("shortcut-bar"):setup()
require("git"):setup()
require("fs-usage"):setup()
require("smart-enter"):setup({ open_multi = true })
require("restore"):setup()
require("gvfs"):setup()

require("yafg"):setup({
	editor = "nvim",
	file_arg_format = "+{row} {file}",
})

require("whoosh"):setup({
	bookmarks = {
		{ tag = "Desktop", path = "~/Desktop", key = "d" },
		{ tag = "Documents", path = "~/Documents", key = "D" },
		{ tag = "Downloads", path = "~/Downloads", key = "o" },
		{ tag = "Pictures", path = "~/Pictures", key = "p" },
		{ tag = "Config", path = "~/.config", key = "c" },
	},
})
