function widget:GetInfo()
	return {
		name      = "Statistics tracking and Event Notifications",
		desc      = "Tracks statistics and handles notifications",
		author    = "",
		date      = "",
		license   = "",
		layer     = 0,
		enabled   = true
	}
end

local killsFile = "luaui/config/sf_ckc"
local killCount = 0
local myTeamID = Spring.GetMyTeamID
local myAllyTeamID = Spring.GetMyAllyTeamID
local unitAllyTeamID = Spring.GetUnitAllyTeam

local notificationTimeout = 10

local allyCommHPNotificationTimeout = 60
local myCommHPNotificationTimeout = 60
local allyT4HPNotificationTimeout = 60
local goliathNotificationTimeout = 60
local mammothNotificationTimeout = 60
local juggernautNotificationTimeout = 60
local silverbackNotificationTimeout = 60
local allyJuggernautNotificationTimeout = 60
local allySilverbackNotificationTimeout = 60
local energyNotificationTimeout = 30
local metalNotificationTimeout = 30
local supplyNotificationTimeout = 30
local enemyT2Notification = 0
local enemyT3Notification = 0
local enemyT4Notification = 0
local enemyCommanderSpottedTimeout = 60
local enemyCloakingMechSpottedTimeout = 60
local enemyShieldingTankSpottedTimeout = 60
local upgradeNotificationTimeout = 10
local myMexNotificationTimeout = 15

local meT1Notification = 0
local meT2Notification = 0
local meT3Notification = 0
local meT4Notification = 0

local dontRemindMeToTechToT1 = 0
local dontRemindMeToTechToT2 = 0
local dontRemindMeToTechToT3 = 0
local dontRemindMeToTechToT4 = 0

local notificationQueue = {}
local dt = 1 -- Timeout Decrement

--[[
Description of how to enqueue stuff, because I get loopy and forget how to do things...

Whenever you want to display a notification, instead of directly echoing the message, you will add it to the queue:

local function enqueueNotification(message)
  table.insert(notificationQueue, { message = message })
end

With this queuing system in place, multiple notifications will be added to the queue instead of being directly enacted, and they will be played one after another as the `notificationTimeout` reaches 0.
]]--

function widget:Initialize()

	notificationTimeout = 0
	allyCommHPNotificationTimeout = 0
	myCommHPNotificationTimeout = 0
	allyT4HPNotificationTimeout = 0
	goliathNotificationTimeout = 0
	mammothNotificationTimeout = 0
	juggernautNotificationTimeout = 0
	silverbackNotificationTimeout = 0
	allyJuggernautNotificationTimeout = 0
	allySilverbackNotificationTimeout = 0
	energyNotificationTimeout = 0
	metalNotificationTimeout = 0
	supplyNotificationTimeout = 0
	enemyCommanderSpottedTimeout = 0
	enemyCloakingMechSpottedTimeout = 0
	enemyShieldingTankSpottedTimeout = 0
	upgradeNotificationTimeout = 0
	myMexNotificationTimeout = 0

	---- See if the kills file exists
	--if not VFS.FileExists(killsFile) then
	--	Spring.Echo("THE KILLS FILE DOES NOT EXIST SO I WILL CREATE IT")
	--	file = io.open(killsFile, "w");
	--	file:write("")
	--	file:close()
	--end
	--
	---- Load previous kill count from file
	--if VFS.FileExists(killsFile) then
	--	Spring.Echo("THE KILLS FILE EXISTS")
	--	local file = io.open(killsFile, "r")
	--	local content = file:read("*all")
	--	io.close(file)
	--	killCount = tonumber(content) or 0
	--end
end

