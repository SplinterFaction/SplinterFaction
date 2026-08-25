function widget:GetInfo()
	return {
		name    = "Tech Upgrade Button",
		desc    = "World-anchored upgrade button on your EM converters and commander. Mirrors the order-panel Upgrade command from unit_morph.lua; click to start the morph.",
		author  = "Scary le Poo",
		date    = "2026-08-24",
		license = "GNU GPL, v2 or later",
		layer   = 50,          -- above healthbars, below panels
		enabled = true,
	}
end

--------------------------------------------------------------------------------
--
-- HOW IT WORKS
--
-- unit_morph.lua inserts a real command description on every unit that has a
-- morphdef. The command id is assigned at gadget load (CMD_MORPH + n, n being
-- the global morphdef index), so this widget never hard-codes an id. Instead
-- it scans each extractor's cmdDescs for the first id inside the morph range
-- and mirrors it: same disabled state, same tooltip, same order.
--
-- The button is drawn in DrawScreen through the Static GUI shapes module
-- (WG.StaticGUI). Each extractor's anchor point is projected with
-- Spring.WorldToScreenCoords every frame; the resulting rects are cached so
-- MousePress can hit-test them. A click issues GiveOrderToUnit with the
-- mirrored cmdID. The gadget's AllowCommand / CommandFallback / StartMorph do
-- the real work (tech check, RP spend, team message when short), so nothing
-- here is authoritative.
--
-- Progress: while a morph runs the gadget broadcasts Script.LuaUI.MorphUpdate
-- every frame with {progress, into} per morphing unit. The button stays on
-- screen during the morph with a progress ring around the icon and a
-- percentage in place of the cost; clicks on it are consumed but do nothing.
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Tunables
--------------------------------------------------------------------------------

-- Morph command range, mirrored from unit_morph.lua:
--   CMD_MORPH = 31410 (+n per morphdef), CMD_MORPH_STOP = 32410 (+n),
--   CMD_MORPH_PAUSE = 33410, CMD_MORPH_QUEUE = 34410.
-- STOP begins 1000 above MORPH, so the morph range is [31410, 32410).
local CMD_MORPH_FIRST = 31410
local CMD_MORPH_LAST  = 32409
local CMD_MORPH_QUEUE = 34410

local RP_RULES_PARAM  = "researchPoints"   -- game_researchpoints_ledger.lua

local RESCAN_FRAMES   = 15       -- how often the visible-mex set and RP are refreshed
local MAX_CAM_HEIGHT  = 2600     -- hide all buttons when the camera is higher than this above ground
local ANCHOR_LIFT     = 22       -- elmos above the unit's top to place the button
local BAR_STACK_GAP   = 3        -- px between the healthbar's top edge and the button's bottom

local BTN_W, BTN_H    = 96, 34   -- button size in pixels (tall enough for the ring)
local ICON_SIZE       = 24       -- unit picture inside the button
local PAD             = 5
local RADIUS          = 5
local BORDER          = 1.5
local FONT_SIZE       = 14

local FONT_FILE       = "fonts/Saira_SemiCondensed-SemiBold.ttf"

-- Colours (r, g, b, a)
local COL_BG          = { 0.06, 0.07, 0.09, 0.88 }
local COL_BG_HOVER    = { 0.12, 0.14, 0.18, 0.94 }
local COL_BORDER      = { 0.55, 0.60, 0.68, 0.90 }
local COL_BORDER_HOT  = { 1.00, 1.00, 1.00, 1.00 }
local COL_BORDER_GREY = { 0.35, 0.35, 0.38, 0.70 }
local COL_ICON        = { 1, 1, 1, 1 }
local COL_ICON_GREY   = { 0.5, 0.5, 0.5, 0.6 }
local COL_RP          = { 190/255, 120/255, 1, 1 }   -- violet, matches ResearchStr in unit_morph.lua
local COL_RP_GREY     = { 190/255, 120/255, 1, 0.45 }
local COL_RING_BG     = { 0.30, 0.32, 0.36, 0.80 }
local COL_RING        = { 190/255, 120/255, 1, 1 }
local RING_WIDTH      = 2.5
local RING_PAD        = 3        -- gap between icon edge and ring
local RING_SEGMENTS   = 32       -- segments for a full circle

--------------------------------------------------------------------------------
-- Engine locals
--------------------------------------------------------------------------------

