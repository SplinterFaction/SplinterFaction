function gadget:GetInfo()
	return {
		name = "Chicken Burrow Health Scale",
		desc = "yes",
		author = "Damgam",
		date = "2023",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

local burrowName = "chickensbeacon"

if gadgetHandler:IsSyncedCode() then
    function gadget:UnitCreated(unitID, unitDefID, unitTeam)
        if UnitDefs[unitDefID].name == burrowName then
            local burrowHealth = 1000 + 1000*(Spring.GetGameRulesParam("queenAnger") or 0)
            Spring.SetUnitMaxHealth(unitID, burrowHealth)
        end
    end
end