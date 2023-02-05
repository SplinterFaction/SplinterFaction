if not gadgetHandler:IsSyncedCode() then
	return
end

function gadget:GetInfo()
	return {
		name    = "Tech-based fac buildspeed",
		desc    = "Factories get better buildspeed with tech",
		author  = "Sprung",
		date    = "2023-02-04",
		license = "Public Domain",
		layer   = 0,
		enabled = true,
	}
end

local factoryNames = {
	"f1landfac",
	"f2landfac",
	"fedairplant",
	"lozairplant",
	"fedseaplant",
	"lozseaplant",
}
local nominalFactorySpeeds = {} -- [unitDefID] = buildSpeed
for i = 1, #factoryNames do
	local unitDef = UnitDefNames[factoryNames[i]]
	nominalFactorySpeeds[unitDef.id] = unitDef.buildSpeed
end

--[[ FIXME: autogenerate these?
local nominalFactorySpeeds = {}
for unitDefID, unitDef in pairs(UnitDefs) do
if unitDef.isFactory then
	nominalFactorySpeeds[unitDefID] = unitDef.buildSpeed
end
]]

local factoriesByTeam = {} -- [teamID] = { [unitID] = nominalSpeed }; kept so that we know whom to update on the fly during tech-up

local SetBuildSpeed = Spring.SetUnitBuildSpeed -- (unitID, speed). should ideally be a wrapper that sets an attribute instead of raw engine function, so another gadget doesn't override

local function GetTechLevelMultiplier(teamID)

	local techCheck = GG.TechCheck

	if not techCheck then
		Spring.Echo("shiiiit. tech gadget broke.")
		return 1
	end

	if techCheck("tech3", teamID) then
		return 24
	elseif techCheck("tech2", teamID) then
		return 16
	elseif techCheck("tech1", teamID) then
		return 10
	else -- if techCheck("tech0") then -- is that a separate tech level or just baseline? whatever, modify as needed
		return 1
	end

end

--[[ This would ideally be hooked up to some sort of event that would fire if tech changes.
     Since the tech gadget doesn't seem to have that, we will just fire it periodically. ]]
local function TechChangedEvent(teamID)
	local mult = GetTechLevelMultiplier(teamID) -- this would be a decent place to cache the mult if this was an event
	for unitID, nominalSpeed in pairs(factoriesByTeam[teamID]) do
		SetBuildSpeed(unitID, nominalSpeed * mult)
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
	local nominalSpeed = nominalFactorySpeeds[unitDefID]
	if not nominalSpeed then
		return
	end

	factoriesByTeam[unitTeam][unitID] = nominalSpeed

	SetBuildSpeed(unitID, nominalSpeed * GetTechLevelMultiplier(unitTeam))
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	factoriesByTeam[unitTeam][unitID] = nil
end

function gadget:Initialize()
	local teams = Spring.GetTeamList()
	for i = 1, #teams do
		local teamID = teams[i]
		factoriesByTeam[teamID] = {}
	end

	for _, unitID in ipairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
	end
end
