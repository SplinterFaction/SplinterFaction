if not gadgetHandler:IsSyncedCode() then
	return
end

function gadget:GetInfo()
	return {
		name    = "Tech-based buildspeed",
		desc    = "Builders get better buildspeed with tech",
		author  = "Sprung",
		date    = "2023-02-04",
		license = "Public Domain",
		layer   = 0,
		enabled = true,
	}
end

local multipliersForFactories       = { 10,  30, 44, 92, 192 }
local multipliersForRegularBuilders = { 8,  16,  32,  64, 128 }
local multipliersForCommanders      = multipliersForRegularBuilders

local nominalBuildSpeeds = {}
local multipliers = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	local role = unitDef.customParams.unitrole
	if role == "Factory" then
		nominalBuildSpeeds[unitDefID] = unitDef.buildSpeed
		multipliers[unitDefID] = multipliersForFactories
	elseif role == "Builder" then
		nominalBuildSpeeds[unitDefID] = unitDef.buildSpeed
		multipliers[unitDefID] = multipliersForRegularBuilders
	elseif role == "Commander" then
		nominalBuildSpeeds[unitDefID] = unitDef.buildSpeed
		multipliers[unitDefID] = multipliersForCommanders
	end
end

local buildersByTeam = {} -- [teamID] = { [unitID] = nominalSpeed }; kept so that we know whom to update on the fly during tech-up

local SetBuildSpeed = Spring.SetUnitBuildSpeed -- (unitID, speed). should ideally be a wrapper that sets an attribute instead of raw engine function, so another gadget doesn't override

local spGetUnitDefID = Spring.GetUnitDefID

local function GetTechLevel(teamID)
	local techCheck = GG.TechCheck
	if not techCheck then
		Spring.Echo("shiiiit. tech gadget broke.")
		return 1
	end
	if techCheck("tech4", teamID) then
		return 5
	elseif techCheck("tech3", teamID) then
		return 4
	elseif techCheck("tech2", teamID) then
		return 3
	elseif techCheck("tech1", teamID) then
		return 2
	else -- if techCheck("tech0") then -- is that a separate tech level or just baseline? whatever, modify as needed
		return 1
	end
end

local repairSpeedModifier = 0.25
local reclaimSpeedModifier = 0.25
local resurrectSpeedModifier = 0.25
local captureSpeedModifier = 0.25
local terraformSpeedModifier = 100


--[[ This would ideally be hooked up to some sort of event that would fire if tech changes.
     Since the tech gadget doesn't seem to have that, we will just fire it periodically. ]]
local function TechChangedEvent(teamID)
	if teamID ~= nil then
		local techLevel = GetTechLevel(teamID) -- this would be a decent place to cache the techlevel if this was an event
		for unitID, nominalSpeed in pairs(buildersByTeam[teamID]) do
			if unitID ~= nil then
				--Spring.SetUnitBuildSpeed ( number builderID, number buildSpeed [, number repairSpeed [, number reclaimSpeed[, number resurrectSpeed [, number captureSpeed [, number terraformSpeed ]]]]] )
				SetBuildSpeed(unitID, nominalSpeed * multipliers[spGetUnitDefID(unitID)][techLevel],
				              nominalSpeed * multipliers[spGetUnitDefID(unitID)][techLevel] * repairSpeedModifier,
				              nominalSpeed * multipliers[spGetUnitDefID(unitID)][techLevel] * reclaimSpeedModifier,
				              nominalSpeed * multipliers[spGetUnitDefID(unitID)][techLevel] * resurrectSpeedModifier,
				              nominalSpeed * multipliers[spGetUnitDefID(unitID)][techLevel] * captureSpeedModifier,
				              nominalSpeed * multipliers[spGetUnitDefID(unitID)][techLevel] * terraformSpeedModifier)
			end
		end
	end
end

function gadget:GameFrame(f)
	if f % Game.gameSpeed == 0 then
		local teams = Spring.GetTeamList()
		for i = 1, #teams do
			local teamID = teams[i]
			TechChangedEvent(teamID)
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	local nominalSpeed = nominalBuildSpeeds[unitDefID]
	if not nominalSpeed then
		return
	end

	buildersByTeam[unitTeam][unitID] = nominalSpeed

	--Spring.SetUnitBuildSpeed ( number builderID, number buildSpeed [, number repairSpeed [, number reclaimSpeed[, number resurrectSpeed [, number captureSpeed [, number terraformSpeed ]]]]] )
	SetBuildSpeed(unitID, nominalSpeed * multipliers[unitDefID][GetTechLevel(unitTeam)],
	              nominalSpeed * multipliers[unitDefID][GetTechLevel(unitTeam)] * repairSpeedModifier,
	              nominalSpeed * multipliers[unitDefID][GetTechLevel(unitTeam)] * reclaimSpeedModifier,
	              nominalSpeed * multipliers[unitDefID][GetTechLevel(unitTeam)] * resurrectSpeedModifier,
	              nominalSpeed * multipliers[unitDefID][GetTechLevel(unitTeam)] * captureSpeedModifier,
	              nominalSpeed * multipliers[unitDefID][GetTechLevel(unitTeam)] * terraformSpeedModifier)
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	buildersByTeam[unitTeam][unitID] = nil
end

function gadget:Initialize()
	local teams = Spring.GetTeamList()
	for i = 1, #teams do
		buildersByTeam[teams[i]] = {}
	end

	for _, unitID in ipairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
	end
end