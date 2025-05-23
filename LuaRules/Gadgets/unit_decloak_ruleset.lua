--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "Decloak Ruleset",
		desc      = "Defines rulesets for when a unit should decloak",
		author    = "Google Frog",
		date      = "Nov 25, 2009", -- Major rework 12 Feb 2014
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true  --  loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

include("LuaRules/Configs/customcmds.h.lua")

local CMD_CLOAK = CMD.CLOAK

local unitWantCloakCommandDesc = {
	id      = CMD_WANT_CLOAK,
	type    = CMDTYPE.ICON_MODE,
	name    = 'Cloak State',
	action  = 'wantcloak',
	tooltip	= 'Unit cloaking state',
	params 	= {0, 'Decloaked', 'Cloaked'}
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
	return false  --  silent removal
end

local alliedTrueTable = {allied = true}

local spAreTeamsAllied           = Spring.AreTeamsAllied
local spSetUnitCloak             = Spring.SetUnitCloak
local spGetUnitIsCloaked         = Spring.GetUnitIsCloaked
local spGetUnitRulesParam        = Spring.GetUnitRulesParam
local spSetUnitRulesParam        = Spring.SetUnitRulesParam
local spGetUnitDefID             = Spring.GetUnitDefID
local spGetUnitIsDead            = Spring.GetUnitIsDead

local recloakUnit = {}
local recloakFrame = {}

local noFFWeaponDefs = {}
for i = 1, #WeaponDefs do
	local wd = WeaponDefs[i]
	if wd.customParams and wd.customParams.nofriendlyfire then
		noFFWeaponDefs[i] = true
	end
end

local DEFAULT_DECLOAK_TIME = 240
local PERSONAL_DECLOAK_TIME = 90

local DEFAULT_PROXIMITY_DECLOAK_TIME = 90
local PERSONAL_PROXIMITY_DECLOAK_TIME = 45

local UPDATE_FREQUENCY = 10
local CLOAK_MOVE_THRESHOLD = math.sqrt(0.2)

local currentFrame = 0

local cloakUnitDefID = {}
local commDefID = {}
for i = 1, #UnitDefs do
	local ud = UnitDefs[i]
	if ud.canCloak and not ud.customParams.dynamic_comm then
		cloakUnitDefID[i] = true
	end
	if ud.customParams.dynamic_comm then
		commDefID[i] = true
	end
end

local function GetProximityDecloakTime(unitID, unitDefID)
	unitDefID = unitDefID or spGetUnitDefID(unitID)
	if commDefID[unitDefID] then
		return PERSONAL_PROXIMITY_DECLOAK_TIME
	end
	return (cloakUnitDefID[unitDefID] and PERSONAL_PROXIMITY_DECLOAK_TIME) or DEFAULT_PROXIMITY_DECLOAK_TIME
end

local function GetActionDecloakTime(unitID, unitDefID)
	unitDefID = unitDefID or spGetUnitDefID(unitID)
	if commDefID[unitDefID] then
		return PERSONAL_DECLOAK_TIME
	end
	return (cloakUnitDefID[unitDefID] and PERSONAL_DECLOAK_TIME) or DEFAULT_DECLOAK_TIME
end

local function PokeDecloakUnit(unitID, unitDefID)
	if not recloakUnit[unitID] then
		spSetUnitRulesParam(unitID, "cannotcloak", 1, alliedTrueTable)
		spSetUnitCloak(unitID, 0)
	end
	recloakUnit[unitID] = GetActionDecloakTime(unitID, unitDefID)
end

GG.PokeDecloakUnit = PokeDecloakUnit

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer,
                            weaponID, attackerID, attackerDefID, attackerTeam)
	if  (damage > 0) and
			not (attackerTeam and
					weaponID and
					noFFWeaponDefs[weaponID] and
					attackerID ~= unitID and
					spAreTeamsAllied(unitTeam, attackerTeam)) then
		PokeDecloakUnit(unitID, unitDefID)
	end
end

function gadget:GameFrame(n)
	currentFrame = n
	if n%UPDATE_FREQUENCY == 2 then
		for unitID, frames in pairs(recloakUnit) do
			if frames <= UPDATE_FREQUENCY then
				if not ((spGetUnitRulesParam(unitID,"on_fire") == 1) or (spGetUnitRulesParam(unitID,"disarmed") == 1)) then
					local wantCloakState = spGetUnitRulesParam(unitID, "wantcloak")
					local areaCloaked = spGetUnitRulesParam(unitID, "areacloaked")
					spSetUnitRulesParam(unitID, "cannotcloak", 0, alliedTrueTable)
					if wantCloakState == 1 or areaCloaked == 1 then
						spSetUnitCloak(unitID, 1)
					end
					recloakUnit[unitID] = nil
				end
			else
				recloakUnit[unitID] = frames - UPDATE_FREQUENCY
			end
		end
	end
end

