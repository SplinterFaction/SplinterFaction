function widget:GetInfo()
	return {
		name      = "Custom Cursor Sets",
		desc      = "v1.1 Choose different cursor sets.",
		author    = "CarRepairer, AF",
		date      = "2012-01-11",
		license   = "GNU GPL, v2 or later",
		layer     = -100000,
		handler   = true,
		experimental = false,
		enabled   = true,
		alwaysStart = true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local echo = Spring.Echo

--------------------------------------------------------------------------------

function RestoreCursor() end
function SetCursor(cursorSet) end

options_path = 'Settings/Mouse Cursor'
options = {
	cursorsets = {
		name = 'Cursor Sets',
		type = 'list',
		OnChange = function (self)
			if self.value == 'zk' then
				RestoreCursor()
			else
				SetCursor( self.value );
			end
		end,
		items = {
			{ key = 'zk', name = 'Animated', },
			{ key = 'zk_static', name = 'Static', },
			{ key = 'ca', name = 'CA Classic', },
			{ key = 'ca_static', name = 'CA Static', },
			{ key = 'erom', name = 'Erom', },
			{ key = 'masse', name = 'Masse', },
			{ key = 'forboding_angel', name = 'forboding_angel', },
			{ key = 'k_haos_girl', name = 'K_haos_girl', },
		},
		value = 'zk',
	}
}


--------------------------------------------------------------------------------
--Mouse cursor icons

local cursorNames = {
	'cursornormal',
	'cursorareaattack',
	'cursorattack',
	'cursorsetattack',
	'cursorbuildbad',
	'cursorbuildgood',
	'cursorcapture',
	'cursorcentroid',
	'cursordwatch',
	'cursorwait',
	'cursordgun',
	'cursorfight',
	'cursorgather',
	'cursordefend',
	'cursorpickup',
	'cursormove',
	'cursorpatrol',
	'cursorreclamate',
	'cursorrepair',
	'cursorrevive',
	'cursorrestore',
	'cursorselfd',
	'cursornumber',
	'cursortime',
	'cursorunload',
}

SetCursor = function(cursorSet)
	-- Spring.ReplaceMouseCursor returns false when the replacement loaded no
	-- frames, and the engine installs it anyway, so an incomplete set leaves
	-- cursors that draw nothing at all. Fall back to the shipped ones instead.
	local missing = 0

	for _, cursor in ipairs(cursorNames) do
		local topLeft = (cursor == 'cursornormal' and cursorSet ~= 'k_haos_girl')
		if not Spring.ReplaceMouseCursor(cursor, cursorSet.."/"..cursor, topLeft) then
			missing = missing + 1
		end
	end

	if missing > 0 then
		echo("Cursor set '"..tostring(cursorSet).."' is missing "..missing.." of "
		..#cursorNames.." cursors, falling back to the default set")
		RestoreCursor()
	end
end

RestoreCursor = function()
	for _, cursor in ipairs(cursorNames) do
		local topLeft = (cursor == 'cursornormal')
		Spring.ReplaceMouseCursor(cursor, cursor, topLeft)
	end
end
