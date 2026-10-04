function gadget:GetInfo()
	return {
		name = "Auto TeamColor Picker",
		desc = "Automatically assigns colors to teams",
		author = "Damgam, Born2Crawl (original), generated palette rework 2026",
		date = "2021",
		license = "GNU GPL, v2 or later",
		layer = -100,
		enabled = true,
	}
end

if Spring.GetModOptions().autoteamcolors == "disabled" then
	return
end

local function hex2RGB(hex)
    hex = hex:gsub("#","")
    return {tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))}
end

-- Special colors
local armBlueColor       = "#004DFF" -- Armada Blue
local corRedColor        = "#FF1005" -- Cortex Red
local scavPurpColor      = "#6809A1" -- Scav Purple
local chickenOrangeColor = "#CC8914" -- Chicken Orange
local gaiaGrayColor      = "#000000" -- Gaia black

-- Palettes. Each one names the two main colors; everything else (further teams,
-- teammates) is generated around them. The order here is the order in the
-- options menu, so add new ones at the end.
--   hue        OKLCH hue in degrees: 29 red, 55 orange, 100 yellow, 142 green,
--              195 cyan, 264 blue, 305 purple, 330 magenta, 0 pink
--   lightness  main tone lightness (default 0.72). On an anchor it only affects
--              that team; on the palette it affects every team.
--   chroma     saturation cap (default 0.21), same scoping. Low values give
--              earthy colors: brown is a dark, low chroma orange.
local PALETTES = {
	{ name = "Purple vs Orange", a = { hue = 305 }, b = { hue = 55 } },
	{ name = "Red vs Blue",      a = { hue = 27 },  b = { hue = 258 }, lightness = 0.65, chroma = 0.25 },
	{ name = "Green vs Brown",   a = { hue = 145 }, b = { hue = 62, lightness = 0.56, chroma = 0.085 } },
	{ name = "Teal vs Pink",     a = { hue = 190 }, b = { hue = 352 } },
	{ name = "Gold vs Blue",     a = { hue = 92 },  b = { hue = 262 } },
	{ name = "Green vs Magenta", a = { hue = 142 }, b = { hue = 328 } },
}

-- Rules param names for one palette. Palette 1 keeps the original names.
local function paramNames(index)
	local suffix = (index == 1) and "" or tostring(index)
	return "AutoTeamColorRed" .. suffix, "AutoTeamColorGreen" .. suffix, "AutoTeamColorBlue" .. suffix
end

