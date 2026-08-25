function widget:GetInfo()
	return {
		name      = "Survival Beacon Labels",
		desc      = "Floating world-space labels over specialized Survival AI beacons (shield/jammer/accelerator/forge).",
		author    = "",
		date      = "2026",
		license   = "GNU GPL, v2 or later",
		layer     = 900,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local bgcorner = "LuaUI/Images/bgcorner.png"

local LABEL_Y_OFFSET = 70    -- elmos above the beacon's ground position
local CHIP_PAD_X     = 6
local CHIP_PAD_Y     = 4
local CHIP_CORNER    = 3
local FONT_SIZE      = 12    -- small-text atlas convention: 14/outline 1, sized down slightly for chips
local FONT_OUTLINE   = 1

-- How often (frames) to rescan GetVisibleUnits for the current beacon set.
-- Positions/labels are still redrawn every frame from this cache; only the
-- "which units exist" pass is throttled.
local SCAN_PERIOD  = 15
local GIVEUP_FRAME = 450   -- self-remove if the Survival gadget never appears

-- Off-screen guard: GetVisibleUnits should already frustum-cull, but the
-- cache can lag one scan period behind a fast camera cut, so skip anything
-- projected wildly outside the viewport rather than trust it blindly.
local OFFSCREEN_MARGIN = 200

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

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local glColor            = gl.Color
local glRect             = gl.Rect
local glTexture          = gl.Texture
local glTexRect          = gl.TexRect

local spGetVisibleUnits    = Spring.GetVisibleUnits
local spGetUnitDefID       = Spring.GetUnitDefID
local spGetUnitPosition    = Spring.GetUnitPosition
local spGetUnitRulesParam  = Spring.GetUnitRulesParam
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spGetViewGeometry    = Spring.GetViewGeometry
local spGetGameRulesParam  = Spring.GetGameRulesParam
local spIsGUIHidden        = Spring.IsGUIHidden
local spValidUnitID        = Spring.ValidUnitID

local floor = math.floor

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local vsx, vsy = spGetViewGeometry()
local beaconDefID = nil
local active = false

local beaconCache = {}   -- [unitID] = kind (specialized kinds only; standard/master excluded)

local fontfile = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("ui_font", "Saira_SemiCondensed-SemiBold.ttf")
local font = gl.LoadFont(fontfile, FONT_SIZE, FONT_OUTLINE, 1.4)

--------------------------------------------------------------------------------
-- Helpers
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

local function RescanBeacons()
	beaconCache = {}
	if not beaconDefID then return end

	local units = spGetVisibleUnits(-1, 30, true)
	if not units then return end

	for i = 1, #units do
		local uid = units[i]
		if spGetUnitDefID(uid) == beaconDefID then
			-- nil for beacons outside our LOS-granted access -- the same
			-- {inlos=true} restriction the gadget set the param with, so an
			-- enemy's specialization stays hidden without any extra logic here.
			local kind = spGetUnitRulesParam(uid, "survival_beacon_kind")
			if kind and KIND_COLOR[kind] then
				beaconCache[uid] = kind
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Widget lifecycle
--------------------------------------------------------------------------------

function widget:Initialize()
	local def = UnitDefNames["beacon"]
	if not def then
		Spring.Echo("[Survival Beacon Labels] no 'beacon' unitdef found; removing")
		widgetHandler:RemoveWidget()
		return
	end
	beaconDefID = def.id
end

function widget:Shutdown()
	if font then gl.DeleteFont(font) end
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
end

--------------------------------------------------------------------------------
-- Polling
--------------------------------------------------------------------------------

function widget:GameFrame(n)
	if not active then
		if (spGetGameRulesParam("survival_active")) == 1 then
			active = true
		elseif n > GIVEUP_FRAME then
			widgetHandler:RemoveWidget()   -- not a survival game
		end
		return
	end

	if n % SCAN_PERIOD == 0 then
		RescanBeacons()
	end
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------

function widget:DrawScreen()
	if not active or spIsGUIHidden() then return end

	font:Begin()
	for unitID, kind in pairs(beaconCache) do
		if spValidUnitID(unitID) then
			local x, y, z = spGetUnitPosition(unitID)
			if x then
				local sx, sy = spWorldToScreenCoords(x, y + LABEL_Y_OFFSET, z)
				if sx > -OFFSCREEN_MARGIN and sx < vsx + OFFSCREEN_MARGIN
					and sy > -OFFSCREEN_MARGIN and sy < vsy + OFFSCREEN_MARGIN then

					local color = KIND_COLOR[kind]
					local label = KIND_LABEL[kind]
					local textW = font:GetTextWidth(label) * FONT_SIZE

					local x1 = sx - textW * 0.5 - CHIP_PAD_X
					local x2 = sx + textW * 0.5 + CHIP_PAD_X
					local y1 = sy - CHIP_PAD_Y
					local y2 = sy + FONT_SIZE + CHIP_PAD_Y

					glColor(0.05, 0.05, 0.06, 0.75)
					RectFlat(x1, y1, x2, y2, CHIP_CORNER)

					glColor(color[1], color[2], color[3], 0.9)
					glRect(x1, y1, x2, y1 + 2)   -- thin accent underline

					font:SetTextColor(color[1], color[2], color[3], 1)
					font:Print(label, sx, sy, FONT_SIZE, "co")
				end
			end
		end
	end
	font:End()
end
