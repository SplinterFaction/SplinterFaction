function widget:GetInfo()
	return {
		name = "Custom Unit Rings",
		desc = "Draws rings and textures using ring parameters from customParams",
		author = "",
		date = "2025",
		license = "Public Domain",
		layer = 0,
		enabled = true
	}
end

--[[
--------------------------------------------------------------------------------------------------------------------
*******WHEN USING THIS IN YOUR OWN PROJECT, DON'T FORGET THE CONFIG FILE! (LuaUI/Configs/customunitrings.lua)*******
--------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------
*** springsettings.cfg Option ***
--------------------------------------------------------------------------------------------------------------------
CustomUnitRingsMode = 1

0 → Show rings only for units owned by the local player
1 → Show rings for local player + allies (default)
2 → Show rings for all units


If you need the define rings outside of customparams, edit the config file here LuaUI/Configs/customunitrings.lua

 Multiple rings via customParams (_1, _2, ..., _n)

	ring_color = "r,g,b,a" — for line/outline color
	ring_fillcolor = "r,g,b,a" — filled triangle ring (optional fallback)
	ring_texture = "LuaUI/Images/customringtextures/green_ring_fill.dds" — texture overlay (super clean & fast)
	ring_texsize = "1024" — size of texture quad in world units
	ring_radius = "250" — fallback radius for drawing circle lines
	ring_linewidth = "1" — outline thickness
	ring_divs = "128" — sides of the circle (outline only)
	ring_alwaysshow = "true" or "false"

You can use the following keys in the unit’s customParams:

    ring_color = "R,G,B,A" (example: "0.5,1,0,0.3")
    ring_radius = "500"
    ring_linewidth = "2"
    ring_divs = "128"
    ring_alwaysshow = "true" or "false"

You can define multiple rings by appending _1, _2, etc. (e.g., ring_color_1, ring_radius_1, etc.). double and triple digits are supported (e.g. _10 _100)
RING NUMBERS MUST BE CONSECUTIVE! YOU CANNOT SKIP NUMBERS! (Do not do this: _1, _3. Numbers must be one after the other: _1, _2, _3, etc)

customParams = {
	ring_color = "0,1,0,0.25",
	ring_radius = "500",
	ring_linewidth = "10",
	ring_divs = "128",
	ring_alwaysshow = "false",

	ring_color_1 = "1,0,0,0.5",
	ring_radius_1 = "1000",
	ring_linewidth_1 = "2",
	ring_divs_1 = "128",
	ring_alwaysshow_1 = "true",
}

customParams = {
	-- Ring 1 with texture overlay
	ring_radius = "500",
	ring_color = "1,1,1,0.5",
	ring_texture = "LuaUI/Images/customringtextures/green_ring_fill.dds",
	ring_texsize = "1000",  -- optional, defaults to radius * 2
	ring_alwaysshow = "true",

	-- Ring 2 with fill color
	ring_radius_1 = "300",
	ring_fillcolor_1 = "0,1,0,0.25",
	ring_divs_1 = "64",
	ring_linewidth_1 = "1",

	-- Ring 3 with outline only
	ring_radius_2 = "800",
	ring_color_2 = "1,0,0,0.3",
}


]]--

local showMode = Spring.GetConfigInt("CustomUnitRingsMode", 1)
local myAllyTeam = Spring.GetMyAllyTeamID()
local myTeam = Spring.GetMyTeamID()
local lastShowMode = showMode


local ringedUnits = {}

local function ParseColorString(str)
	if not str then return nil end
	local r, g, b, a = str:match("([^,]+),([^,]+),([^,]+),([^,]+)")
	return r and { tonumber(r), tonumber(g), tonumber(b), tonumber(a) } or nil
end

local function ExtractRingConfigs(customParams)
	local rings = {}
	local index = 0
	while true do
		local suffix = index == 0 and "" or ("_" .. index)

		local radius = tonumber(customParams["ring_radius" .. suffix])
		local colorStr = customParams["ring_color" .. suffix]
		local fillColorStr = customParams["ring_fillcolor" .. suffix]
		local texture = customParams["ring_texture" .. suffix]

		-- Only process if there's something to draw
		if not (radius or texture) then break end

		local ring = {
			radius = radius or 0,
			lineWidth = tonumber(customParams["ring_linewidth" .. suffix]) or 1,
			divs = tonumber(customParams["ring_divs" .. suffix]) or 32,
			color = ParseColorString(colorStr),
			fillColor = ParseColorString(fillColorStr),
			texture = texture,
			texSize = tonumber(customParams["ring_texsize" .. suffix]),
			alwaysshow = (customParams["ring_alwaysshow" .. suffix] or "false") == "true"
		}
		table.insert(rings, ring)
		index = index + 1
	end
	return #rings > 0 and rings or nil