local spGetVisibleUnits       = Spring.GetVisibleUnits
local spGetUnitDefID          = Spring.GetUnitDefID
local spGetUnitPosition       = Spring.GetUnitPosition
local spGetUnitCmdDescs       = Spring.GetUnitCmdDescs
local spGetUnitIsBeingBuilt   = Spring.GetUnitIsBeingBuilt
local spWorldToScreenCoords   = Spring.WorldToScreenCoords
local spGiveOrderToUnit       = Spring.GiveOrderToUnit
local spGiveOrderToUnitArray  = Spring.GiveOrderToUnitArray
local spGetMyTeamID           = Spring.GetMyTeamID
local spGetSpectatingState    = Spring.GetSpectatingState
local spGetTeamRulesParam     = Spring.GetTeamRulesParam
local spGetCameraPosition     = Spring.GetCameraPosition
local spGetGroundHeight       = Spring.GetGroundHeight
local spGetGameFrame          = Spring.GetGameFrame
local spGetModKeyState        = Spring.GetModKeyState
local spGetViewGeometry       = Spring.GetViewGeometry
local spEcho                  = Spring.Echo

local glLoadFont              = gl.LoadFont
local glDeleteFont            = gl.DeleteFont

local mathFloor               = math.floor
local mathMax                 = math.max
local mathSin                 = math.sin
local mathCos                 = math.cos
local mathPi                  = math.pi
local tableSort               = table.sort
local strMatch                = string.match
local strFormat               = string.format

--------------------------------------------------------------------------------
-- State. Kept in a handful of tables so the file stays well under the Lua 5.1
-- 200-local limit no matter how it grows.
--------------------------------------------------------------------------------

local SG            = nil            -- WG.StaticGUI, resolved lazily
local font          = nil            -- SG-wrapped font
local vsx, vsy      = 1, 1

local myTeamID      = 0
local isSpec        = false
local rpBalance     = 0
local camTooHigh    = false
local lastRescan    = -1

-- morphing[unitID] = progress (0..1), fed by MorphStart / MorphUpdate,
-- cleared by MorphStop / MorphFinished / UnitDestroyed.
local morphing      = {}

-- mexes[unitID] = { cmdID, rp, tex, tooltip, lift, hidden, morphing }
--   cmdID   : morph command id mirrored from the unit's cmdDescs
--   rp      : research cost (number, may be 0)
--   tex     : texture name for the icon ("#<unitDefID>" of the morph target)
--   tooltip : gadget-authored tooltip, forwarded to widget:GetTooltip
--   lift    : world-space Y offset above the unit's position
--   hidden  : true after a click, until the gadget confirms via MorphStart
--   morphing: true while the gadget reports the unit mid-morph
local mexes         = {}
local mexList       = {}             -- array of unitIDs for deterministic iteration

-- rects[unitID] = { x1, y1, x2, y2, affordable } rebuilt every DrawScreen
local rects         = {}
local rectList      = {}
local hoverID       = nil

-- Per-unitDefID info cache: { isMex, rp, tex, lift }
local defInfo       = {}

--------------------------------------------------------------------------------
-- Static data
--------------------------------------------------------------------------------

local function Flag(v)
	return (v == true) or (v == "true") or (v == "1") or (v == 1)
end

-- Everything this widget needs to know about a unit type. `rp` and `tex`
-- come from the customParams unit_morph.lua reads (morphdef__research,
-- morphdef__into); if a unit uses gamedata/morph_defs.lua instead, the
-- tooltip parse in ScanUnit fills them in.
local function GetDefInfo(unitDefID)
	local info = defInfo[unitDefID]
	if info then return info end

	local ud = UnitDefs[unitDefID]
	info = { isMex = false, rp = nil, tex = nil, lift = 0 }
	if ud then
		local cp = ud.customParams or {}
		-- Which units get a button. customParams arrive as strings at runtime
		-- ("true" / "1"), so compare loosely.
		--   metal_extractor : SF's EM Converters (they don't extractsMetal)
		--   iscommander     : commander tech morphs (T1 -> T2 -> T3 -> T4)
		--   func == "tech"  : same test unit_morph.lua uses for tech units
		--   upgrade_button  : explicit opt-in for anything else
		info.isMex = Flag(cp.metal_extractor) or Flag(cp.iscommander)
		              or (cp.func == "tech") or Flag(cp.upgrade_button)
		              or ((ud.extractsMetal or 0) > 0)
		info.rp = tonumber(cp.morphdef__research)
		if cp.morphdef__into then
			local into = UnitDefNames[cp.morphdef__into]
			if into then
				info.tex = "#" .. into.id
			end
		end
		-- Sit the button above the model: height is authored per unitdef,
		-- radius is a fallback for models without a sensible height.
		info.lift = mathMax(ud.height or 0, (ud.radius or 0) * 0.8) + ANCHOR_LIFT
	end
	defInfo[unitDefID] = info
	return info
