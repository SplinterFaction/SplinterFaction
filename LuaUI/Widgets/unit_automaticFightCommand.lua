-- TODO: Remove/adjust me when/if https://github.com/beyond-all-reason/RecoilEngine/issues/<TODO-MY-ISSUE-ID-PLEASE-FILE> is resolved

function widget:GetInfo()
  return {
	name		= "Fix UnitIdle callin",
	desc		= "UnitIdle is not called for recently finished units without order queues",
	author		= "Forby",
	date		= "Jan 8, 2007",
	license		= "GNU GPL, v2 or later",
	layer		= 0,
	handler		= true, -- we issue artifical UnitIdle callin to other widgets
	enabled		= true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local CMD_FIGHT				= CMD.FIGHT
local spGetMyTeamID			= Spring.GetMyTeamID
local spGetTeamUnits		= Spring.GetTeamUnits
local spGetUnitDefID		= Spring.GetUnitDefID
local spGetUnitPosition		= Spring.GetUnitPosition
local spGiveOrderToUnit		= Spring.GiveOrderToUnit
local spGetSpectatingState	= Spring.GetSpectatingState
local spGetUnitCommandCount 	= Spring.GetUnitCommandCount

local hmsx = Game.mapSizeX/2
local hmsz = Game.mapSizeZ/2


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- TODO: Consider making this available for all units, there might be some gotchas like engine issuing UnitFinished before assigning orders to units coming out of factory
local targetUnits = {
	fedengineer          = true,
	fedengineer_up1      = true,
	fedengineer_up2      = true,
	fedengineer_up3      = true,
	lozengineer          = true,
	lozengineer_up1      = true,
	lozengineer_up2      = true,
	lozengineer_up3      = true,
	fedcommander         = true,
	fedcommander_up1     = true,
	fedcommander_up2     = true,
	fedcommander_up3     = true,
	fedcommander_up4     = true,
	lozcommander         = true,
	lozcommander_up1     = true,
	lozcommander_up2     = true,
	lozcommander_up3     = true,
	lozcommander_up4     = true
}

local function IsTargetUnit(ud)
    return ud and targetUnits[ud.name]
end


local function SetupUnit(unitID, unitDefID, unitTeam)
	if spGetUnitCommandCount(unitID) > 0 then
		return
	end
	
	widgetManager:UnitIdle(unitID, unitDefID, unitTeam)
end

function widget:PlayerChanged()
	if spGetSpectatingState() then
		widgetHandler:RemoveWidget()
	end
end

function widget:Initialize()
	if spGetSpectatingState() then
		widgetHandler:RemoveWidget()
	end
end


function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam ~= spGetMyTeamID() or not IsTargetUnit(UnitDefs[unitDefID]) then
		return
	end

	SetupUnit(unitID, unitDefID, unitTeam)
end


function widget:UnitGiven(unitID, unitDefID, unitTeam)
	if unitTeam ~= spGetMyTeamID() or not IsTargetUnit(UnitDefs[unitDefID]) then
		return
	end

	SetupUnit(unitID, unitDefID, unitTeam)
end
