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

local burrowName = "healstation_ai"
local aliveBurrows = {}

if gadgetHandler:IsSyncedCode() then
    function gadget:UnitCreated(unitID, unitDefID, unitTeam)
        if UnitDefs[unitDefID].name == burrowName then
            local burrowHealth = 1000 + 500*(Spring.GetGameRulesParam("chickenTechAnger") or 0)
            Spring.SetUnitMaxHealth(unitID, burrowHealth)
			Spring.SetUnitHealth(unitID, burrowHealth)
			aliveBurrows[unitID] = true
        end
    end

	function gadget:GameFrame(n)
		if n%300 == 0 then -- update old burrows max health
			local burrowHealth = 1000 + 500*(Spring.GetGameRulesParam("chickenTechAnger") or 0)
			for unitID, _ in pairs(aliveBurrows) do
				local h, mh = Spring.GetUnitHealth(unitID)
				if h and mh then
					local hp = h/mh
            		Spring.SetUnitMaxHealth(unitID, burrowHealth)
					Spring.SetUnitHealth(unitID, burrowHealth*hp)
				else -- failsafe
					aliveBurrows[unitID] = nil
				end
			end
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID)
		if aliveBurrows[unitID] then aliveBurrows[unitID] = nil end
	end
end