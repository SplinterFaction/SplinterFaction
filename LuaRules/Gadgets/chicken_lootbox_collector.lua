function gadget:GetInfo()
	return {
		name = "Chicken Lootbox Collector",
		desc = "Send transports to collect lone lootboxes and drop them somewhere in friendly area",
		author = "Damgam",
		date = "2023",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if (not gadgetHandler:IsSyncedCode()) or (not Spring.Utilities.Gametype.IsChickens()) then
	return false
end

function SetCount(set)
    local count = 0
    for k in pairs(set) do
        count = count + 1
    end
    return count
end

-- number represents maximum tier of lootbox that can be picked up
local transportsList = {
    [UnitDefNames["lozcrane"].id] = 2,
    [UnitDefNames["fedcondor"].id] = 2,
    [UnitDefNames["loztitan"].id] = 4,
    [UnitDefNames["fedeagle"].id] = 4,
}

local lootboxList = {
    [UnitDefNames["lootbox_t1"].id] = 1,
    [UnitDefNames["lootbox_t2"].id] = 2,
    [UnitDefNames["lootbox_t3"].id] = 3,
    [UnitDefNames["lootbox_t4"].id] = 4,
}

local spawnerList = {
    [UnitDefNames["chickensbeacon"].id] = true,
}

local teams = Spring.GetTeamList()
for _, teamID in ipairs(teams) do
    local teamLuaAI = Spring.GetTeamLuaAI(teamID)
    if (teamLuaAI and string.find(teamLuaAI, "Chickens")) then
        chickenTeamID = teamID
        chickenAllyTeamID = select(6, Spring.GetTeamInfo(chickenTeamID))
        break
    end
end

local aliveLootboxes = {}
local aliveLootboxesCount = 0
local aliveSpawners = {}
local aliveSpawnersCount = 0
local lastTransportSentFrame = 0
local handledLootboxesList = {}
local RaptorStartboxXMin, RaptorStartboxZMin, RaptorStartboxXMax, RaptorStartboxZMax = Spring.GetAllyTeamStartBox(chickenAllyTeamID)

local config = VFS.Include('LuaRules/Configs/chicken_spawn_defs.lua')

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
    if lootboxList[unitDefID] then
        aliveLootboxes[unitID] = lootboxList[unitDefID]
        aliveLootboxesCount = aliveLootboxesCount + 1
    end

    if spawnerList[unitDefID] then
        aliveSpawners[unitID] = true
        aliveSpawnersCount = aliveSpawnersCount + 1
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
    if aliveLootboxes[unitID] then
        aliveLootboxes[unitID] = nil
        aliveLootboxesCount = aliveLootboxesCount - 1
    end

    if aliveSpawners[unitID] then
        aliveSpawners[unitID] = nil
        aliveSpawnersCount = aliveSpawnersCount - 1
    end
end

function gadget:GameFrame(frame)
    if frame%30 == 12 and Spring.GetGameRulesParam("chickenQueenAnger") >= 1 and Spring.GetGameRulesParam("chickenTechAnger") >= config.airStartAnger then
        if aliveLootboxesCount > 0 and aliveSpawnersCount > 0 then
            if SetCount(handledLootboxesList) > 0 then
                handledLootboxesList = {}
            end
            if frame-math.ceil(18000/aliveLootboxesCount) > lastTransportSentFrame then -- 10 minutes for 1 lootbox alive
                local targetLootboxID = -1
                local loopCount = 0
                local success = false
                for lootboxID, lootboxTier in pairs(aliveLootboxes) do
                    local lootboxPosX, lootboxPosY, lootboxPosZ = Spring.GetUnitPosition(lootboxID)
                    if not (lootboxPosX > RaptorStartboxXMin and lootboxPosX < RaptorStartboxXMax and lootboxPosZ > RaptorStartboxZMin and lootboxPosZ < RaptorStartboxZMax) then
                        if math.random(0,aliveLootboxesCount) == 0 and not handledLootboxesList[lootboxID] then
                            for transportDefID, transportTier in pairs(transportsList) do
                                if math.random(0,SetCount(transportsList)) == 0 and transportTier >= lootboxTier and transportTier <= lootboxTier+1 and not handledLootboxesList[lootboxID] then
                                    for spawnerID, _ in pairs(aliveSpawners) do
                                        if math.random(0,SetCount(aliveSpawners)) == 0 and not handledLootboxesList[lootboxID] then
                                            targetLootboxID = lootboxID
                                            local spawnerPosX, spawnerPosY, spawnerPosZ = Spring.GetUnitPosition(spawnerID)
                                            for j = 1,5 do
                                                if math.random() <= config.spawnChance then
                                                    local transportID = Spring.CreateUnit(transportDefID, spawnerPosX+math.random(-256, 256), spawnerPosY+100, spawnerPosZ+math.random(-256, 256), math.random(0,3), chickenTeamID)
                                                    if transportID then
                                                        handledLootboxesList[targetLootboxID] = true
                                                        success = true
                                                        lastTransportSentFrame = frame
                                                        Spring.GiveOrderToUnit(transportID, CMD.LOAD_UNITS, {targetLootboxID}, {"shift"})
                                                        for i = 1,10 do
                                                            local randomX = math.random(RaptorStartboxXMin, RaptorStartboxXMax)
                                                            local randomZ = math.random(RaptorStartboxZMin, RaptorStartboxZMax)
                                                            local randomY = math.max(0, Spring.GetGroundHeight(randomX, randomZ))
                                                            Spring.GiveOrderToUnit(transportID, CMD.UNLOAD_UNITS, {randomX, randomY, randomZ, 1024}, {"shift"})
                                                            if i == 10 then
                                                                Spring.GiveOrderToUnit(transportID, CMD.MOVE, {randomX+math.random(-256,256), randomY, randomZ+math.random(-256,256)}, {"shift"})
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                        if success == true then
                                            break
                                        end
                                    end
                                end
                                if success == true then
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end