--So apparently, unitdestroyed in widgetspace is only called when one of your own units dies
--Unfortunately, the only way I can see this ever actually working is to have a gadget that adds enemy team commander deaths to a rulesparam and keeps incrementing a counter. Then,in gameover() in the widget we can read the number there, add it to the number we got from the existing file, and write that to the count file. Unfortunately I quite possibly lack the skill to do this. This widget will stick around until a figure out how to do it. Everything is a damn project.
--function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
--	Spring.Echo("A UNIT DIED")
--	if unitTeam and attackerTeam ~= myTeamID() then
--		Spring.Echo("THE UNIT IS NOT ON MY TEAM")
--		if Spring.GetUnitDefID(unitID) == UnitDefNames["lozcommander"].id or
--				Spring.GetUnitDefID(unitID) == UnitDefNames["lozcommander_up1"].id or
--				Spring.GetUnitDefID(unitID) == UnitDefNames["lozcommander_up2"].id or
--				Spring.GetUnitDefID(unitID) == UnitDefNames["lozcommander_up3"].id or
--				Spring.GetUnitDefID(unitID) == UnitDefNames["lozcommander_up4"].id or
--				Spring.GetUnitDefID(unitID) == UnitDefNames["fedcommander"].id or
--				Spring.GetUnitDefID(unitID) == UnitDefNames["fedcommander_up1"].id or
--				Spring.GetUnitDefID(unitID) == UnitDefNames["fedcommander_up2"].id or
--				Spring.GetUnitDefID(unitID) == UnitDefNames["fedcommander_up3"].id or
--				Spring.GetUnitDefID(unitID) == UnitDefNames["fedcommander_up4"].id then
--			Spring.Echo("AN ENEMY COMMANDER DIED")
--			killCount = killCount + 1
--			WriteKillCountToFile()
--		end
--	end
--end

--function WriteKillCountToFile()
--	local file = io.open(killsFile, "w")
--	file:write(tostring(killCount))
--	io.close(file)
--end


