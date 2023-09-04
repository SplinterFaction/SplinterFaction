function widget:GetInfo()
	return {
		name      = "MetalExtractor AutoUpgrade",
		desc      = "Automatically add metal extractors to the upgrade queue",
		author    = "",
		date      = "",
		license   = "",
		layer     = 0,
		enabled   = false
	}
end

local CMD_MORPH_QUEUE = 34410
local myTechLevel = 0
local myTeamID = Spring.GetMyTeamID

local mexTechLevel = {}
local mexes = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if UnitDefs[unitDefID].name == "fedmetalextractor" or UnitDefs[unitDefID].name == "lozmetalextractor" then
		mexTechLevel[unitDefID] = 0
	end
	if UnitDefs[unitDefID].name == "fedmetalextractor_up1" or UnitDefs[unitDefID].name == "lozmetalextractor_up1" then
		mexTechLevel[unitDefID] = 1
	end
	if UnitDefs[unitDefID].name == "fedmetalextractor_up2" or UnitDefs[unitDefID].name == "lozmetalextractor_up2" then
		mexTechLevel[unitDefID] = 2
	end
	if UnitDefs[unitDefID].name == "fedmetalextractor_up3" or UnitDefs[unitDefID].name == "lozmetalextractor_up3" then
		mexTechLevel[unitDefID] = 3
	end
	if UnitDefs[unitDefID].name == "fedmetalextractor_up4" or UnitDefs[unitDefID].name == "lozmetalextractor_up4" then
		mexTechLevel[unitDefID] = 4
	end
end

function widget:UnitCreated(unitID, unitDefID, teamID)
	if teamID == Spring.GetLocalTeamID() and UnitDefs[unitDefID].customParams.metal_extractor then
		if UnitDefs[unitDefID].customParams.requiretech == "tech4" then
			-- Don't add t4 to the table
		else
			mexes[unitID] = true
		end
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

function widget:UnitDestroyed(unitID)
	mexes[unitID] = nil
end

function widget:GameFrame(frame)
	--Let the player know that they have enough income to tech up
	if frame > 4500 then -- Don't do shit for 2.5 minutes
		if frame%1800 == 21 then -- frame%1800 = every 60 seconds == 21 means do it on frame 21 of 30 (we just chose a random frame so that it doesn't get lumped in with a ton stuff from other widgets)
			Spring.Echo("My tech level is: " .. myTechLevel)
			for unitID in pairs(mexes) do
				if mexTechLevel[Spring.GetUnitDefID(unitID)] >=  myTechLevel then -- We need to use this to check and see if we *can* upgrade the tech level of the mex by comparing it to myTechLevel
					Spring.Echo("This mex level is: " .. mexTechLevel[Spring.GetUnitDefID(unitID)] .. ", Which is equal to or greater than my tech level, so we'll check it on the next pass")
					-- don't do a goddamn thing
				else
					-- do something goddamnit
					Spring.GiveOrderToUnit(unitID, CMD_MORPH_QUEUE, {}, {})
				end
			end
		end
	end
end
