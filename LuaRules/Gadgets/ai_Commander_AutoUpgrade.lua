function gadget:GetInfo()
	return {
		name      = "AI Commander AutoUpgrade",
		desc      = "Automatically add Commanders to the upgrade queue",
		author    = "",
		date      = "",
		license   = "",
		layer     = 0,
		enabled   = true
	}
end

local CMD_MORPH_QUEUE = 34410
local teamTechLevel = {}
local commTechLevel = {}
local commanders = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.name == "fedcommander" or unitDef.name == "lozcommander" then
		commTechLevel[unitDefID] = 0
	end
	if unitDef.name == "fedcommander_up1" or unitDef.name == "lozcommander_up1" then
		commTechLevel[unitDefID] = 1
	end
	if unitDef.name == "fedcommander_up2" or unitDef.name == "lozcommander_up2" then
		commTechLevel[unitDefID] = 2
	end
	if unitDef.name == "fedcommander_up3" or unitDef.name == "lozcommander_up3" then
		commTechLevel[unitDefID] = 3
	end
	if unitDef.name == "fedcommander_up4" or unitDef.name == "lozcommander_up4" then
		commTechLevel[unitDefID] = 4
	end
end

function gadget:UnitCreated(unitID, unitDefID, teamID)
	if UnitDefs[unitDefID].customParams.unitrole == "Commander" then
		if not (UnitDefs[unitDefID].customParams.requiretech == "tech4") then -- Don't add T4
			commanders[unitID] = true
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
	commanders[unitID] = nil
end

function gadget:GameFrame(frame)
	--Let the player know that they have enough income to tech up
	if frame > 450 then -- 450 = 15 seconds
		if frame%450 == 18 then
			--Spring.Echo("My tech level is: " .. myTechLevel)
			for unitID in pairs(commanders) do
				local unitTeam = Spring.GetUnitTeam(unitID)
				if not (commTechLevel[Spring.GetUnitDefID(unitID)] >= teamTechLevel[unitTeam]) and Spring.GetTeamLuaAI(unitTeam) then -- We need to use this to check and see if we *can* upgrade the tech level of the mex by comparing it to myTechLevel
					local su, sm = math.round(Spring.GetTeamRulesParam(unitTeam, "supplyUsed") or 0), math.round(Spring.GetTeamRulesParam(myTeamID(), "supplyMax") or 0)
					local ec, es, ep, ei, ee = Spring.GetTeamResources(unitTeam, "energy")
					local mc, ms, mp, mi, me = Spring.GetTeamResources(unitTeam, "metal")
					for unitID in pairs(commanders) do
						if teamTechLevel == 0 then
							if mi >= 10 and ei >= 170 then
								Spring.GiveOrderToUnit(unitID, CMD_MORPH_QUEUE, {}, {"shift"})
							end
						end

						if teamTechLevel == 1 then
							if mi >= 20 and ei >= 560 then
								Spring.GiveOrderToUnit(unitID, CMD_MORPH_QUEUE, {}, {"shift"})
							end
						end

						if teamTechLevel == 2 then
							if mi >= 40 and ei >= 1040 then
								Spring.GiveOrderToUnit(unitID, CMD_MORPH_QUEUE, {}, {"shift"})
							end
						end

						if teamTechLevel == 3 then
							if mi >= 80 and ei >= 3120 then
								Spring.GiveOrderToUnit(unitID, CMD_MORPH_QUEUE, {}, {"shift"})
							end
						end
					end
				end
			end
		end
	end
end
