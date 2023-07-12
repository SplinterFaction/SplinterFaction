function gadget:GetInfo()
	return {
		name = "Chicken Nuke Spawner",
		desc = "Spawns a capturable nuke facility in the center of the map",
		author = "",
		date = "",
		license = "",
		layer = 0,
		enabled = true
	}
end

local MAP_SIZE_X = Game.mapSizeX
local MAP_SIZE_Z = Game.mapSizeZ
local MAP_CENTER_X = Game.mapSizeX * 0.5
local MAP_CENTER_Z = Game.mapSizeZ * 0.5

local listOfStructures = { -- number represents how many of this we want to spawn
	["nukesilo"] = {
		amount = math.max(1, math.ceil((MAP_SIZE_X+MAP_SIZE_Z)*0.000125)), -- one per 4000 square-elmos
		captureDifficulty = 16,
		captureRange = 384,
	},
}

local aliveStructures = {}

if (not Spring.Utilities.Gametype.IsChickens()) or (not gadgetHandler:IsSyncedCode()) then
	return
end

local nearbyCaptureLibrary = VFS.Include("luarules/utilities/damgam_lib/nearby_capture.lua")
local positionCheckLibrary = VFS.Include("luarules/utilities/damgam_lib/position_checks.lua")

local teams = Spring.GetTeamList()
for _, teamID in ipairs(teams) do
	local teamLuaAI = Spring.GetTeamLuaAI(teamID)
	if (teamLuaAI and string.find(teamLuaAI, "Chickens")) then
		chickenTeamID = teamID
		chickenAllyTeamID = select(6, Spring.GetTeamInfo(chickenTeamID))
		ChickenStartboxXMin, ChickenStartboxZMin, ChickenStartboxXMax, ChickenStartboxZMax = Spring.GetAllyTeamStartBox(chickenAllyTeamID)
		if ChickenStartboxXMin == 0 and ChickenStartboxXMax == MAP_SIZE_X and ChickenStartboxZMin == 0 and ChickenStartboxZMax == MAP_SIZE_X then
			chickenHasNoStartbox = true
		end
		break
	end
end

function gadget:GameFrame(frame)
	if frame == 30 then
		for name,data in pairs(listOfStructures) do
			for j = 1,data.amount do
				for i = 1,100 do
					local posx = math.random(0,MAP_SIZE_X)
					local posz = math.random(0,MAP_SIZE_X)
					local posy = Spring.GetGroundHeight(posx,posz)
					local canSpawnStructure = positionCheckLibrary.FlatAreaCheck(posx, posy, posz, 128)
					if canSpawnStructure then
						canSpawnStructure = positionCheckLibrary.MapEdgeCheck(posx, posy, posz, 128)
					end
					if canSpawnStructure then
						canSpawnStructure = positionCheckLibrary.OccupancyCheck(posx, posy, posz, 128)
					end
					if canSpawnStructure then
						canSpawnStructure = positionCheckLibrary.VisibilityCheckEnemy(posx, posy, posz, 32, chickenAllyTeamID, true, true, true)
					end
					if canSpawnStructure then
						if (not chickenHasNoStartbox) and posx > ChickenStartboxXMin and posx < ChickenStartboxXMax and posz > ChickenStartboxZMin and posz < ChickenStartboxZMax then -- we don't want this crap to spawn in chicken startbox
							canSpawnStructure = false
						end
					end
					if canSpawnStructure then
						local unitID = Spring.CreateUnit(name, posx, posy, posz, 0, chickenTeamID)
						if unitID then
							Spring.SetUnitNeutral(unitID, true)
							Spring.SetUnitAlwaysVisible(unitID,true)
							aliveStructures[unitID] = data
							break
						end
					end
				end
			end
		end
	end
	if frame%30 == 16 then
		for unitID, data in pairs(aliveStructures) do
			nearbyCaptureLibrary.NearbyCapture(unitID, data.captureDifficulty, data.captureRange)
		end
	end
end

function gadget:UnitDestroyed(unitID)
	if aliveStructures[unitID] then
		aliveStructures[unitID] = nil
	end
end

function gadget:UnitGiven(unitID, unitDefID, unitNewTeam, unitOldTeam)
	if aliveStructures[unitID] then
		if unitNewTeam == chickenTeamID then
			Spring.SetUnitNeutral(unitID, true)
		else
			Spring.SetUnitNeutral(unitID, false)
		end
		Spring.SetUnitAlwaysVisible(unitID,true)
	end
end