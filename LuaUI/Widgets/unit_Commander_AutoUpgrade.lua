function widget:GetInfo()
	return {
		name      = "Commander AutoUpgrade",
		desc      = "Automatically Upgrade Commanders when income targets have been hit",
		author    = "",
		date      = "",
		license   = "",
		layer     = 0,
		enabled   = true
	}
end

local CMD_MORPH = 31410
local CMD_MORPH_QUEUE = 34410
local myTechLevel = 0
local myTeamID = Spring.GetMyTeamID

local comm = {}

function widget:UnitCreated(unitID, unitDefID, teamID)
	if teamID == Spring.GetLocalTeamID() and UnitDefs[unitDefID].customParams.unitrole == "Commander" then
		comm[unitID] = true
	end
end

-- Get my current tech level the ghetto way
function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam == myTeamID() and UnitDefs[unitDefID].customParams.unitrole == "Commander" then
		myTechLevel = UnitDefs[unitDefID].customParams.techlevel
		if myTechLevel == "tech0" then
			myTechLevel = 0
		end
		if myTechLevel == "tech1" then
			myTechLevel = 1
		end
		if myTechLevel == "tech2" then
			myTechLevel = 2
		end
		if myTechLevel == "tech3" then
			myTechLevel = 3
		end
		if myTechLevel == "tech4" then
			myTechLevel = 4
		end
	end
end

function widget:GameFrame(frame)
	if frame > 450 then -- 450 = 15 seconds
		if frame%450 == 18 then
			su, sm = math.round(Spring.GetTeamRulesParam(myTeamID(), "supplyUsed") or 0), math.round(Spring.GetTeamRulesParam(myTeamID(), "supplyMax") or 0)
			ec, es, ep, ei, ee = Spring.GetTeamResources(myTeamID(), "energy")
			mc, ms, mp, mi, me = Spring.GetTeamResources(myTeamID(), "metal")
			for unitID in pairs(comm) do
				if myTechLevel == 0 then
					if mi >= 10 and ei >= 170 then
						Spring.GiveOrderToUnit(unitID, CMD_MORPH_QUEUE, {}, {"shift"})
					end
				end

				if myTechLevel == 1 then
					if mi >= 20 and ei >= 560 then
						Spring.GiveOrderToUnit(unitID, CMD_MORPH_QUEUE, {}, {"shift"})
					end
				end

				if myTechLevel == 2 then
					if mi >= 40 and ei >= 1040 then
						Spring.GiveOrderToUnit(unitID, CMD_MORPH_QUEUE, {}, {"shift"})
					end
				end

				if myTechLevel == 3 then
					if mi >= 80 and ei >= 3120 then
						Spring.GiveOrderToUnit(unitID, CMD_MORPH_QUEUE, {}, {"shift"})
					end
				end
			end
		end
	end
end
