--[[
You can define as many rings as you want per unit in the LuaUI/Configs/customunitrings.lua file — just like you would with customParams.
The key is that each unit's entry in the config file is a list (Lua table) of ring definitions.

The widget loops over each ring in that list, just like it would for multiple _1, _2, etc. customParams.
So you're free to:

    Layer textures and outlines
    Have concentric radius rings
    Mix filled and textured visuals

return {
	fedcommander = {
		-- Ring 1: Outline only
		{
			radius = 500,
			color = {0, 1, 0, 0.25},
			lineWidth = 2,
			divs = 64,
			alwaysshow = true,
		},

		-- Ring 2: Texture-based fill
		{
			radius = 300,
			color = {1, 1, 1, 0.5},
			texture = "LuaUI/Images/customringtextures/red_ring_fill.dds",
			texSize = 600,
			alwaysshow = false,
		},

		-- Ring 3: Filled color fallback
		{
			radius = 200,
			fillColor = {0.5, 0.2, 1, 0.2},
			divs = 64,
			lineWidth = 1,
		}
	},

	atm = {
		{
			radius = 3000,
			color = {1, 0.3, 0, 0.4},
			lineWidth = 1,
			divs = 128,
		}
	}
}
]]--

return {
	-- Key is the unitDefName
	fedcommander = {
		{
			radius = 225,
			color = {1, 0, 0, 0.5},
			lineWidth = 1,
			divs = 64,
			alwaysshow = true,
			-- Optional fill or texture
			--fillColor = {0, 0.5, 0.5, 0.2},
			--texture = "LuaUI/Images/customringtextures/red_ring_fill.dds",
			--texSize = 1000,
		},

	},
	fedcommander_up1 = {
		{
			radius = 325,
			color = {1, 0, 0, 0.5},
			lineWidth = 1,
			divs = 64,
			alwaysshow = true,
			-- Optional fill or texture
			--fillColor = {0, 0.5, 0.5, 0.2},
			--texture = "LuaUI/Images/customringtextures/red_ring_fill.dds",
			--texSize = 1000,
		},

	},
	fedcommander_up2 = {
		{
			radius = 525,
			color = {1, 0, 0, 0.5},
			lineWidth = 1,
			divs = 64,
			alwaysshow = true,
			-- Optional fill or texture
			--fillColor = {0, 0.5, 0.5, 0.2},
			--texture = "LuaUI/Images/customringtextures/red_ring_fill.dds",
			--texSize = 1000,
		},

	},
	fedcommander_up3 = {
		{
			radius = 625,
			color = {1, 0, 0, 0.5},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
			-- Optional fill or texture
			--fillColor = {0, 0.5, 0.5, 0.2},
			--texture = "LuaUI/Images/customringtextures/red_ring_fill.dds",
			--texSize = 1000,
		},

	},
	fedcommander_up4 = {
		{
			radius = 825,
			color = {1, 0, 0, 0.5},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
			-- Optional fill or texture
			--fillColor = {0, 0.5, 0.5, 0.2},
			--texture = "LuaUI/Images/customringtextures/red_ring_fill.dds",
			--texSize = 1000,
		},

	},

	lozcommander = {
		{
			radius = 225,
			color = {1, 0, 0, 0.5},
			lineWidth = 1,
			divs = 64,
			alwaysshow = true,
			-- Optional fill or texture
			--fillColor = {0, 0.5, 0.5, 0.2},
			--texture = "LuaUI/Images/customringtextures/red_ring_fill.dds",
			--texSize = 1000,
		},

	},
	lozcommander_up1 = {
		{
			radius = 325,
			color = {1, 0, 0, 0.5},
			lineWidth = 1,
			divs = 64,
			alwaysshow = true,
			-- Optional fill or texture
			--fillColor = {0, 0.5, 0.5, 0.2},
			--texture = "LuaUI/Images/customringtextures/red_ring_fill.dds",
			--texSize = 1000,
		},

	},
	lozcommander_up2 = {
		{
			radius = 525,
			color = {1, 0, 0, 0.5},
			lineWidth = 1,
			divs = 64,
			alwaysshow = true,
			-- Optional fill or texture
			--fillColor = {0, 0.5, 0.5, 0.2},
			--texture = "LuaUI/Images/customringtextures/red_ring_fill.dds",
			--texSize = 1000,
		},

	},
	lozcommander_up3 = {
		{
			radius = 625,
			color = {1, 0, 0, 0.5},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
			-- Optional fill or texture
			--fillColor = {0, 0.5, 0.5, 0.2},
			--texture = "LuaUI/Images/customringtextures/red_ring_fill.dds",
			--texSize = 1000,
		},

	},
	lozcommander_up4 = {
		{
			radius = 825,
			color = {1, 0, 0, 0.5},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
			-- Optional fill or texture
			--fillColor = {0, 0.5, 0.5, 0.2},
			--texture = "LuaUI/Images/customringtextures/red_ring_fill.dds",
			--texSize = 1000,
		},

	},


	atm = {
		{
			radius = 250,
			color = {1, 0.3, 0, 0.4},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
		},
		{
			radius = 500,
			color = {1, 0.3, 0, 0.4},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
		},
		{
			radius = 750,
			color = {1, 0.3, 0, 0.4},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
		},
		{
			radius = 1000,
			color = {1, 0.3, 0, 0.4},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
		},
		{
			radius = 1250,
			color = {1, 0.3, 0, 0.4},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
		},
		{
			radius = 1500,
			color = {1, 0.3, 0, 0.4},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
		},
		{
			radius = 1750,
			color = {1, 0.3, 0, 0.4},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
		},
		{
			radius = 2000,
			color = {1, 0.3, 0, 0.4},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
		},
		{
			radius = 2250,
			color = {1, 0.3, 0, 0.4},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
		},
		{
			radius = 2500,
			color = {1, 0.3, 0, 0.4},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
		},
		{
			radius = 2750,
			color = {1, 0.3, 0, 0.4},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
		},
		{
			radius = 3000,
			color = {1, 0.3, 0, 0.4},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
		},
		{
			radius = 3250,
			color = {1, 0.3, 0, 0.4},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
		},
		{
			radius = 3500,
			color = {1, 0.3, 0, 0.4},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
		},
		{
			radius = 3750,
			color = {1, 0.3, 0, 0.4},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
		},
		{
			radius = 4000,
			color = {1, 0.3, 0, 0.4},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
		},
		{
			radius = 4250,
			color = {1, 0.3, 0, 0.4},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
		},
		{
			radius = 4500,
			color = {1, 0.3, 0, 0.4},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
		},
		{
			radius = 4750,
			color = {1, 0.3, 0, 0.4},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
		},
		{
			radius = 5000,
			color = {1, 0.3, 0, 0.4},
			lineWidth = 1,
			divs = 128,
			alwaysshow = true,
		},

	}
}