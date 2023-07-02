function widget:GetInfo()
	return {
		name      = "Statistics tracking and Event Notifications",
		desc      = "Tracks statistics and handles notifications",
		author    = "",
		date      = "",
		license   = "",
		layer     = 0,
		enabled   = false
	}
end

local killsFile = "luaui/config/sf_ckc"
local killCount = 0
local myTeamID = Spring.GetMyTeamID
local myAllyTeamID = Spring.GetMyAllyTeamID
local unitAllyTeamID = Spring.GetUnitAllyTeam
local notificationTimeout = 10
local allyCommHPNotificationTimeout = 60
local allyT4HPNotificationTimeout = 60
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


function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	-- Spring.Echo("A unit is taking damage")
	-- Spring.Echo("The Unit's Team is " .. unitTeam)
	local unitHP,unitMaxHP = Spring.GetUnitHealth(unitID)
	if unitTeam ~= myTeamID() then
		-- Ally high value units under attack
		if UnitDefs[unitDefID].customParams.unittype == "Commander" then
			if allyCommHPNotificationTimeout <= 0 then
				if unitHP <= unitMaxHP * 0.5 then
					table.insert(notificationQueue, { message = "An Allied Commander has taken heavy damage" })
				end
			end
		end
		if UnitDefs[unitDefID].customParams.requiretech == "tech4" and UnitDefs[unitDefID].customParams.unittype ~= "Commander" then
			if allyT4HPNotificationTimeout <= 0 then
				if unitHP <= unitMaxHP * 0.5 then
					table.insert(notificationQueue, { message = "An Allied Tier 4 unit has taken heavy damage" })
				end
			end
		end
	end

	if unitTeam == myTeamID() then
		if UnitDefs[unitDefID].customParams.unittype == "Commander" then
			-- Spring.Echo("My Commander is Taking Damage")
		end
		if UnitDefs[unitDefID].customParams.requiretech == "tech3" and UnitDefs[unitDefID].customParams.unittype ~= "Commander" then
			table.insert(notificationQueue, { message = "My Tier 3 Unit is Taking Damage" })
			-- Spring.Echo("I'm adding t3 unit taking damage to the queue")
		end
		if UnitDefs[unitDefID].customParams.requiretech == "tech4" and UnitDefs[unitDefID].customParams.unittype ~= "Commander" then
				-- Spring.Echo("My Tier 4 Unit is Taking Damage")
		end
	end
end

function widget:UnitEnteredLos(unitID, unitTeam, allyTeam)
	local unitDefID = Spring.GetUnitDefID(unitID)
	if allyTeam ~= myAllyTeamID then
		if UnitDefs[unitDefID].customParams.unittype == "Commander" then
			-- Spring.Echo("An Enemy Commander has been spotted")
		end
		if UnitDefs[unitDefID].customParams.requiretech == "tech4" and UnitDefs[unitDefID].customParams.unittype ~= "Commander" then
			-- Spring.Echo("An Enemy Tier 4 Unit has been spotted")
		end
		if UnitDefs[unitDefID].name == "feddeleter" then
			-- Spring.Echo("An Enemy Tier 3 Cloaking Mech has been spotted")
		end
		if UnitDefs[unitDefID].name == "lozprotector" then
			-- Spring.Echo("An Enemy Tier 3 Shielding Tank has been spotted")
		end
	end
end

local function updateNotifications(dt)
	-- Decrement the timeout
	notificationTimeout = notificationTimeout - dt
	allyCommHPNotificationTimeout = allyCommHPNotificationTimeout - dt
	allyT4HPNotificationTimeout = allyT4HPNotificationTimeout - dt

	-- Spring.Echo("notificationTimeout is " .. notificationTimeout)

	-- Check if the timeout has reached 0
	if notificationTimeout <= 0 then
		-- Check if there are notifications in the queue
		if #notificationQueue > 0 then
			-- Dequeue the next notification
			local nextNotification = table.remove(notificationQueue, 1)

			-- Echo the notification message
			Spring.Echo(nextNotification.message)

			-- Reset the timeout
			notificationTimeout = 10
		end
	end
end

function widget:GameFrame(frame)
	if frame%30 == 5 then
		updateNotifications(dt)
	end
end

