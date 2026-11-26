function widget:GetInfo()
	return {
		name    = "Wait Markers",
		desc    = "Draws the wait cursor, large, over every unit that is on Wait",
		author  = "ForbodingAngel, Claude",
		date    = "2026-11-26",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
--
--  The engine marks a waiting unit with a small copy of the wait cursor, and
--  only while the unit is selected. Its size cannot be set for wait alone: the
--  one setting there is (queueIconScale in cmdcolors.txt) scales the icon of
--  every queued order together. So this draws the wait cursor itself, animated
--  and large, over each unit of yours (or, watching, of anyone) whose current
--  order is Wait, selected or not.
--
--  The picture is the game's own wait cursor: Anims/cursorwait.txt and the
--  frames it lists.
--
--------------------------------------------------------------------------------

local TUNE = {
	scale     = 0.65,  -- marker half-size, in unit radii
	minSize   = 17,    -- ... and never smaller than this, in elmos
	maxSize   = 32,    -- ... nor larger: a factory's would otherwise fill the screen
	lift      = 0.6,   -- how far above the unit's top the marker sits, in marker half-sizes
	alpha     = 0.95,
	period    = 0.2,   -- seconds between two looks at who is waiting
}

local CURSOR_SPEC = "anims/cursorwait.txt"
local CMD_WAIT = CMD.WAIT

local spGetVisibleUnits        = Spring.GetVisibleUnits
local spGetUnitCurrentCommand  = Spring.GetUnitCurrentCommand
local spGetUnitDefID           = Spring.GetUnitDefID
local spGetUnitPosition        = Spring.GetUnitPosition
local spIsUnitInView           = Spring.IsUnitInView
local spGetFactoryCommands     = Spring.GetFactoryCommands
local spGetUnitCommands        = Spring.GetUnitCommands
local spValidUnitID            = Spring.ValidUnitID

local frames = {}        -- {file, until}: until is the time in the loop its turn ends
local loopTime = 0

local unitSize = {}      -- unitDefID -> marker half-size
local unitTop = {}       -- unitDefID -> height of the unit's top
local isFactory = {}
for unitDefID, ud in pairs(UnitDefs) do
	local size = math.max(TUNE.minSize, math.min(TUNE.maxSize, (ud.radius or 20) * TUNE.scale))
	unitSize[unitDefID] = size
	unitTop[unitDefID] = (ud.height or 30)
	isFactory[unitDefID] = ud.isFactory or false
end

local waiting = {}       -- unitID -> unitDefID
local sinceLook = 0
local clock = 0

-- the frames of the wait cursor, from the cursor's own spec
local function LoadFrames()
	local text = VFS.LoadFile(CURSOR_SPEC)
	if not text then
		return false
	end
	local total = 0
	for file, seconds in text:gmatch("frame%s+(%S+)%s+([%d%.]+)") do
		if VFS.FileExists(file) then
			total = total + math.min(tonumber(seconds) or 0.05, 0.25) -- a held first frame is not held here
			frames[#frames + 1] = { file = file, till = total }
		end
	end
	loopTime = total
	return #frames > 0
end

local function IsWaiting(unitID, unitDefID)
	if spGetUnitCurrentCommand(unitID) == CMD_WAIT then
		return true
	end
	if isFactory[unitDefID] then
		-- a factory's own orders (what it builds, and Wait) are in its factory queue
		local queue = spGetFactoryCommands(unitID, 1)
		return queue ~= nil and queue[1] ~= nil and queue[1].id == CMD_WAIT
	end
	return false
end

local function Look()
	local seen = {}
	local units = spGetVisibleUnits(-1, nil, false) or {}
	for i = 1, #units do
		local unitID = units[i]
		local unitDefID = spGetUnitDefID(unitID)
		if unitDefID and IsWaiting(unitID, unitDefID) then
			seen[unitID] = unitDefID
		end
	end
	waiting = seen
end

function widget:Initialize()
	if not LoadFrames() then
		Spring.Echo("[Wait Markers] no wait cursor found (" .. CURSOR_SPEC .. ")")
		widgetHandler:RemoveWidget()
		return
	end
	Look()
end

function widget:Update(dt)
	clock = clock + dt
	sinceLook = sinceLook + dt
	if sinceLook >= TUNE.period then
		sinceLook = 0
		Look()
	end
end

-- an order to wait (or to stop waiting) shows at the next look, at once
function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID)
	if cmdID == CMD_WAIT then
		sinceLook = TUNE.period
	end
end

function widget:UnitDestroyed(unitID)
	waiting[unitID] = nil
end

function widget:DrawWorld()
	if not next(waiting) or Spring.IsGUIHidden() then
		return
	end
	local at = clock % loopTime
	local frame = frames[1]
	for i = 1, #frames do
		if at < frames[i].till then
			frame = frames[i]
			break
		end
	end
	gl.DepthTest(false)
	gl.Color(1, 1, 1, TUNE.alpha)
	gl.Texture(frame.file)
	for unitID, unitDefID in pairs(waiting) do
		if spValidUnitID(unitID) and spIsUnitInView(unitID) then
			local x, y, z = spGetUnitPosition(unitID)
			if x then
				local size = unitSize[unitDefID] or TUNE.minSize
				gl.PushMatrix()
				gl.Translate(x, y + (unitTop[unitDefID] or 30) + size * TUNE.lift, z)
				gl.Billboard()
				gl.TexRect(-size, -size, size, size)
				gl.PopMatrix()
			end
		end
	end
	gl.Texture(false)
	gl.Color(1, 1, 1, 1)
end