function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam == myTeamID() then
		-- Announce to the player that we have hit a tier
		if UnitDefs[unitDefID].customParams.techlevel == "tech1" then
			if meT1Notification == 0 then
				table.insert(notificationQueue, { message = "met1" })
				meT1Notification = 1
			end
		end
		if UnitDefs[unitDefID].customParams.techlevel == "tech2" then
			if meT2Notification == 0 then
				table.insert(notificationQueue, { message = "met2" })
				meT2Notification = 1
			end
		end
		if UnitDefs[unitDefID].customParams.techlevel == "tech3" then
			if meT3Notification == 0 then
				table.insert(notificationQueue, { message = "met3" })
				meT3Notification = 1
			end
		end
		if UnitDefs[unitDefID].customParams.techlevel == "tech4" then
			if meT4Notification == 0 then
				table.insert(notificationQueue, { message = "met4" })
				meT4Notification = 1
			end
		end
	end
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	-- Spring.Echo("A unit is taking damage")
	-- Spring.Echo("The Unit's Team is " .. unitTeam)
	local unitHP,unitMaxHP = Spring.GetUnitHealth(unitID)
	local x,y,z = Spring.GetUnitPosition(unitID)
	if unitTeam ~= myTeamID() then
		-- Ally high value units under attack
		if UnitDefs[unitDefID].customParams.unittype == "Commander" then
			if allyCommHPNotificationTimeout <= 0 then
				if unitHP <= unitMaxHP * 0.5 then
					table.insert(notificationQueue, { message = "allycomWarning" })
					Spring.SetLastMessagePosition (x,y,z)
				end
				allyCommHPNotificationTimeout = 60
			end
		end
		if UnitDefs[unitDefID].customParams.requiretech == "tech4" and UnitDefs[unitDefID].customParams.unittype ~= "Commander" then
			if UnitDefs[unitDefID].name == "fedjuggernaut" then
				if allyJuggernautNotificationTimeout <= 0 then
					if unitHP <= unitMaxHP * 0.5 then
						table.insert(notificationQueue, { message = "allyjuggernautWarning" })
						Spring.SetLastMessagePosition (x,y,z)
					end
					allyJuggernautNotificationTimeout = 60
				end
			end
			if UnitDefs[unitDefID].name == "lozsilverback" then
				if allySilverbackNotificationTimeout <= 0 then
					if unitHP <= unitMaxHP * 0.75 then
						table.insert(notificationQueue, { message = "allysilverbackWarning" })
						Spring.SetLastMessagePosition (x,y,z)
					end
					allySilverbackNotificationTimeout = 60
				end
			end
		end
	end

	if unitTeam == myTeamID() then
		if UnitDefs[unitDefID].customParams.unittype == "Commander" then
			if myCommHPNotificationTimeout <= 0 then
				if unitHP <= unitMaxHP * 0.25 then
					table.insert(notificationQueue, { message = "mycomCriticalDamageWarning" })
					Spring.SetLastMessagePosition (x,y,z)
				elseif unitHP <= unitMaxHP * 0.5 then
					table.insert(notificationQueue, { message = "mycomHeavyDamageWarning" })
					Spring.SetLastMessagePosition (x,y,z)
				end
				myCommHPNotificationTimeout = 30
			end
		end
		if UnitDefs[unitDefID].customParams.requiretech == "tech3" and UnitDefs[unitDefID].customParams.unittype ~= "Commander" then
			if UnitDefs[unitDefID].name == "fedgoliath" then
				if goliathNotificationTimeout <= 0 then
					if unitHP <= unitMaxHP * 0.5 then
						table.insert(notificationQueue, { message = "mygoliathWarning" })
						Spring.SetLastMessagePosition (x,y,z)
					end
					goliathNotificationTimeout = 60
				end
			end
			if UnitDefs[unitDefID].name == "lozmammoth" then
				if mammothNotificationTimeout <= 0 then
					if unitHP <= unitMaxHP * 0.75 then
						table.insert(notificationQueue, { message = "mymammothWarning" })
						Spring.SetLastMessagePosition (x,y,z)
					end
					mammothNotificationTimeout = 60
				end
			end
		end
		if UnitDefs[unitDefID].customParams.requiretech == "tech4" and UnitDefs[unitDefID].customParams.unittype ~= "Commander" then
			if UnitDefs[unitDefID].name == "fedjuggernaut" then
				if juggernautNotificationTimeout <= 0 then
					if unitHP <= unitMaxHP * 0.5 then
						table.insert(notificationQueue, { message = "myjuggernautWarning" })
						Spring.SetLastMessagePosition (x,y,z)
					end
					juggernautNotificationTimeout = 60
				end
			end
			if UnitDefs[unitDefID].name == "lozsilverback" then
				if silverbackNotificationTimeout <= 0 then
					if unitHP <= unitMaxHP * 0.75 then
						table.insert(notificationQueue, { message = "mysilverbackWarning" })
						Spring.SetLastMessagePosition (x,y,z)
					end
					silverbackNotificationTimeout = 60
				end
			end
		end
		if UnitDefs[unitDefID].customParams.metal_extractor then
			if myMexNotificationTimeout <= 0 then
					table.insert(notificationQueue, { message = "myMexDamageWarning" })
				Spring.SetLastMessagePosition (x,y,z)
				myMexNotificationTimeout = 15
			end
		end
	end
end