end

--------------------------------------------------------------------------------
-- Scanning
--------------------------------------------------------------------------------

-- Parses the RP cost out of a gadget tooltip ("research: 400"). Colour codes
-- precede the label, so match on the label alone.
local function ParseTooltipRP(tooltip)
	if not tooltip then return nil end
	local n = strMatch(tooltip, "research:%s*(%d+)")
	return n and tonumber(n) or nil
end

-- Resolves the icon texture from the morph cmdDesc if customParams didn't.
-- unit_morph sets texture = "#<into name>"; gl.Texture wants "#<unitDefID>".
local function ResolveTexture(cmdTex)
	if not cmdTex then return nil end
	local name = strMatch(cmdTex, "^#(.+)$")
	if name then
		local ud = UnitDefNames[name]
		if ud then return "#" .. ud.id end
		if tonumber(name) then return cmdTex end
		return nil
	end
	return cmdTex   -- a real image path from morphdef.texture
end

-- Returns an entry table for a unit that currently has an enabled morph
-- command, or nil.
local function ScanUnit(unitID, unitDefID)
	local info = GetDefInfo(unitDefID)
	if not info.isMex then return nil end
	if spGetUnitIsBeingBuilt(unitID) then return nil end

	local descs = spGetUnitCmdDescs(unitID)
	if not descs then return nil end
	for i = 1, #descs do
		local d = descs[i]
		local id = d.id
		if id and id >= CMD_MORPH_FIRST and id <= CMD_MORPH_LAST then
			local inMorph = morphing[unitID] ~= nil
			if d.disabled and not inMorph then
				return nil    -- tech-locked: no button
			end
			local rp = info.rp or ParseTooltipRP(d.tooltip) or 0
			local tex = info.tex or ResolveTexture(d.texture)
			return {
				cmdID   = id,
				rp      = rp,
				tex     = tex,
				tooltip = d.tooltip or "Upgrade",
				lift    = info.lift,
				hidden  = false,
				morphing = inMorph,
			}
		end
	end
	return nil
end

local function RebuildList()
	local n = 0
	for unitID in pairs(mexes) do
		n = n + 1
		mexList[n] = unitID
	end
	for i = #mexList, n + 1, -1 do
		mexList[i] = nil
	end
	tableSort(mexList)
end