if gadgetHandler:IsSyncedCode() then

	---------------------------------------------------------------------------
	-- Generated palette
	--
	-- Colors are built in OKLCH (perceptual lightness / chroma / hue) instead of
	-- being picked from hand-written hex tables. Every team anchor sits at the
	-- same perceived lightness, so no team ends up bright while another is dark.
	--
	--   * Team hues: the first two are the palette's anchors. Further
	--     teams are spread through the rest of the hue wheel so the smallest gap
	--     between any two teams is as large as possible. Works for any count.
	--   * Player colors: each team owns a slice of the wheel around its hue.
	--     Players step through that slice first, then through lighter and deeper
	--     tints once the slice is used up. The more teams there are, the
	--     narrower the slice, and the more the tints carry the difference.
	--   * Per game: which team gets which hue is shuffled, and the whole wheel is
	--     nudged a few degrees, so matches do not always look identical.
	--
	-- OKLCH hue reference (degrees): 29 red, 55 orange, 100 yellow, 142 green,
	-- 195 cyan, 264 blue, 305 purple, 330 magenta, 0 pink.
	---------------------------------------------------------------------------
	local CFG = {
		-- Lightness tints, used in this order. The first is the main tone.
		tierLightness  = { 0.72, 0.83, 0.61 },
		maxChroma      = 0.21, -- saturation cap (each color is also clipped to what sRGB can show)

		-- Yellows only read as yellow when they are lighter than everything else
		-- (at the shared lightness they turn mustard), so hues near yellow get a lift.
		yellowHue      = 105,
		yellowWidth    = 40,   -- degrees either side that receive some of the lift
		yellowLift     = 0.13,

		familyReach    = 0.28, -- how far a team's slice reaches toward a neighboring team's hue (fraction of the gap)
		familyMaxReach = 55,   -- ...but never further than this many degrees per side
		minHueStep     = 20,   -- preferred minimum hue step between teammates
		slotStagger    = 0.035,-- small lightness offset on alternating teammates' hues
		packedStagger  = 0.055,-- same, when a team has to squeeze extra hues into a narrow slice

		crowdedGap     = 36,   -- if team hues get closer than this, neighboring teams also alternate tints

		shuffleTeams   = true, -- randomize which team gets which hue each game
		hueDrift       = 8,    -- random rotation of the whole wheel each game, in degrees (0 = off)
	}

	local mathCos, mathSin, mathFloor, mathMin, mathMax, mathRandom = math.cos, math.sin, math.floor, math.min, math.max, math.random
	local DEG2RAD = math.pi / 180

	-- OKLCH -> linear sRGB (unclamped)
	local function oklchToLinear(L, C, h)
		local a = C * mathCos(h * DEG2RAD)
		local b = C * mathSin(h * DEG2RAD)
		local l = L + 0.3963377774 * a + 0.2158037573 * b
		local m = L - 0.1055613458 * a - 0.0638541728 * b
		local s = L - 0.0894841775 * a - 1.2914855480 * b
		l, m, s = l * l * l, m * m * m, s * s * s
		return 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
			-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
			-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
	end

	local function inGamut(r, g, b)
		return r >= 0 and r <= 1 and g >= 0 and g <= 1 and b >= 0 and b <= 1
	end

	local function toByte(x)
		x = mathMin(1, mathMax(0, x))
		if x <= 0.0031308 then
			x = 12.92 * x
		else
			x = 1.055 * x ^ (1 / 2.4) - 0.055
		end
		return mathFloor(x * 255 + 0.5)
	end

	-- OKLCH -> sRGB bytes. Chroma is reduced until the color fits in sRGB, which
	-- keeps the requested lightness and hue intact.
	local function oklchToRGB(L, C, h)
		local d = math.abs(h - CFG.yellowHue) % 360
		if d > 180 then
			d = 360 - d
		end
		if d < CFG.yellowWidth then
			L = L + CFG.yellowLift * mathCos(d / CFG.yellowWidth * 90 * DEG2RAD)
		end
		L = mathMin(L, 0.95)
		local r, g, b = oklchToLinear(L, C, h)
		if not inGamut(r, g, b) then
			local lo, hi = 0, C
			for _ = 1, 16 do
				local mid = (lo + hi) * 0.5
				if inGamut(oklchToLinear(L, mid, h)) then
					lo = mid
				else
					hi = mid
				end
			end
			r, g, b = oklchToLinear(L, lo, h)
		end
		return toByte(r), toByte(g), toByte(b)
	end

	-- Team specs ({hue, dL, chroma}) for n teams. The two anchors stay fixed; the
	-- remaining teams are split between the two arcs separating them so the
	-- smallest gap is maximal.
	local function buildTeamHues(palette, n)
		local baseL = CFG.tierLightness[1]
		local function spec(hue, anchor)
			return {
				hue = hue % 360,
				dL = ((anchor and anchor.lightness) or palette.lightness or baseL) - baseL,
				chroma = (anchor and anchor.chroma) or palette.chroma or CFG.maxChroma,
			}
		end
		local hueA, hueB = palette.a.hue % 360, palette.b.hue % 360
		local hues = { spec(hueA, palette.a), spec(hueB, palette.b) }
		if n <= 2 then
			hues[n + 1] = nil
			return hues
		end
		local arcUp = (hueB - hueA) % 360 -- from A upward to B
		local arcDown = 360 - arcUp       -- from B upward to A
		local extra = n - 2
		local bestK, bestGap = 0, -1
		for k = 0, extra do -- k extra teams on arcUp, the rest on arcDown
			local gap = mathMin(arcUp / (k + 1), arcDown / (extra - k + 1))
			if gap > bestGap then
				bestK, bestGap = k, gap
			end
		end
		for j = 1, extra - bestK do
			hues[#hues + 1] = spec(hueB + arcDown * j / (extra - bestK + 1))
		end
		for j = 1, bestK do
			hues[#hues + 1] = spec(hueA + arcUp * j / (bestK + 1))
		end
		return hues
	end

	-- For every team: the gap to its lower and upper neighbor on the wheel, and
	-- its position in sorted order.
	local function describeHues(specs)
		local n = #specs
		local order, hues = {}, {}
		for i = 1, n do
			order[i] = i
			hues[i] = specs[i].hue
		end
		table.sort(order, function(a, b) return hues[a] < hues[b] end)
		local info = {}
		for pos = 1, n do
			local i = order[pos]
			local gapDown, gapUp = 360, 360
			if n > 1 then
				gapDown = (hues[i] - hues[order[(pos - 2) % n + 1]]) % 360
				gapUp = (hues[order[pos % n + 1]] - hues[i]) % 360
			end
			info[i] = { hue = hues[i], dL = specs[i].dL, chroma = specs[i].chroma, gapDown = gapDown, gapUp = gapUp, sortedPos = pos - 1 }
		end
		return info
	end

	-- Colors for one team of `count` players. Returns a list of {r, g, b}.
	local function buildFamily(team, count, crowded)
		local tiers = CFG.tierLightness
		local numTiers = #tiers
		local reachDown = mathMin(team.gapDown * CFG.familyReach, CFG.familyMaxReach)
		local reachUp = mathMin(team.gapUp * CFG.familyReach, CFG.familyMaxReach)

		-- How many distinct hues this team uses
		local maxDown = mathFloor(reachDown / CFG.minHueStep)
		local maxUp = mathFloor(reachUp / CFG.minHueStep)
		local hueCount = mathMin(count, 1 + maxDown + maxUp)
		local packed = false
		if hueCount * numTiers < count then
			-- Not enough hue/tint combinations at the preferred step: pack hues tighter
			hueCount = mathFloor((count + numTiers - 1) / numTiers)
			maxDown, maxUp = hueCount, hueCount
			packed = true
		end

		-- Split the extra hues between the two sides in proportion to the room there
		local numDown = mathFloor((hueCount - 1) * reachDown / (reachDown + reachUp) + 0.5)
		numDown = mathMin(numDown, maxDown)
		local numUp = hueCount - 1 - numDown
		if numUp > maxUp then
			numUp = maxUp
			numDown = hueCount - 1 - numUp
		end

		-- Hue slots: the team hue first, then alternating sides, nearest first
		local slots = { { hue = team.hue, stagger = 0 } }
		for j = 1, mathMax(numDown, numUp) do
			local stagger = (j % 2 == 1) and (packed and CFG.packedStagger or CFG.slotStagger) or 0
			if j <= numDown then
				slots[#slots + 1] = { hue = team.hue - reachDown * j / numDown, stagger = stagger }
			end
			if j <= numUp then
				slots[#slots + 1] = { hue = team.hue + reachUp * j / numUp, stagger = stagger }
			end
		end

		-- With many teams, neighbors on the wheel start on different tints
		local tierOffset = crowded and (team.sortedPos % numTiers) or 0

		local colors = {}
		for i = 0, count - 1 do
			-- Normally walk the hues first and the tints second. When hues are
			-- packed tight the tints are the stronger cue, so walk those first.
			local slotIndex, tierIndex = i % hueCount, mathFloor(i / hueCount)
			if packed then
				slotIndex, tierIndex = mathFloor(i / numTiers), i % numTiers
			end
			local slot = slots[slotIndex + 1]
			local tier = (tierIndex + tierOffset) % numTiers + 1
			local L = tiers[tier] + slot.stagger + team.dL
			local r, g, b = oklchToRGB(L, team.chroma, slot.hue % 360)
			colors[i + 1] = { r, g, b }
		end
		return colors
	end

	---------------------------------------------------------------------------
	-- Team setup
	---------------------------------------------------------------------------
	local gaiaTeamID = Spring.GetGaiaTeamID()
	local teamList = Spring.GetTeamList()

	local function setColor(paletteIndex, teamID, r, g, b)
		local nameR, nameG, nameB = paramNames(paletteIndex)
		Spring.SetTeamRulesParam(teamID, nameR, r)
		Spring.SetTeamRulesParam(teamID, nameG, g)
		Spring.SetTeamRulesParam(teamID, nameB, b)
	end

	-- Fixed colors are the same in every palette
	local function setHexColor(teamID, hex)
		local rgb = hex2RGB(hex)
		for paletteIndex = 1, #PALETTES do
			setColor(paletteIndex, teamID, rgb[1], rgb[2], rgb[3])
		end
	end

	-- Fixed colors first; everything else is grouped by allyteam
	local allyOrder = {}   -- allyTeamIDs in order of first appearance
	local allyMembers = {} -- allyTeamID -> list of teamIDs
	local playerTeamCount = 0
	for i = 1, #teamList do
		local teamID = teamList[i]
		local luaAI = Spring.GetTeamLuaAI(teamID)
		if teamID == gaiaTeamID then
			setHexColor(teamID, gaiaGrayColor)
		elseif luaAI and string.find(luaAI, "Scavenger") then
			setHexColor(teamID, scavPurpColor)
		elseif luaAI and string.find(luaAI, "Chicken") then
			setHexColor(teamID, chickenOrangeColor)
		else
			local allyTeamID = select(6, Spring.GetTeamInfo(teamID, false))
			if not allyMembers[allyTeamID] then
				allyMembers[allyTeamID] = {}
				allyOrder[#allyOrder + 1] = allyTeamID
			end
			local members = allyMembers[allyTeamID]
			members[#members + 1] = teamID
			playerTeamCount = playerTeamCount + 1
		end
	end

	if playerTeamCount > 0 then
		-- Everyone on a single allyteam (co-op against a fixed-color AI, sandbox):
		-- there is no enemy family to stay clear of, so give every player their
		-- own hue as if it were a free-for-all.
		local groups = {}
		if #allyOrder == 1 then
			local members = allyMembers[allyOrder[1]]
			for i = 1, #members do
				groups[i] = { members[i] }
			end
		else
			for i = 1, #allyOrder do
				groups[i] = allyMembers[allyOrder[i]]
			end
		end

		local numGroups = #groups

		-- Per-game variation. Synced random, so every client agrees. Rolled once
		-- and shared by all palettes, so switching palette keeps the same layout.
		local shuffle = {}
		for i = 1, numGroups do
			shuffle[i] = i
		end
		if CFG.shuffleTeams then
			for i = numGroups, 2, -1 do
				local j = mathRandom(1, i)
				shuffle[i], shuffle[j] = shuffle[j], shuffle[i]
			end
		end
		local drift = 0
		if CFG.hueDrift > 0 then
			drift = (mathRandom() * 2 - 1) * CFG.hueDrift
		end

		for paletteIndex = 1, #PALETTES do
			local base = buildTeamHues(PALETTES[paletteIndex], numGroups)
			local specs = {}
			for i = 1, numGroups do
				local src = base[shuffle[i]]
				specs[i] = { hue = (src.hue + drift) % 360, dL = src.dL, chroma = src.chroma }
			end

			local info = describeHues(specs)
			local crowded = false
			for i = 1, numGroups do
				if mathMin(info[i].gapDown, info[i].gapUp) < CFG.crowdedGap then
					crowded = true
				end
			end

			for i = 1, numGroups do
				local members = groups[i]
				local colors = buildFamily(info[i], #members, crowded)
				for p = 1, #members do
					setColor(paletteIndex, members[p], colors[p][1], colors[p][2], colors[p][3])
				end
			end
		end
	end


else	-- UNSYNCED


	local anonymousMode = false --Spring.GetModOptions().teamcolors_anonymous_mode

	local iconDevModeColors = {
		armblue       = armBlueColor,
		corred        = corRedColor,
		scavpurp      = scavPurpColor,
		chickenorange = chickenOrangeColor,
		gaiagray      = gaiaGrayColor,
	}
	local iconDevMode = "no" --Spring.GetModOptions().teamcolors_icon_dev_mode
	local iconDevModeColor = iconDevModeColors[iconDevMode]

	local gaiaTeamID = Spring.GetGaiaTeamID()
	local teamList = Spring.GetTeamList()

	-- Per-player toggle (options menu). Off by default: teams keep the colors
	-- they were given in the lobby. The synced half always publishes the
	-- generated palette, so switching this on mid-game needs nothing synced.
	local ENABLE_CONFIG = "AutoTeamColors"
	local RELOAD_UI_ON_TOGGLE = true -- widgets cache team colors, so reload LuaUI after a live switch
	local PALETTE_CONFIG = "AutoTeamColorsPalette" -- 1-based index into PALETTES
	local autoEnabled = Spring.GetConfigInt(ENABLE_CONFIG, 0) == 1

	local function readPalette()
		local index = Spring.GetConfigInt(PALETTE_CONFIG, 1)
		if not PALETTES[index] then
			index = 1
		end
		return index
	end
	local paletteIndex = readPalette()

	local function updateTeamColors()
		local myTeamID = Spring.GetMyTeamID()
		local myAllyTeamID = Spring.GetMyAllyTeamID()
		for i = 1, #teamList do
			local teamID = teamList[i]
			local r, g, b
			if autoEnabled then
				local nameR, nameG, nameB = paramNames(paletteIndex)
				r = (Spring.GetTeamRulesParam(teamID, nameR))
				g = (Spring.GetTeamRulesParam(teamID, nameG))
				b = (Spring.GetTeamRulesParam(teamID, nameB))
			end
			if r and g and b then
				r, g, b = r / 255, g / 255, b / 255
			else
				r, g, b = Spring.GetTeamOrigColor(teamID)
			end

			if iconDevModeColor then
				Spring.SetTeamColor(teamID, hex2RGB(iconDevModeColor)[1]/255, hex2RGB(iconDevModeColor)[2]/255, hex2RGB(iconDevModeColor)[3]/255)
			elseif Spring.GetConfigInt("SimpleTeamColors", 0) == 1 or (anonymousMode and not Spring.GetSpectatingState()) then
				local allyTeamID = select(6, Spring.GetTeamInfo(teamID))
				if teamID == myTeamID then
					Spring.SetTeamColor(teamID,
						Spring.GetConfigInt("SimpleTeamColorsPlayerR", 0)/255,
						Spring.GetConfigInt("SimpleTeamColorsPlayerG", 77)/255,
						Spring.GetConfigInt("SimpleTeamColorsPlayerB", 255)/255)
				elseif allyTeamID == myAllyTeamID then
					Spring.SetTeamColor(teamID,
						Spring.GetConfigInt("SimpleTeamColorsAllyR", 0)/255,
						Spring.GetConfigInt("SimpleTeamColorsAllyG", 255)/255,
						Spring.GetConfigInt("SimpleTeamColorsAllyB", 0)/255)
				elseif allyTeamID ~= myAllyTeamID and teamID ~= gaiaTeamID then
					Spring.SetTeamColor(teamID,
						Spring.GetConfigInt("SimpleTeamColorsEnemyR", 255)/255,
						Spring.GetConfigInt("SimpleTeamColorsEnemyG", 16)/255,
						Spring.GetConfigInt("SimpleTeamColorsEnemyB", 5)/255)
				else
					Spring.SetTeamColor(teamID, hex2RGB(gaiaGrayColor)[1]/255, hex2RGB(gaiaGrayColor)[2]/255, hex2RGB(gaiaGrayColor)[3]/255)
				end
			else
				Spring.SetTeamColor(teamID, r, g, b)
			end
		end
	end
	updateTeamColors()

	function gadget:Update()
		local enabledNow = Spring.GetConfigInt(ENABLE_CONFIG, 0) == 1
		local paletteNow = readPalette()
		if enabledNow ~= autoEnabled or (enabledNow and paletteNow ~= paletteIndex) then
			autoEnabled = enabledNow
			paletteIndex = paletteNow
			updateTeamColors()
			if RELOAD_UI_ON_TOGGLE then
				Spring.SendCommands("luarules reloadluaui")
			end
		elseif math.random(0,60) == 0 then
			updateTeamColors()
		elseif Spring.GetConfigInt("UpdateTeamColors", 0) == 1 then
			updateTeamColors()
			Spring.SetConfigInt("UpdateTeamColors", 0)
			Spring.SetConfigInt("SimpleTeamColors_Reset", 0)
		end
	end
end
