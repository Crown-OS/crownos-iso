--- @since 26.8.15

local DEFAULT_SHORTCUTS = {
	{ "H", "all shortcuts" },
	{ "l", "open" },
	{ "h", "back" },
	{ "<Space>", "select" },
	{ "y", "copy" },
	{ "x", "cut" },
	{ "p", "paste" },
	{ "d", "trash" },
	{ "u", "undo trash" },
	{ "a", "new" },
	{ "r", "rename" },
	{ "/", "find" },
	{ "'", "bookmarks" },
	{ "q", "quit" },
}

ShortcutBar = { _id = "shortcut-bar" }

function ShortcutBar:new(area, shortcuts)
	return setmetatable({ _area = area, _shortcuts = shortcuts }, { __index = self })
end

function ShortcutBar:reflow() return { self } end

function ShortcutBar:redraw()
	local spans = {}
	for _, shortcut in ipairs(self._shortcuts) do
		spans[#spans + 1] = ui.Span(" " .. shortcut[1] .. " "):style(th.mode.normal_main)
		spans[#spans + 1] = ui.Span(" " .. shortcut[2] .. "  "):style(th.status.overall)
	end
	return { ui.Line(spans):area(self._area) }
end

local function setup(_, opts)
	local shortcuts = (opts and opts.shortcuts) or DEFAULT_SHORTCUTS

	function Root:layout()
		self._chunks = ui.Layout()
			:direction(ui.Layout.VERTICAL)
			:constraints({
				ui.Constraint.Length(1),
				ui.Constraint.Length(Tabs.height()),
				ui.Constraint.Fill(1),
				ui.Constraint.Length(1),
				ui.Constraint.Length(1),
			})
			:split(self._area)
	end

	function Root:build()
		self._children = {
			Backdrop:new(self._area),
			Header:new(self._chunks[1], cx.active),
			Tabs:new(self._chunks[2]),
			Tab:new(self._chunks[3], cx.active),
			ShortcutBar:new(self._chunks[4], shortcuts),
			Status:new(self._chunks[5], cx.active),
			Modal:new(self._area),
		}
	end
end

return { setup = setup }
