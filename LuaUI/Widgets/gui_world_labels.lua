function widget:GetInfo()
	return {
		name      = "World Labels",
		desc      = "Floating world-space chips: commander name tags and Survival AI beacon kind labels.",
		author    = "Scary le Poo",
		date      = "2026",
		license   = "GNU GPL, v2 or later",
		layer     = 900,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- Overview
--
-- One renderer, several label "sources". A source claims a unitDefID and, for a
-- unit of that def, produces a label table {text, color, yOffset}. The renderer
-- never knows what a beacon or a commander is.
--
-- Sources are consulted in priority order. The first source that claims a def
-- owns every unit of that def, even if it then decides that particular unit
-- gets no label (e.g. a standard Survival beacon). This is what stops a beacon,
-- which is also a commander, from getting both a kind chip and a name tag.
--
-- Replaces gui_survival_beacon_labels.lua and gui_com_nametags.lua.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local bgcorner = "LuaUI/Images/bgcorner.png"

local CHIP_PAD_X     = 6
local CHIP_PAD_Y     = 4
local CHIP_CORNER    = 3
local FONT_SIZE      = 12    -- small-text atlas convention, sized down slightly for chips
local FONT_OUTLINE   = 1

-- Seconds between rescans of GetVisibleUnits. Positions are still projected
-- every frame from the cache; only "which units are on screen" is throttled.
-- Time-based rather than GameFrame-based so tags appear during pre-game
-- placement (frame 0) and the cache stays live while paused.
local SCAN_INTERVAL = 0.5

-- The beacon source stays dormant (never removes the widget) until the
-- Survival gadget announces itself; stop polling for it after this frame.
local SURVIVAL_GIVEUP_FRAME = 450

-- Off-screen guard: GetVisibleUnits should already frustum-cull, but the
-- cache can lag one scan period behind a fast camera cut, so skip anything
-- projected wildly outside the viewport rather than trust it blindly.
local OFFSCREEN_MARGIN = 200

-- Beacon labels
local BEACON_Y_OFFSET = 70
local KIND_COLOR = {
	shield      = {0.30, 0.55, 0.95, 1},   -- blue
	jammer      = {0.62, 0.40, 0.90, 1},   -- purple
	accelerator = {0.95, 0.85, 0.20, 1},   -- yellow
	forge       = {0.92, 0.45, 0.18, 1},   -- orange
}
local KIND_LABEL = {
	shield      = "SHIELD",
	jammer      = "JAMMER",
	accelerator = "ACCEL",
	forge       = "FORGE",
}

-- Commander tags sit *below* the model (the space above is taken by health
-- bars and the tech button). The anchor is the front edge of the unit's
-- footprint as seen from the camera: unit position, stepped `radius` elmos
-- along the ground away from the camera's facing, then projected. This
-- keeps the chip just under the silhouette at any camera tilt.
local COMMANDER_BELOW_GAP = 4      -- px between the footprint edge and the chip's top
local COMMANDER_RADIUS_MULT = 1.0  -- >1 pushes the chip further out from the model

-- When gui_tech_upgrade_button.lua is showing a button on the same unit, the
-- chip stacks this many pixels above the button's top edge (or above the
-- healthbar's top edge when there is no button) instead of using the world
-- anchor. The button is screen-space and fixed-size, so a pure
-- world offset collides with it at most zoom levels.
local STACK_GAP = 4

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local glColor   = gl.Color
local glRect    = gl.Rect
local glTexture = gl.Texture
local glTexRect = gl.TexRect

local spGetVisibleUnits     = Spring.GetVisibleUnits
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitTeam         = Spring.GetUnitTeam
local spGetUnitPosition     = Spring.GetUnitPosition
local spGetUnitRulesParam   = Spring.GetUnitRulesParam
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spGetViewGeometry     = Spring.GetViewGeometry
local spGetGameRulesParam   = Spring.GetGameRulesParam
local spGetGameFrame        = Spring.GetGameFrame
local spIsGUIHidden         = Spring.IsGUIHidden
local spValidUnitID         = Spring.ValidUnitID
local spGetTeamInfo         = Spring.GetTeamInfo
local spGetTeamColor        = Spring.GetTeamColor
local spGetTeamLuaAI        = Spring.GetTeamLuaAI
local spGetAIInfo           = Spring.GetAIInfo
local spGetPlayerList       = Spring.GetPlayerList
local spGetPlayerInfo       = Spring.GetPlayerInfo
local spGetGaiaTeamID       = Spring.GetGaiaTeamID
local spGetCameraVectors    = Spring.GetCameraVectors
local spGetGroundHeight     = Spring.GetGroundHeight

local floor = math.floor
local sqrt  = math.sqrt

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local vsx, vsy = spGetViewGeometry()
local gaiaTeamID = spGetGaiaTeamID()

-- Own-team tag suppression: you know which commander is yours, and the tag
-- just adds clutter under your own unit. Spectators keep tags on everyone.
-- Refreshed in PlayerChanged (covers /take, team switch, becoming a spec).
local SHOW_OWN_COMMANDER_TAG = false
local myTeamID    = Spring.GetMyTeamID()
local isSpectator = Spring.GetSpectatingState()

local font = nil
local scanTimer = 0

-- Persisted settings
local showCommanderTags = true
local showBeaconLabels  = true

-- [unitID] = label table {text=, color=, yOffset=} for every unit currently
-- on screen that some source gave a label. Rebuilt on every rescan.
local labelCache = {}

-- Beacon source state
local beaconDefID    = nil
local survivalActive = false
local beaconLabels   = {}   -- [kind] = prebuilt label table (immutable, shared)
for kind, color in pairs(KIND_COLOR) do
	beaconLabels[kind] = { text = KIND_LABEL[kind], color = color, yOffset = BEACON_Y_OFFSET }
end

-- Commander source state
local comDefs    = {}   -- [unitDefID] = true
local teamLabels = {}   -- [teamID] = label table; wiped whenever names/colors may change

--------------------------------------------------------------------------------
-- Commander source
--------------------------------------------------------------------------------

-- customParams arrive as strings at runtime, so a Lua `false` in the def file
-- becomes "false" and `0` becomes "0". Compare as strings; accept real
-- booleans too in case a def loader ever hands one through untouched.
local function ShowNameTag(cp)
	local v = cp.shownametag
	if v == nil then return true end
	v = tostring(v):lower()
	return not (v == "0" or v == "false")
end

local function BuildComDefs()
	comDefs = {}
	for unitDefID, def in pairs(UnitDefs) do
		local cp = def.customParams
		if cp and cp.iscommander and ShowNameTag(cp) then
			comDefs[unitDefID] = true
		end
	end
end

local function TeamName(teamID)
	local _, leaderID, _, isAI = spGetTeamInfo(teamID, false)

	if isAI then
		-- Lua AIs: the name the lobby and player list already show.
		local luaAI = spGetTeamLuaAI(teamID)
		if luaAI and luaAI ~= "" then
			return luaAI
		end
		-- Skirmish AIs (non-Lua): shortName from the AI info block.
		if spGetAIInfo then
			local _, aiName, _, shortName = spGetAIInfo(teamID)
			if shortName and shortName ~= "" then return shortName end
			if aiName and aiName ~= "" then return aiName end
		end
		return "AI"
	end

	-- Human team: prefer an active, non-spectating player; otherwise the leader.
	local players = spGetPlayerList(teamID)
	if players then
		for i = 1, #players do
			local pname, active, isSpec = spGetPlayerInfo(players[i], false)
			if pname and active and not isSpec then
				return pname
			end
		end
	end
	if leaderID and leaderID >= 0 then
		local pname = spGetPlayerInfo(leaderID, false)
		if pname then return pname end
	end
	return "------"
end

local function CommanderLabel(unitID, unitDefID)
	local teamID = spGetUnitTeam(unitID)
	if teamID == nil or teamID == gaiaTeamID then return nil end

	-- No tag on my own commander (unless spectating, where "my team" is just
	-- the one being viewed and every tag is wanted).
	if not SHOW_OWN_COMMANDER_TAG and not isSpectator and teamID == myTeamID then
		return nil
	end

	local label = teamLabels[teamID]
	if not label then
		local r, g, b = spGetTeamColor(teamID)
		label = {
			text    = TeamName(teamID),
			color   = { r or 1, g or 1, b or 1, 1 },
		}
		teamLabels[teamID] = label
	end

	-- Different commander defs on the same team can have different footprints,
	-- so the geometry lives on a thin per-unit wrapper, not the shared entry.
	local ud = UnitDefs[unitDefID]
	return {
		text    = label.text,
		color   = label.color,
		yOffset = 0,
		below   = true,
		radius  = (ud.radius or 0) * COMMANDER_RADIUS_MULT,
	}
end

local function InvalidateTeamLabels()
	teamLabels = {}
	scanTimer = SCAN_INTERVAL   -- force a rescan on the next Update
end

--------------------------------------------------------------------------------
-- Beacon source
--------------------------------------------------------------------------------

local function BeaconLabel(unitID)
	-- nil for beacons outside our LOS-granted access -- the same {inlos=true}
	-- restriction the gadget set the param with, so an enemy's specialization
	-- stays hidden without any extra logic here. Standard/master beacons have
	-- a kind without a color entry and get no chip at all.
	local kind = spGetUnitRulesParam(unitID, "survival_beacon_kind")
	if kind then
		return beaconLabels[kind]
	end
	return nil
end

--------------------------------------------------------------------------------
-- Source registry (priority order)
--------------------------------------------------------------------------------

-- Each source: claims(unitDefID) -> bool, label(unitID, unitDefID) -> table|nil,
-- enabled() -> bool. First claiming source owns the unit.
local sources = {
	{
		name    = "beacon",
		enabled = function() return showBeaconLabels and survivalActive end,
		claims  = function(unitDefID) return unitDefID == beaconDefID end,
		label   = BeaconLabel,
	},
	{
		name    = "commander",
		enabled = function() return showCommanderTags end,
		claims  = function(unitDefID) return comDefs[unitDefID] == true end,
		label   = CommanderLabel,
	},
}

-- Decide which source owns a unit and what label (if any) it gets. Returns the
-- label table or nil. Ownership is decided on claims() alone so a disabled
-- owner still blocks lower-priority sources; that is the intended behavior
-- (hiding beacon chips should not suddenly reveal name tags on beacons).
local function ResolveLabel(unitID, unitDefID)
	for i = 1, #sources do
		local src = sources[i]
		if src.claims(unitDefID) then
			if src.enabled() then
				return src.label(unitID, unitDefID)
			end
			return nil
		end
	end
	return nil
end

local function Rescan()
	labelCache = {}
	local units = spGetVisibleUnits(-1, 30, true)
	if not units then return end

	for i = 1, #units do
		local unitID = units[i]
		local unitDefID = spGetUnitDefID(unitID)
		if unitDefID then
			local label = ResolveLabel(unitID, unitDefID)
			if label then
				labelCache[unitID] = label
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

local function RectFlat(px, py, sx, sy, cs)
	px, py, sx, sy, cs = floor(px), floor(py), floor(sx), floor(sy), floor(cs)

	glRect(px + cs, py, sx - cs, sy)
	glRect(sx - cs, py + cs, sx, sy - cs)
	glRect(px, py + cs, px + cs, sy - cs)

	glTexture(bgcorner)
	glTexRect(px, py + cs, px + cs, py)
	glTexRect(sx, py + cs, sx - cs, py)
	glTexRect(px, sy - cs, px + cs, sy)
	glTexRect(sx, sy - cs, sx - cs, sy)
	glTexture(false)
end

local function DrawChip(sx, sy, label)
	local color = label.color
	local textW = font:GetTextWidth(label.text) * FONT_SIZE

	local x1 = sx - textW * 0.5 - CHIP_PAD_X
	local x2 = sx + textW * 0.5 + CHIP_PAD_X
	local y1 = sy - CHIP_PAD_Y
	local y2 = sy + FONT_SIZE + CHIP_PAD_Y

	glColor(0.05, 0.05, 0.06, 0.75)
	RectFlat(x1, y1, x2, y2, CHIP_CORNER)

	glColor(color[1], color[2], color[3], 0.9)
	glRect(x1, y1, x2, y1 + 2)   -- thin accent underline

	font:SetTextColor(color[1], color[2], color[3], 1)
	font:Print(label.text, sx, sy, FONT_SIZE, "co")
end

-- Screen anchor for a unit's chip. Labels flagged `below` hang under the
-- model's footprint. Otherwise: sit just above the tech upgrade button's rect
-- if it's drawing on this unit, else above the healthbar top, else project the
-- label's world offset. Returns sx, sy or nil when the unit can't be placed.
local function ChipAnchor(unitID, label)
	if label.below then
		local x, y, z = spGetUnitPosition(unitID)
		if not x then return nil end
		-- Horizontal direction from the unit toward the camera = -forward.xz.
		local fwd = spGetCameraVectors().forward
		local dx, dz = -fwd[1], -fwd[3]
		local len = sqrt(dx * dx + dz * dz)
		if len > 0.001 then
			dx, dz = dx / len * label.radius, dz / len * label.radius
		else
			dx, dz = 0, 0   -- looking straight down: footprint edge is ambiguous, use the center
		end
		local ax, az = x + dx, z + dz
		local ay = spGetGroundHeight(ax, az) or y
		local sx, sy = spWorldToScreenCoords(ax, ay, az)
		-- Chip occupies [sy - CHIP_PAD_Y, sy + FONT_SIZE + CHIP_PAD_Y]; put its top edge GAP below the anchor.
		return sx, sy - COMMANDER_BELOW_GAP - FONT_SIZE - CHIP_PAD_Y
	end

	local btn = WG.TechUpgradeButton
	if btn then
		local r = btn.getRect(unitID)
		if r then
			-- rect = {x1, y1, x2, y2, ...}; chip baseline sits CHIP_PAD_Y above
			-- its own bottom edge, so add that back to keep a clean STACK_GAP.
			return (r[1] + r[3]) * 0.5, r[4] + STACK_GAP + CHIP_PAD_Y
		end
	end
	local x, y, z = spGetUnitPosition(unitID)
	if not x then return nil end
	local sx, sy = spWorldToScreenCoords(x, y + label.yOffset, z)
	-- No button, but healthbars: stay above them (same world-vs-pixel issue).
	local hb = WG.healthbars
	if hb and hb.getBarTopScreenPos then
		local _, barTop = hb.getBarTopScreenPos(unitID)
		if barTop and barTop + STACK_GAP + CHIP_PAD_Y > sy then
			sy = barTop + STACK_GAP + CHIP_PAD_Y
		end
	end
	return sx, sy
end

function widget:DrawScreen()
	if spIsGUIHidden() or not font then return end
	if next(labelCache) == nil then return end

	font:Begin()
	for unitID, label in pairs(labelCache) do
		if spValidUnitID(unitID) then
			local sx, sy = ChipAnchor(unitID, label)
			if sx and sx > -OFFSCREEN_MARGIN and sx < vsx + OFFSCREEN_MARGIN
				and sy > -OFFSCREEN_MARGIN and sy < vsy + OFFSCREEN_MARGIN then
				DrawChip(sx, sy, label)
			end
		end
	end
	font:End()
end

--------------------------------------------------------------------------------
-- Widget lifecycle
--------------------------------------------------------------------------------

function widget:Initialize()
	local fontfile = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("ui_font", "Saira_SemiCondensed-SemiBold.ttf")
	font = gl.LoadFont(fontfile, FONT_SIZE, FONT_OUTLINE, 1.4)

	BuildComDefs()

	local def = UnitDefNames["beacon"]
	if def then
		beaconDefID = def.id
	end

	WG.WorldLabels = {
		setCommanderTags = function(value) showCommanderTags = (value and true or false); scanTimer = SCAN_INTERVAL end,
		getCommanderTags = function() return showCommanderTags end,
		setBeaconLabels  = function(value) showBeaconLabels  = (value and true or false); scanTimer = SCAN_INTERVAL end,
		getBeaconLabels  = function() return showBeaconLabels end,
		getLabel         = function(unitID) return labelCache[unitID] end,
		rescan           = Rescan,
	}

	Rescan()
end

function widget:Shutdown()
	if font then gl.DeleteFont(font); font = nil end
	WG.WorldLabels = nil
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
end

function widget:Update(dt)
	if not survivalActive and beaconDefID then
		local frame = spGetGameFrame()
		if frame <= SURVIVAL_GIVEUP_FRAME then
			if (spGetGameRulesParam("survival_active")) == 1 then
				survivalActive = true
				scanTimer = SCAN_INTERVAL
			end
		end
	end

	scanTimer = scanTimer + dt
	if scanTimer >= SCAN_INTERVAL then
		scanTimer = 0
		Rescan()
	end
end

-- Anything that can change a team's displayed name or color wipes the
-- per-team cache; the next rescan rebuilds only what is on screen.
function widget:PlayerChanged(playerID)
	-- Our own team/spectator state can change here too (/spectator, /take,
	-- team switch); the forced rescan below re-applies the own-tag skip.
	myTeamID    = Spring.GetMyTeamID()
	isSpectator = Spring.GetSpectatingState()
	InvalidateTeamLabels()
end

function widget:TeamChanged(teamID)
	InvalidateTeamLabels()
end

function widget:TeamDied(teamID)
	InvalidateTeamLabels()
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	labelCache[unitID] = nil
	scanTimer = SCAN_INTERVAL
end

function widget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	labelCache[unitID] = nil
	scanTimer = SCAN_INTERVAL
end

function widget:UnitDestroyed(unitID)
	labelCache[unitID] = nil
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

function widget:GetConfigData()
	return {
		showCommanderTags = showCommanderTags,
		showBeaconLabels  = showBeaconLabels,
	}
end

function widget:SetConfigData(data)
	if type(data) ~= "table" then return end
	if data.showCommanderTags ~= nil then showCommanderTags = data.showCommanderTags end
	if data.showBeaconLabels  ~= nil then showBeaconLabels  = data.showBeaconLabels  end
end