function widget:UnitEnteredLos(unitID, unitTeam)
	local unitDefID = Spring.GetUnitDefID(unitID)
	local x,y,z = Spring.GetUnitPosition(unitID)
	--Spring.Echo(1)
	if unitTeam ~= myAllyTeamID() then
		--Spring.Echo(2)
		if UnitDefs[unitDefID].customParams.unitrole == "Commander" then
			--Spring.Echo(3)
			if enemyCommanderSpottedTimeout <= 0 then
				--Spring.Echo(4)
				table.insert(notificationQueue, { message = "enemycommanderSpotted" })
				enemyCommanderSpottedTimeout = 60
				Spring.SetLastMessagePosition (x,y,z)
			end
		end
		if UnitDefs[unitDefID].customParams.requiretech == "tech2" then
			if enemyT2Notification == 0 then
				table.insert(notificationQueue, { message = "enemyt2" })
				enemyT2Notification = 1
				Spring.SetLastMessagePosition (x,y,z)
			end
		end
		if UnitDefs[unitDefID].customParams.requiretech == "tech3" then
			if enemyT3Notification == 0 then
				table.insert(notificationQueue, { message = "enemyt3" })
				enemyT3Notification = 1
				Spring.SetLastMessagePosition (x,y,z)
			end
		end
		if UnitDefs[unitDefID].customParams.requiretech == "tech4" then
			if enemyT4Notification == 0 then
				table.insert(notificationQueue, { message = "enemyt4" })
				enemyT4Notification = 1
				Spring.SetLastMessagePosition (x,y,z)
			end
		end
		if UnitDefs[unitDefID].name == "feddeleter" then
			if enemyCloakingMechSpottedTimeout <= 0 then
				table.insert(notificationQueue, { message = "enemyt3CloakingMech" })
				enemyCloakingMechSpottedTimeout = 60
				Spring.SetLastMessagePosition (x,y,z)
			end
		end
		if UnitDefs[unitDefID].name == "lozprotector" then
			if enemyShieldingTankSpottedTimeout <= 0 then
				table.insert(notificationQueue, { message = "enemyt3ShieldingTank" })
				enemyShieldingTankSpottedTimeout = 60
				Spring.SetLastMessagePosition (x,y,z)
			end
		end
	end
	if UnitDefs[unitDefID].name == "lootbox_t1" then
		table.insert(notificationQueue, { message = "lootboxdetectedt1" })
		Spring.SetLastMessagePosition (x,y,z)
	end
	if UnitDefs[unitDefID].name == "lootbox_t2" then
		table.insert(notificationQueue, { message = "lootboxdetectedt2" })
		Spring.SetLastMessagePosition (x,y,z)
	end
	if UnitDefs[unitDefID].name == "lootbox_t3" then
		table.insert(notificationQueue, { message = "lootboxdetectedt3" })
		Spring.SetLastMessagePosition (x,y,z)
	end
	if UnitDefs[unitDefID].name == "lootbox_t4" then
		table.insert(notificationQueue, { message = "lootboxdetectedt4" })
		Spring.SetLastMessagePosition (x,y,z)
	end

end

function WG.AddNotification(notificationType)
	if notificationType == "energyWarning" then
		if energyNotificationTimeout <= 0 then
			table.insert(notificationQueue, { message = "energyWarning" })
			energyNotificationTimeout = 30
			Spring.SendMessageToPlayer(Spring.GetMyPlayerID(), "Build more power plants!")
		end
	end
	if notificationType == "metalWarning" then
		if metalNotificationTimeout <= 0 then
			table.insert(notificationQueue, { message = "metalWarning" })
			metalNotificationTimeout = 30
			Spring.SendMessageToPlayer(Spring.GetMyPlayerID(), "You are excessing metal!")
		end
	end
	if notificationType == "supplyWarning" then
		if supplyNotificationTimeout <= 0 then
			table.insert(notificationQueue, { message = "supplyWarning" })
			supplyNotificationTimeout = 30
			Spring.SendMessageToPlayer(Spring.GetMyPlayerID(), "Build more supply depots!")
		end
	end
	if notificationType == "morphFinished" then
		if upgradeNotificationTimeout <= 0 then
			table.insert(notificationQueue, { message = "upgradecomplete" })
			upgradeNotificationTimeout = 10
			Spring.SendMessageToPlayer(Spring.GetMyPlayerID(), "Unit upgrade complete!")
		end
	end
end

