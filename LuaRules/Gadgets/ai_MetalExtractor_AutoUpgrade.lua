function gadget:GetInfo()
	return {
		name      = "AI MetalExtractor AutoUpgrade",
		desc      = "Automatically add metal extractors to the upgrade queue",
		author    = "",
		date      = "",
		license   = "",
		layer     = 0,
		enabled   = true
	}
end

local CMD_MORPH_QUEUE = 34410
local teamTechLevel = {}
local mexTechLevel = {}
local mexes = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.name == "fedmetalextractor" or unitDef.name == "lozmetalextractor" then
		mexTechLevel[unitDefID] = 0
	end
	if unitDef.name == "fedmetalextractor_up1" or unitDef.name == "lozmetalextractor_up1" then
		mexTechLevel[unitDefID] = 1
	end
	if unitDef.name == "fedmetalextractor_up2" or unitDef.name == "lozmetalextractor_up2" then
		mexTechLevel[unitDefID] = 2
	end
	if unitDef.name == "fedmetalextractor_up3" or unitDef.name == "lozmetalextractor_up3" then
		mexTechLevel[unitDefID] = 3
	end
	if unitDef.name == "fedmetalextractor_up4" or unitDef.name == "lozmetalextractor_up4" then
		mexTechLevel[unitDefID] = 4
	end
end

function gadget:UnitCreated(unitID, unitDefID, teamID)
	if UnitDefs[unitDefID].customParams.metal_extractor then
		if not (UnitDefs[unitDefID].customParams.requiretech == "tech4") then -- Don't add T4
			mexes[unitID] = true
		end
	end
end

-- Get my current tech level the ghetto way
function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if UnitDefs[unitDefID].customParams.unitrole == "Commander" then
		local unitTechLevel = UnitDefs[unitDefID].customParams.techlevel
		if unitTechLevel == "tech0" then
			teamTechLevel[unitTeam] = 0
		end
		if unitTechLevel == "tech1" then
			teamTechLevel[unitTeam] = 1
		end
		if unitTechLevel == "tech2" then
			teamTechLevel[unitTeam] = 2
		end
		if unitTechLevel == "tech3" then
			teamTechLevel[unitTeam] = 3
		end
		if unitTechLevel == "tech4" then
			teamTechLevel[unitTeam] = 4
		end
	end
end

function gadget:UnitDestroyed(unitID)
	mexes[unitID] = nil
end

function gadget:GameFrame(frame)
	--Let the player know that they have enough income to tech up
	if frame > 4500 then -- Don't do shit for 2.5 minutes
		if frame%1800 == 21 then -- frame%1800 = every 60 seconds == 21 means do it on frame 21 of 30 (we just chose a random frame so that it doesn't get lumped in with a ton stuff from other gadgets)
			--Spring.Echo("My tech level is: " .. myTechLevel)
			for unitID in pairs(mexes) do
				local unitTeam = Spring.GetUnitTeam(unitID)
				if not (mexTechLevel[Spring.GetUnitDefID(unitID)] >= teamTechLevel[unitTeam]) and Spring.GetTeamLuaAI(unitTeam) then -- We need to use this to check and see if we *can* upgrade the tech level of the mex by comparing it to myTechLevel
					Spring.GiveOrderToUnit(unitID, CMD_MORPH_QUEUE, {}, {})
				end
			end
		end
	end
end
