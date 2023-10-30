function gadget:GetInfo()
	return {
		name      = "AI Commander AutoUpgrade",
		desc      = "Automatically add Commanders to the upgrade queue",
		author    = "Your Name",
		date      = "Date",
		license   = "GPL",
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

function gadget:UnitCreated(unitID, unitDefID, teamID)
	local unitDef = UnitDefs[unitDefID]
	if unitDef.customParams.unitrole == "Commander" then
		if unitDef.customParams.requiretech ~= "tech4" then
			commanders[unitID] = teamID
		end
	end
end

function gadget:UnitDestroyed(unitID)
	commanders[unitID] = nil
end

function gadget:GameFrame(frame)
	if frame > 450 then
		if frame % 450 == 18 then
			for unitID, teamID in pairs(commanders) do
				local unitTeam = Spring.GetUnitTeam(unitID)
				if Spring.GetTeamLuaAI(unitTeam) then
					local teamTech = teamTechLevel[teamID] or 0
					if teamTech < 4 then
						local su, sm = math.round(Spring.GetTeamRulesParam(unitTeam, "supplyUsed") or 0), math.round(Spring.GetTeamRulesParam(unitTeam, "supplyMax") or 0)
						local ec, es, ep, ei, ee = Spring.GetTeamResources(unitTeam, "energy")
						local mc, ms, mp, mi, me = Spring.GetTeamResources(unitTeam, "metal")
						local unitDefID = Spring.GetUnitDefID(unitID)
						local commTech = commTechLevel[unitDefID] or 0

						if commTech == 0 then
							if mi >= 10 and ei >= 170 then
								Spring.GiveOrderToUnit(unitID, CMD_MORPH_QUEUE, {}, {"shift"})
							end
						end

						if commTech == 1 then
							if mi >= 20 and ei >= 560 then
								Spring.GiveOrderToUnit(unitID, CMD_MORPH_QUEUE, {}, {"shift"})
							end
						end

						if commTech == 2 then
							if mi >= 40 and ei >= 1040 then
								Spring.GiveOrderToUnit(unitID, CMD_MORPH_QUEUE, {}, {"shift"})
							end
						end

						if commTech == 3 then
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