-- Only called with enemyID if an enemy is within decloak radius.
function gadget:AllowUnitCloak(unitID, enemyID)
	if enemyID then
		local transID = Spring.GetUnitTransporter(unitID)
		if transID then
			-- For some reason enemyID indicates that the unit is being transported.
			return spGetUnitIsCloaked(transID)
		end
		recloakFrame[unitID] = currentFrame + GetProximityDecloakTime(unitID)
		return false
	end

	if recloakFrame[unitID] then
		if recloakFrame[unitID] > currentFrame then
			return false
		end
		recloakFrame[unitID] = nil
	end

	local stunnedOrInbuild = Spring.GetUnitIsStunned(unitID)
	if stunnedOrInbuild then
		return false
	end

	local unitDefID = unitID and Spring.GetUnitDefID(unitID)
	local ud = unitDefID and UnitDefs[unitDefID]
	if not ud then
		return false
	end

	local areaCloaked = (Spring.GetUnitRulesParam(unitID, "areacloaked") == 1) and ((Spring.GetUnitRulesParam(unitID, "cloak_shield") or 0) == 0)
	if not areaCloaked then
		local speed = select(4, Spring.GetUnitVelocity(unitID))
		local moving = speed and speed > CLOAK_MOVE_THRESHOLD
		local cost = moving and ud.cloakCostMoving or ud.cloakCost

		if not Spring.UseUnitResource(unitID, "e", cost/2) then -- SlowUpdate happens twice a second.
			return false
		end
	end

	return true
end

function gadget:AllowUnitDecloak(unitID, objectID, weaponID)
	recloakFrame[unitID] = currentFrame + GetActionDecloakTime(unitID)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function SetWantedCloaked(unitID, state)
	if (not unitID) or spGetUnitIsDead(unitID) then
		return
	end

	local wantCloakState = spGetUnitRulesParam(unitID, "wantcloak")
	local cmdDescID = Spring.FindUnitCmdDesc(unitID, CMD_WANT_CLOAK)
	if (cmdDescID) then
		Spring.EditUnitCmdDesc(unitID, cmdDescID, { params = {state, 'Decloaked', 'Cloaked'}})
	end

	if state == 1 and wantCloakState ~= 1 then
		local cannotCloak = spGetUnitRulesParam(unitID, "cannotcloak")
		local areaCloaked = spGetUnitRulesParam(unitID, "areacloaked")
		if cannotCloak ~= 1 and areaCloaked ~= 1 then
			spSetUnitCloak(unitID, 1)
		end
		spSetUnitRulesParam(unitID, "wantcloak", 1, alliedTrueTable)
	elseif state == 0 and wantCloakState == 1 then
		local areaCloaked = spGetUnitRulesParam(unitID, "areacloaked")
		if areaCloaked ~= 1 then
			spSetUnitCloak(unitID, 0)
		end
		spSetUnitRulesParam(unitID, "wantcloak", 0, alliedTrueTable)
	end
end

GG.SetWantedCloaked = SetWantedCloaked

function gadget:AllowCommand_GetWantedCommand()
	return {[CMD_CLOAK] = true, [CMD_WANT_CLOAK] = true}
end

function gadget:AllowCommand_GetWantedUnitDefID()
	return true
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if cmdID == CMD_WANT_CLOAK then
		if cloakUnitDefID[unitDefID] then
			SetWantedCloaked(unitID,cmdParams[1])
		end
		return false
	elseif cmdID == CMD_CLOAK then
		return false
	end
	return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:UnitCreated(unitID, unitDefID)
	local ud = UnitDefs[unitDefID]
	if cloakUnitDefID[unitDefID] then
		local cloakDescID = Spring.FindUnitCmdDesc(unitID, CMD_CLOAK)
		if cloakDescID then
			Spring.InsertUnitCmdDesc(unitID, unitWantCloakCommandDesc)
			Spring.RemoveUnitCmdDesc(unitID, cloakDescID)
			spSetUnitRulesParam(unitID, "wantcloak", 0, alliedTrueTable)
			if ud.customParams.initcloaked then
				SetWantedCloaked(unitID, 1)
			end
			return
		end
	elseif ud.customParams.dynamic_comm then
		local cloakDescID = Spring.FindUnitCmdDesc(unitID, CMD_CLOAK)
		if cloakDescID then
			Spring.RemoveUnitCmdDesc(unitID, cloakDescID)
		end
	end
end

function gadget:Initialize()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = spGetUnitDefID(unitID)
		gadget:UnitCreated(unitID, unitDefID)
		local pos = select(2, Spring.GetUnitPosition(unitID))
	end
end

function gadget:Load(zip)
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		-- restore cloak for dyncomms during a loaded savegame
		-- the CMD_CLOAK cmd desc ID was already removed during the UnitCreated() call, so we can't use the detection method used there
		-- instead we do this
		Spring.InsertUnitCmdDesc(unitID, unitWantCloakCommandDesc)
		local wantedState = spGetUnitRulesParam(unitID, "wantcloak")
		spSetUnitRulesParam(unitID, "wantcloak", 0, alliedTrueTable)
		SetWantedCloaked(unitID, wantedState)
		-- unit_commander_upgrade runs after us and decloaks us while setting our decloak radius,
		-- so reset at earliest opportunity
		if wantedState == 1 then
			recloakUnit[unitID] = 0
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