end

function widget:Initialize()
	for _, uId in pairs(Spring.GetAllUnits()) do
		widget:UnitEnteredLos(uId)
	end
end

function widget:UnitEnteredLos(unitID)
	local unitDefID = Spring.GetUnitDefID(unitID)
	if unitDefID then
		widget:UnitCreated(unitID, unitDefID)
	end
end

local unitRingConfig = VFS.FileExists("LuaUI/Configs/customunitrings.lua") and VFS.Include("LuaUI/Configs/customunitrings.lua") or {}

function widget:UnitCreated(unitID, unitDefID)
	local ud = UnitDefs[unitDefID]
	if not ud then return end

	local defName = ud.name
	local rings

	-- Try config file first
	if unitRingConfig[defName] then
		rings = unitRingConfig[defName]
	else
		-- Fallback: try customParams
		rings = ExtractRingConfigs(ud.customParams or {})
	end

	if rings then
		ringedUnits[unitID] = rings
	end
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	local ud = UnitDefs[unitDefID]
	if not ud then return end

	local defName = ud.name
	local rings

	-- Try config file first
	if unitRingConfig[defName] then
		rings = unitRingConfig[defName]
	else
		-- Fallback: try customParams
		rings = ExtractRingConfigs(ud.customParams or {})
	end

	if rings then
		ringedUnits[unitID] = rings
	end
end



function widget:UnitDestroyed(unitID)
	ringedUnits[unitID] = nil
end

local function UpdateShowMode()
	local newMode = Spring.GetConfigInt("CustomUnitRingsMode", 1)
	if newMode ~= lastShowMode then
		showMode = newMode
		lastShowMode = newMode
		Spring.Echo("CustomUnitRingsMode updated to " .. newMode)
	end
end


function widget:DrawWorldPreUnit()

	for unitID, rings in pairs(ringedUnits) do
		local show = false
		local unitTeam = Spring.GetUnitTeam(unitID)
		local unitAllyTeam = Spring.GetUnitAllyTeam(unitID)

		-- Show conditions based on config setting
		if showMode == 2 then
			show = true -- Show everything
		elseif showMode == 1 and unitAllyTeam == myAllyTeam then
			show = true -- Show allied units
		elseif showMode == 0 and unitTeam == myTeam then
			show = true -- Show own units only
		end

		-- Respect selection or alwaysshow
		if show then
			local filtered = true
			for _, ring in ipairs(rings) do
				if ring.alwaysshow or Spring.IsUnitSelected(unitID) then
					filtered = false
					break
				end
			end
			show = not filtered
		end

		if show then
			local ux, uy, uz = Spring.GetUnitPosition(unitID)
			if ux then
				for _, ring in ipairs(rings) do
					if ring.alwaysshow or Spring.IsUnitSelected(unitID) then
						-- Draw texture ring
						if ring.texture then
							gl.PushMatrix()
							gl.Translate(ux, uy + 1, uz)
							gl.Rotate(90, 1, 0, 0)
							gl.Texture(ring.texture)
							gl.Color(1, 1, 1, (ring.color and ring.color[4]) or 1)
							local s = ring.texSize or (ring.radius * 2)
							gl.TexRect(-s/2, -s/2, s/2, s/2)
							gl.Texture(false)
							gl.PopMatrix()
						end

						-- Draw filled triangle ring (fallback, if no texture)
						if not ring.texture and ring.fillColor then
							gl.Color(ring.fillColor)
							gl.BeginEnd(GL.TRIANGLE_FAN, function()
								gl.Vertex(ux, uy + 1, uz)
								for i = 0, ring.divs do
									local angle = (i / ring.divs) * 2 * math.pi
									local dx = math.cos(angle) * ring.radius
									local dz = math.sin(angle) * ring.radius
									gl.Vertex(ux + dx, uy + 1, uz + dz)
								end
							end)
						end

						-- Outline ring
						if ring.color and ring.radius then
							gl.Color(ring.color)
							gl.LineWidth(ring.lineWidth)
							gl.DrawGroundCircle(ux, uy, uz, ring.radius, ring.divs)
						end
					end
				end
			end
		end
	end

	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
end

function widget:GameFrame(n)
	if n % 90 == 0 then -- every 3 seconds (30fps)
		UpdateShowMode()
	end
end