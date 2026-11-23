function gadget:GetInfo()
	return {
		name    = "Group Pace",
		desc    = "Units ordered to move together (Ctrl + move) keep to the pace of the slowest of them",
		author  = "SplinterFaction Team",
		date    = "2026-11-23",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
--
--  LuaUI asks for it with Spring.SendLuaRulesMsg("grouppace:<id>,<id>,..."),
--  sent right after the units' move orders (cmd_line_move_spread.lua does, for
--  a move given with Ctrl held). Every unit in the list is held to the top
--  speed of the slowest one. A unit gets its own speed back when it is given
--  its next order that is not queued, or has nothing left to do.
--
--  Fixed-wing aircraft are left out: they cannot fly at a tank's pace.
--
--------------------------------------------------------------------------------

if not gadgetHandler:IsSyncedCode() then
	return false
end

local PREFIX = "grouppace:"
local MAX_UNITS = 500

local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitTeam         = Spring.GetUnitTeam
local spValidUnitID         = Spring.ValidUnitID
local spGetUnitMoveTypeData = Spring.GetUnitMoveTypeData
local spGetPlayerInfo       = Spring.GetPlayerInfo

local MoveCtrl = Spring.MoveCtrl

-- how each unit type's speed is set, or nil for those left alone
local setter = {}
for unitDefID, ud in pairs(UnitDefs) do
	if (ud.speed or 0) > 0 and not ud.isFactory then
		if ud.canFly then
			if ud.isHoveringAirUnit or ud.hoverAttack then
				setter[unitDefID] = MoveCtrl.SetGunshipMoveTypeData
			end
		else
			setter[unitDefID] = MoveCtrl.SetGroundMoveTypeData
		end
	end
end

local paced = {} -- unitID -> its own top speed, for the units being held back

local function SetSpeed(unitID, speed)
	local set = setter[spGetUnitDefID(unitID) or 0]
	if set then
		pcall(set, unitID, "maxWantedSpeed", speed)
	end
end

local function Release(unitID)
	local own = paced[unitID]
	if own then
		paced[unitID] = nil
		if spValidUnitID(unitID) then
			SetSpeed(unitID, own)
		end
	end
end

function gadget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, #PREFIX) ~= PREFIX then
		return
	end
	local _, _, spectator, teamID = spGetPlayerInfo(playerID, false)
	if spectator then
		return true
	end
	local units, slowest = {}, nil
	for id in msg:sub(#PREFIX + 1):gmatch("%d+") do
		local unitID = tonumber(id)
		if #units < MAX_UNITS and spValidUnitID(unitID) and spGetUnitTeam(unitID) == teamID
				and setter[spGetUnitDefID(unitID) or 0] then
			local own = paced[unitID]
			if not own then
				local data = spGetUnitMoveTypeData(unitID)
				own = data and data.maxSpeed
			end
			if own and own > 0 then
				units[#units + 1] = { unitID, own }
				if not slowest or own < slowest then
					slowest = own
				end
			end
		end
	end
	if #units < 2 then
		return true
	end
	for i = 1, #units do
		local unitID, own = units[i][1], units[i][2]
		paced[unitID] = own
		SetSpeed(unitID, slowest)
	end
	return true
end

-- the next order that is not queued behind the others ends it
function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if paced[unitID] and not cmdOptions.shift then
		Release(unitID)
	end
	return true
end

function gadget:UnitIdle(unitID)
	if paced[unitID] then
		Release(unitID)
	end
end

function gadget:UnitDestroyed(unitID)
	paced[unitID] = nil
end