local function updateNotifications(dt)
	-- Decrement the timeout
	notificationTimeout = notificationTimeout - dt
	allyCommHPNotificationTimeout = allyCommHPNotificationTimeout - dt
	allyT4HPNotificationTimeout = allyT4HPNotificationTimeout - dt
	myCommHPNotificationTimeout = myCommHPNotificationTimeout - dt
	goliathNotificationTimeout = goliathNotificationTimeout - dt
	mammothNotificationTimeout = mammothNotificationTimeout - dt
	juggernautNotificationTimeout = juggernautNotificationTimeout - dt
	silverbackNotificationTimeout = silverbackNotificationTimeout - dt
	allyJuggernautNotificationTimeout = allyJuggernautNotificationTimeout - dt
	allySilverbackNotificationTimeout = allySilverbackNotificationTimeout - dt
	energyNotificationTimeout = energyNotificationTimeout - dt
	metalNotificationTimeout = metalNotificationTimeout - dt
	supplyNotificationTimeout = supplyNotificationTimeout - dt
	enemyCommanderSpottedTimeout = enemyCommanderSpottedTimeout - dt
	enemyCloakingMechSpottedTimeout = enemyCloakingMechSpottedTimeout - dt
	enemyShieldingTankSpottedTimeout = enemyShieldingTankSpottedTimeout - dt
	upgradeNotificationTimeout = upgradeNotificationTimeout - dt
	myMexNotificationTimeout = myMexNotificationTimeout -dt


	-- Spring.Echo("notificationTimeout is " .. notificationTimeout)

	-- Check if the timeout has reached 0
	if notificationTimeout <= 0 then
		-- Check if there are notifications in the queue
		if #notificationQueue > 0 then
			-- Dequeue the next notification
			local nextNotification = table.remove(notificationQueue, 1)

			-- Play the sound file
			Spring.PlaySoundFile(nextNotification.message, VOLUI)
			-- Spring.Echo(nextNotification.message)

			-- Reset the timeout
			notificationTimeout = 5
		end
	end
end

local function purgeNotificationQueue()
	-- Remove many entries (such as dumping all queued events)
	local startRecord = 1
	local endRecord = 100
	 -- Loop through table indices  1 - 100 and remove them ... If there are more than 3 or 4, we seriously fucked up, but going to 100 just to be sure.
	for recordsToRemove = endRecord, startRecord, -1 do
		table.remove(notificationQueue, recordsToRemove)
	end
end

function widget:GameFrame(frame)
	if frame%30 == 5 then
		updateNotifications(dt)
	end

	--Let the player know that they have enough income to tech up
	if frame > 450 then
		if frame%450 == 5 then -- frame%450 = every 15 seconds
			-- Get the current resourcing stats
			su, sm = math.round(Spring.GetTeamRulesParam(myTeamID(), "supplyUsed") or 0), math.round(Spring.GetTeamRulesParam(myTeamID(), "supplyMax") or 0)
			ec, es, ep, ei, ee = Spring.GetTeamResources(myTeamID(), "energy")
			mc, ms, mp, mi, me = Spring.GetTeamResources(myTeamID(), "metal")
			Spring .Echo ("energy " .. ei)
			Spring .Echo ("metal " .. mi)
			if meT1Notification == 0 and dontRemindMeToTechToT1 == 0 then
				if mi >= 10 and ei >= 170 then
					table.insert(notificationQueue, { message = "enoughincomefort1" })
					-- Spring.Echo("You have enough income to tech to tier 1!")
					dontRemindMeToTechToT1 = 1
				end
			end
			if meT1Notification == 1 and meT2Notification == 0 and dontRemindMeToTechToT2 == 0 then
				if mi >= 20 and ei >= 560 then
					table.insert(notificationQueue, { message = "enoughincomefort2" })
					-- Spring.Echo("You have enough income to tech to tier 2!")
					dontRemindMeToTechToT2 = 1
				end
			end
			if meT1Notification == 1 and meT2Notification == 1 and meT3Notification == 0 and dontRemindMeToTechToT3 == 0 then
				if mi >= 40 and ei >= 1040 then
					table.insert(notificationQueue, { message = "enoughincomefort3" })
					-- Spring.Echo("You have enough income to tech to tier 3!")
					dontRemindMeToTechToT3 = 1
				end
			end
			if meT1Notification == 1 and meT2Notification == 1 and meT3Notification == 1 and meT4Notification == 0 and dontRemindMeToTechToT4 == 0 then
				if mi >= 80 and ei >= 3120 then
					table.insert(notificationQueue, { message = "enoughincomefort4" })
					-- Spring.Echo("You have enough income to tech to tier 4!")
					dontRemindMeToTechToT4 = 1
				end
			end
		end
	end
end

function widget:Shutdown()

end