local function Rescan()
	rpBalance = tonumber(spGetTeamRulesParam(myTeamID, RP_RULES_PARAM)) or 0

	-- Camera height cull: no buttons when zoomed out to strategic view.
	local cx, cy, cz = spGetCameraPosition()
	local ground = spGetGroundHeight(cx, cz) or 0
	camTooHigh = (cy - ground) > MAX_CAM_HEIGHT

	for k in pairs(mexes) do mexes[k] = nil end

	if isSpec or camTooHigh then
		RebuildList()
		return
	end

	-- Only units this player owns; allies get nothing (you can't order them).
	local visible = spGetVisibleUnits(myTeamID, nil, false)
	if visible then
		for i = 1, #visible do
			local unitID = visible[i]
			local unitDefID = spGetUnitDefID(unitID)
			if unitDefID then
				local entry = ScanUnit(unitID, unitDefID)
				if entry then
					mexes[unitID] = entry
				end
			end
		end
	end
	RebuildList()
end

local function Forget(unitID)
	if mexes[unitID] then
		mexes[unitID] = nil
		RebuildList()
	end
	rects[unitID] = nil
	if hoverID == unitID then hoverID = nil end
end

--------------------------------------------------------------------------------
-- Orders
--------------------------------------------------------------------------------

local function IssueUpgrade(unitID, queue)
	local entry = mexes[unitID]
	if not entry or entry.morphing then return false end
	local cmd = queue and CMD_MORPH_QUEUE or entry.cmdID
	spGiveOrderToUnit(unitID, cmd, {}, 0)
	-- Optimistic removal; the next rescan re-adds it if the gadget refused.
	entry.hidden = true
	return true
end

-- Ctrl-click: upgrade every visible affordable mex, cheapest first, without
-- overspending the current balance.
local function IssueUpgradeAll()
	local budget = rpBalance
	local ordered = {}
	for i = 1, #mexList do
		local unitID = mexList[i]
		local e = mexes[unitID]
		if e and not e.hidden and not e.morphing then
			ordered[#ordered + 1] = unitID
		end
	end
	tableSort(ordered, function(a, b)
		local ra, rb = mexes[a].rp, mexes[b].rp
		if ra ~= rb then return ra < rb end
		return a < b
	end)
	local issued = 0
	for i = 1, #ordered do
		local unitID = ordered[i]
		local e = mexes[unitID]
		if e.rp <= budget then
			budget = budget - e.rp
			IssueUpgrade(unitID, false)
			issued = issued + 1
		end
	end
	return issued
end

--------------------------------------------------------------------------------
-- Hit testing
--------------------------------------------------------------------------------

local function HitTest(mx, my)
	-- Later-drawn buttons are on top, so test in reverse draw order.
	for i = #rectList, 1, -1 do
		local unitID = rectList[i]
		local r = rects[unitID]
		if r and mx >= r[1] and mx <= r[3] and my >= r[2] and my <= r[4] then
			return unitID, r
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

-- The end-game graph is a full-screen modal; nothing world-anchored should
-- draw or take clicks while it is open.
local function ModalOpen()
	local eg = WG.StaticEndGraph
	return eg ~= nil and eg.IsOpen ~= nil and eg.IsOpen() == true
end

local function BindSG()
	if SG then return true end
	SG = WG.StaticGUI
	if not SG then return false end
	local raw = glLoadFont(FONT_FILE, FONT_SIZE, 1, 1.0)
	if not raw then
		spEcho("[TechUpgradeButton] failed to load " .. FONT_FILE)
		SG = nil
		return false
	end
	font = SG.WrapFont(raw)
	return true
end

-- Arc from 12 o'clock clockwise, `frac` of a full turn. Screen Y is up.
local arcPts = {}
local function DrawRing(cx, cy, radius, frac, width, color)
	local segs = mathMax(2, mathFloor(RING_SEGMENTS * frac + 0.5))
	if frac >= 1 then segs = RING_SEGMENTS end
	local n = 0
	for i = 0, segs do
		local t = (i / segs) * frac
		local ang = mathPi * 0.5 - t * 2 * mathPi
		n = n + 1; arcPts[n] = cx + mathCos(ang) * radius
		n = n + 1; arcPts[n] = cy + mathSin(ang) * radius
	end
	for i = #arcPts, n + 1, -1 do arcPts[i] = nil end
	SG.LineStrip(arcPts, width, color)
	return n / 2
end

local function DrawButton(unitID, e, sx, sy, affordable, hovered)
	local x1 = mathFloor(sx - BTN_W * 0.5)
	local y1 = mathFloor(sy)
	local x2 = x1 + BTN_W
	local y2 = y1 + BTN_H

	local inMorph = e.morphing
	local bg     = (hovered and not inMorph) and COL_BG_HOVER or COL_BG
	local border = (inMorph or not affordable) and COL_BORDER_GREY
	              or (hovered and COL_BORDER_HOT or COL_BORDER)

	SG.RoundedRect(x1, y1, x2, y2, RADIUS, bg)
	SG.RoundedOutline(x1, y1, x2, y2, RADIUS, border, BORDER)

	local ix1 = x1 + PAD
	local iy1 = y1 + (BTN_H - ICON_SIZE) * 0.5
	if e.tex then
		SG.Icon(ix1, iy1, ix1 + ICON_SIZE, iy1 + ICON_SIZE, e.tex,
		        (affordable and not inMorph) and COL_ICON or COL_ICON_GREY)
	end
	if inMorph then
		local cx, cy = ix1 + ICON_SIZE * 0.5, iy1 + ICON_SIZE * 0.5
		local radius = ICON_SIZE * 0.5 + RING_PAD
		DrawRing(cx, cy, radius, 1, RING_WIDTH, COL_RING_BG)
		local p = morphing[unitID] or 0
		if p > 0.01 then
			DrawRing(cx, cy, radius, p, RING_WIDTH, COL_RING)
		end
	end

	rects[unitID] = { x1, y1, x2, y2, affordable and not inMorph }
	rectList[#rectList + 1] = unitID
end

local function DrawLabels()
	font:Begin()
	for i = 1, #rectList do
		local unitID = rectList[i]
		local r = rects[unitID]
		local e = mexes[unitID]
		if r and e then
			local c = r[5] and COL_RP or COL_RP_GREY
			-- font:Print ignores gl.Color; the text colour must be set per call.
			font:SetTextColor(c[1], c[2], c[3], c[4])
			local tx = r[1] + PAD + ICON_SIZE + PAD * 2
			local ty = r[2] + BTN_H * 0.5
			if e.morphing then
				font:SetTextColor(COL_RP[1], COL_RP[2], COL_RP[3], COL_RP[4])
				font:Print(strFormat("%d%%", mathFloor((morphing[unitID] or 0) * 100 + 0.5)), tx, ty, FONT_SIZE, "vo")
			else
				font:Print(e.rp > 0 and strFormat("%d RP", e.rp) or "Upgrade", tx, ty, FONT_SIZE, "vo")
			end
		end
	end
	font:End()
end

function widget:DrawScreen()
	if not BindSG() then return end
	if isSpec or camTooHigh or #mexList == 0 or ModalOpen() then
		for i = #rectList, 1, -1 do rectList[i] = nil end
		for k in pairs(rects) do rects[k] = nil end
		return
	end

	for i = #rectList, 1, -1 do rectList[i] = nil end
	for k in pairs(rects) do rects[k] = nil end

	for i = 1, #mexList do
		local unitID = mexList[i]
		local e = mexes[unitID]
		if e and not e.hidden then
			local ux, uy, uz = spGetUnitPosition(unitID)
			if ux then
				local sx, sy, sz = spWorldToScreenCoords(ux, uy + e.lift, uz)
				-- Stack above the healthbar rows when the unit has any: the bar
				-- is world-sized and the button is pixel-sized, so neither a
				-- fixed world nor a fixed pixel lift keeps them apart at every
				-- zoom. Taking the higher of the two anchors does.
				local hb = WG.healthbars
				if hb and hb.getBarTopScreenPos then
					local _, barTop = hb.getBarTopScreenPos(unitID)
					if barTop and barTop + BAR_STACK_GAP > sy then
						sy = barTop + BAR_STACK_GAP
					end
				end
				-- sz > 1 means the point is behind the camera plane.
				if sz and sz <= 1 and sx > -BTN_W and sx < vsx + BTN_W
				   and sy > -BTN_H and sy < vsy + BTN_H then
					DrawButton(unitID, e, sx, sy, e.rp <= rpBalance, unitID == hoverID)
				end
			end
		end
	end

	if #rectList > 0 then
		DrawLabels()
	end
	SG.Flush()
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

function widget:IsAbove(mx, my)
	local id = HitTest(mx, my)
	hoverID = id
	return id ~= nil
end

function widget:GetTooltip(mx, my)
	local id = HitTest(mx, my)
	local e = id and mexes[id]
	if e then return e.tooltip end
	return nil
end

function widget:MousePress(mx, my, button)
	local id, r = HitTest(mx, my)
	if not id then return false end
	if button ~= 1 then return true end        -- swallow right/middle over a button

	local alt, ctrl, meta, shift = spGetModKeyState()
	if ctrl then
		IssueUpgradeAll()
	elseif shift then
		IssueUpgrade(id, true)                  -- queue, waits for RP in the gadget
	elseif r[5] then
		IssueUpgrade(id, false)
	end
	-- Always consume: a greyed button must not fall through and deselect units.
	return true
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

-- /techbtn: dumps every gate a unit passes through on its way to the screen.
-- Kept as a permanent diagnostic.
local function DebugDump()
	local cx, cy, cz = spGetCameraPosition()
	local ground = spGetGroundHeight(cx, cz) or 0
	spEcho(strFormat("[TechBtn] SG=%s font=%s team=%d spec=%s rp=%s camH=%.0f cull=%s list=%d rects=%d",
		tostring(WG.StaticGUI ~= nil), tostring(font ~= nil), myTeamID, tostring(isSpec),
		tostring(rpBalance), cy - ground, tostring(camTooHigh), #mexList, #rectList))
	local visible = spGetVisibleUnits(myTeamID, nil, false) or {}
	spEcho("[TechBtn] visible own units: " .. #visible)
	local shown = 0
	for i = 1, #visible do
		local unitID = visible[i]
		local unitDefID = spGetUnitDefID(unitID)
		local info = unitDefID and GetDefInfo(unitDefID)
		if info and info.isMex and shown < 6 then
			shown = shown + 1
			local descs = spGetUnitCmdDescs(unitID) or {}
			local ids = {}
			local morphLine = "none"
			for j = 1, #descs do
				local d = descs[j]
				ids[#ids + 1] = tostring(d.id)
				if d.id and d.id >= CMD_MORPH_FIRST and d.id <= CMD_MORPH_LAST then
					morphLine = strFormat("id=%d disabled=%s tex=%s tip=%s", d.id,
						tostring(d.disabled), tostring(d.texture),
						tostring(d.tooltip and d.tooltip:gsub("\n", " | ") or nil))
				end
			end
			local e = mexes[unitID]
			spEcho(strFormat("[TechBtn] unit %d def=%s beingBuilt=%s cmds=[%s] morph: %s entry=%s",
				unitID, UnitDefs[unitDefID].name, tostring(spGetUnitIsBeingBuilt(unitID)),
				table.concat(ids, ","), morphLine,
				e and strFormat("cmd=%d rp=%d tex=%s hidden=%s", e.cmdID, e.rp, tostring(e.tex), tostring(e.hidden)) or "nil"))
			local ux, uy, uz = spGetUnitPosition(unitID)
			if ux then
				local sx, sy, sz = spWorldToScreenCoords(ux, uy + info.lift, uz)
				spEcho(strFormat("[TechBtn]   screen %.0f,%.0f z=%.3f (view %dx%d)", sx or -1, sy or -1, sz or -1, vsx, vsy))
			end
		end
	end
	if shown == 0 then
		spEcho("[TechBtn] no eligible unit found among own units (metal_extractor / iscommander / func=tech / upgrade_button)")
	end
	return true
end


local function RefreshTeam()
	myTeamID = spGetMyTeamID()
	isSpec = spGetSpectatingState()
	lastRescan = -1
end


function widget:PlayerChanged(playerID)
	RefreshTeam()
end

function widget:UnitDestroyed(unitID)
	morphing[unitID] = nil
	Forget(unitID)
end

function widget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	if oldTeam == myTeamID then Forget(unitID) end
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if oldTeam == myTeamID then Forget(unitID) end
	lastRescan = -1
end

-- Script.LuaUI globals from unit_morph.lua's unsynced half. MorphUpdate must
-- exist for the gadget to consider LuaUI a listener at all (it gates
-- MorphStart/MorphStop/MorphFinished on `useLuaUI`).
local function OnMorphStart(unitID, morphDef)
	morphing[unitID] = 0
	local e = mexes[unitID]
	if e then e.hidden = false; e.morphing = true end
	lastRescan = -1
end

local function OnMorphStop(unitID)
	morphing[unitID] = nil
	lastRescan = -1                             -- cmdDesc re-enabled; rescan restores the button
end

local function OnMorphFinished(oldID, newID)
	morphing[oldID] = nil
	Forget(oldID)
	lastRescan = -1                             -- pick up newID's next tier promptly
end

-- Per-frame progress feed. Also the only signal after a widget reload
-- mid-morph, so it (re)populates `morphing` on its own.
local function OnMorphUpdate(morphTable)
	for unitID, data in pairs(morphTable) do
		morphing[unitID] = data.progress or 0
		local e = mexes[unitID]
		if e and not e.morphing then e.morphing = true; e.hidden = false end
	end
	for unitID in pairs(morphing) do
		if not morphTable[unitID] then
			morphing[unitID] = nil
			lastRescan = -1
		end
	end
end

-- The morph gadget only calls a LuaUI global if it exists, and only one
-- widget can own each name. gui_healthbars_gl4 owns them (it draws morph
-- progress in the bar) and relays every event through
-- WG.healthbars.addMorphListener. Subscribe there when it exists; fall back
-- to owning the globals ourselves if it doesn't (healthbars disabled).
local morphSource = nil          -- "relay" | "globals" | nil
local SubscribeMorphEvents

local MORPH_HANDLERS = {
	MorphStart    = function(...) return OnMorphStart(...) end,
	MorphStop     = function(...) return OnMorphStop(...) end,
	MorphFinished = function(...) return OnMorphFinished(...) end,
	MorphUpdate   = function(...) return OnMorphUpdate(...) end,
}

SubscribeMorphEvents = function()
	if morphSource then return true end
	local hb = WG.healthbars
	if hb and hb.addMorphListener then
		hb.addMorphListener("TechUpgradeButton", MORPH_HANDLERS)
		morphSource = "relay"
		return true
	end
	local ok = widgetHandler:RegisterGlobal("MorphUpdate", MORPH_HANDLERS.MorphUpdate)
	if ok then
		widgetHandler:RegisterGlobal("MorphStart",    MORPH_HANDLERS.MorphStart)
		widgetHandler:RegisterGlobal("MorphStop",     MORPH_HANDLERS.MorphStop)
		widgetHandler:RegisterGlobal("MorphFinished", MORPH_HANDLERS.MorphFinished)
		morphSource = "globals"
		return true
	end
	return false   -- globals taken and relay not up yet: retry from Update
end

local function UnsubscribeMorphEvents()
	if morphSource == "relay" then
		local hb = WG.healthbars
		if hb and hb.removeMorphListener then hb.removeMorphListener("TechUpgradeButton") end
	elseif morphSource == "globals" then
		widgetHandler:DeregisterGlobal("MorphStart")
		widgetHandler:DeregisterGlobal("MorphStop")
		widgetHandler:DeregisterGlobal("MorphFinished")
		widgetHandler:DeregisterGlobal("MorphUpdate")
	end
	morphSource = nil
end

function widget:Update()
	local frame = spGetGameFrame()
	if not morphSource and frame % 30 == 0 then
		SubscribeMorphEvents()
	end
	if frame - lastRescan >= RESCAN_FRAMES or lastRescan < 0 then
		lastRescan = frame
		Rescan()
	end
end

function widget:Initialize()
	vsx, vsy = spGetViewGeometry()
	RefreshTeam()
	SubscribeMorphEvents()
	if widgetHandler.AddAction then
		widgetHandler:AddAction("techbtn", function() DebugDump() return true end, nil, "t")
	end

	-- Lets other world-anchored widgets (gui_world_labels.lua) stack above the
	-- button instead of colliding with it. Rects are rebuilt every DrawScreen;
	-- a reader running earlier in the frame sees last frame's rect, which is
	-- indistinguishable on screen.
	WG.TechUpgradeButton = {
		getRect = function(unitID) return rects[unitID] end,   -- {x1,y1,x2,y2,affordable} or nil
	}
end

function widget:ViewResize(nx, ny)
	vsx, vsy = nx, ny
end


function widget:Shutdown()
	if widgetHandler.RemoveAction then
		widgetHandler:RemoveAction("techbtn")
	end
	UnsubscribeMorphEvents()
	if font and SG then
		SG.DeleteFont(font)
	end
	WG.TechUpgradeButton = nil
end

--------------------------------------------------------------------------------
-- Test hook. Exposes internals when loaded outside the engine (no widgetHandler).
--------------------------------------------------------------------------------

if not widgetHandler then
	return {
		Rescan          = Rescan,
		ScanUnit        = ScanUnit,
		ParseTooltipRP  = ParseTooltipRP,
		ResolveTexture  = ResolveTexture,
		HitTest         = HitTest,
		IssueUpgrade    = IssueUpgrade,
		IssueUpgradeAll = IssueUpgradeAll,
		Forget          = Forget,
		OnMorphStart    = OnMorphStart,
		OnMorphStop     = OnMorphStop,
		OnMorphFinished = OnMorphFinished,
		OnMorphUpdate   = OnMorphUpdate,
		DrawRing        = DrawRing,
		state = function()
			return { mexes = mexes, mexList = mexList, rects = rects, rectList = rectList,
			         rpBalance = rpBalance, camTooHigh = camTooHigh, morphing = morphing }
		end,
		setRects = function(id, r)
			rects[id] = r
			rectList[#rectList + 1] = id
		end,
		setRP = function(v) rpBalance = v end,
	}
end
