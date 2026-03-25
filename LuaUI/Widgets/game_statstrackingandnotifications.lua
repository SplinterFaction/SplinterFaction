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

-- FIX 1: Replaced 18 individual timeout variables with a single table.
-- To add a new timeout, just add an entry here. updateNotifications() handles the rest.
local timeouts = {
	notification             = 10,
	allyCommHP               = 60,
	myCommHP                 = 60,
	allyT4HP                 = 60,
	goliath                  = 60,
	mammoth                  = 60,
	juggernaut               = 60,
	silverback               = 60,
	allyJuggernaut           = 60,
	allySilverback           = 60,
	energy                   = 30,
	metal                    = 30,
	supply                   = 30,
	enemyCommanderSpotted    = 60,
	enemyCloakingMechSpotted = 60,
	enemyShieldingTankSpotted= 60,
	upgrade                  = 10,
	myMex                    = 15,
}

local enemyT2Notification = 0
local enemyT3Notification = 0
local enemyT4Notification = 0

local meT1Notification = 0
local meT2Notification = 0
local meT3Notification = 0
local meT4Notification = 0

local dontRemindMeToTechToT1 = 0
local dontRemindMeToTechToT2 = 0
local dontRemindMeToTechToT3 = 0
local dontRemindMeToTechToT4 = 0

local notificationQueue = {}
local dt = 1 -- Timeout Decrement (1 second, matches the GameFrame call frequency of every 30 frames at 30fps)

--[[
HOW TO ADD A NEW NOTIFICATION — end to end guide

Let's say you want to warn the player when an enemy T3 artillery unit is spotted.
Follow these four steps:

────────────────────────────────────────────────────────────────────
STEP 1 — Add a sound file
────────────────────────────────────────────────────────────────────
Drop your .wav or .ogg file somewhere under luaui/sounds/, e.g.:
    luaui/sounds/enemyt3artillery.wav

The message string you use in the queue (Step 3) must match this filename
exactly, without the extension, as that is what Spring.PlaySoundFile() expects.

────────────────────────────────────────────────────────────────────
STEP 2 — Add a cooldown timeout (if needed)
────────────────────────────────────────────────────────────────────
If this notification can fire more than once (i.e. it's not a one-time
"first sighting" flag), add a cooldown entry to the timeouts table at the
top of the file:

    local timeouts = {
        ...
        enemyT3ArtillerySpotted = 60,   -- 60 seconds between alerts
    }

Skip this step if the notification should only ever fire once (like the
enemyT2/T3/T4 tier-spotted flags). In that case you'll use a plain 0/1
flag variable instead, like enemyT2Notification.

────────────────────────────────────────────────────────────────────
STEP 3 — Enqueue the notification in the right game event
────────────────────────────────────────────────────────────────────
Find the widget callback where the trigger lives — UnitEnteredLos for
visibility events, UnitDamaged for HP events, UnitFinished for
build-complete events, GameFrame for periodic resource checks, or
WG.AddNotification for calls coming from other widgets.

Inside that callback, check your cooldown (or one-time flag), insert
into the queue, reset the cooldown, and optionally snap the camera:

    if UnitDefs[unitDefID].name == "fedhowitzer" then
        if timeouts.enemyT3ArtillerySpotted <= 0 then
            table.insert(notificationQueue, { message = "enemyt3artillery" })
            timeouts.enemyT3ArtillerySpotted = 60
            Spring.SetLastMessagePosition(x, y, z)
        end
    end

The queue fires notifications one at a time as timeouts.notification
counts down, so you never need to worry about sounds overlapping.

────────────────────────────────────────────────────────────────────
STEP 4 — Add a testing shortcut in widget:Initialize() (optional)
────────────────────────────────────────────────────────────────────
Uncomment or add a line in the testing block inside widget:Initialize()
so you can zero out the timeout and verify the sound plays in-game
without waiting for the real trigger condition:

    --timeouts.enemyT3ArtillerySpotted = 0

That's it. The decrement loop in updateNotifications() picks up any new
timeouts table entry automatically — no other plumbing required.
]]--

function widget:Initialize()

	------------ Uncomment these to make testing easier
	--timeouts.notification = 0
	--timeouts.allyCommHP = 0
	--timeouts.myCommHP = 0
	--timeouts.allyT4HP = 0
	--timeouts.goliath = 0
	--timeouts.mammoth = 0
	--timeouts.juggernaut = 0
	--timeouts.silverback = 0
	--timeouts.allyJuggernaut = 0
	--timeouts.allySilverback = 0
	--timeouts.energy = 0
	--timeouts.metal = 0
	--timeouts.supply = 0
	--timeouts.enemyCommanderSpotted = 0
	--timeouts.enemyCloakingMechSpotted = 0
	--timeouts.enemyShieldingTankSpotted = 0
	--timeouts.upgrade = 0
	--timeouts.myMex = 0
	------------

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
			if timeouts.allyCommHP <= 0 then
				if unitHP <= unitMaxHP * 0.5 then
					table.insert(notificationQueue, { message = "allycomWarning" })
					Spring.SetLastMessagePosition (x,y,z)
					-- FIX 3: Timeout now only resets when the HP threshold was actually met,
					-- so the cooldown isn't wasted on hits above the warning threshold.
					timeouts.allyCommHP = 60
				end
			end
		end
		if UnitDefs[unitDefID].customParams.requiretech == "tech4" and UnitDefs[unitDefID].customParams.unittype ~= "Commander" then
			if UnitDefs[unitDefID].name == "fedjuggernaut" then
				if timeouts.allyJuggernaut <= 0 then
					if unitHP <= unitMaxHP * 0.5 then
						table.insert(notificationQueue, { message = "allyjuggernautWarning" })
						Spring.SetLastMessagePosition (x,y,z)
						timeouts.allyJuggernaut = 60
					end
				end
			end
			if UnitDefs[unitDefID].name == "lozsilverback" then
				if timeouts.allySilverback <= 0 then
					if unitHP <= unitMaxHP * 0.75 then
						table.insert(notificationQueue, { message = "allysilverbackWarning" })
						Spring.SetLastMessagePosition (x,y,z)
						timeouts.allySilverback = 60
					end
				end
			end
		end
	end

	if unitTeam == myTeamID() then
		if UnitDefs[unitDefID].customParams.unittype == "Commander" then
			if timeouts.myCommHP <= 0 then
				if unitHP <= unitMaxHP * 0.25 then
					table.insert(notificationQueue, { message = "mycomCriticalDamageWarning" })
					Spring.SetLastMessagePosition (x,y,z)
					timeouts.myCommHP = 30
				elseif unitHP <= unitMaxHP * 0.5 then
					table.insert(notificationQueue, { message = "mycomHeavyDamageWarning" })
					Spring.SetLastMessagePosition (x,y,z)
					timeouts.myCommHP = 30
				end
				-- FIX 3 applied here: timeout was previously reset outside the HP checks,
				-- which suppressed future warnings even when no notification was queued.
			end
		end
		if UnitDefs[unitDefID].customParams.requiretech == "tech3" and UnitDefs[unitDefID].customParams.unittype ~= "Commander" then
			if UnitDefs[unitDefID].name == "fedgoliath" then
				if timeouts.goliath <= 0 then
					if unitHP <= unitMaxHP * 0.5 then
						table.insert(notificationQueue, { message = "mygoliathWarning" })
						Spring.SetLastMessagePosition (x,y,z)
						timeouts.goliath = 60
					end
				end
			end
			if UnitDefs[unitDefID].name == "lozmammoth" then
				if timeouts.mammoth <= 0 then
					if unitHP <= unitMaxHP * 0.75 then
						table.insert(notificationQueue, { message = "mymammothWarning" })
						Spring.SetLastMessagePosition (x,y,z)
						timeouts.mammoth = 60
					end
				end
			end
		end
		if UnitDefs[unitDefID].customParams.requiretech == "tech4" and UnitDefs[unitDefID].customParams.unittype ~= "Commander" then
			if UnitDefs[unitDefID].name == "fedjuggernaut" then
				if timeouts.juggernaut <= 0 then
					if unitHP <= unitMaxHP * 0.5 then
						table.insert(notificationQueue, { message = "myjuggernautWarning" })
						Spring.SetLastMessagePosition (x,y,z)
						timeouts.juggernaut = 60
					end
				end
			end
			if UnitDefs[unitDefID].name == "lozsilverback" then
				if timeouts.silverback <= 0 then
					if unitHP <= unitMaxHP * 0.75 then
						table.insert(notificationQueue, { message = "mysilverbackWarning" })
						Spring.SetLastMessagePosition (x,y,z)
						timeouts.silverback = 60
					end
				end
			end
		end
		if UnitDefs[unitDefID].customParams.metal_extractor then
			if timeouts.myMex <= 0 then
				table.insert(notificationQueue, { message = "myMexDamageWarning" })
				Spring.SetLastMessagePosition (x,y,z)
				timeouts.myMex = 15
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
			if timeouts.enemyCommanderSpotted <= 0 then
				--Spring.Echo(4)
				table.insert(notificationQueue, { message = "enemycommanderSpotted" })
				timeouts.enemyCommanderSpotted = 60
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
			if timeouts.enemyCloakingMechSpotted <= 0 then
				table.insert(notificationQueue, { message = "enemyt3CloakingMech" })
				timeouts.enemyCloakingMechSpotted = 60
				Spring.SetLastMessagePosition (x,y,z)
			end
		end
		if UnitDefs[unitDefID].name == "lozprotector" then
			if timeouts.enemyShieldingTankSpotted <= 0 then
				table.insert(notificationQueue, { message = "enemyt3ShieldingTank" })
				timeouts.enemyShieldingTankSpotted = 60
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

-- FIX 4: Removed the direct Spring.SendMessageToPlayer() calls from WG.AddNotification.
-- Previously, resource/upgrade warnings fired a chat message immediately, bypassing the
-- queue entirely. Now all output goes through the queue for consistent pacing.
-- If you want the chat ping back for a specific notification, add it inside the
-- updateNotifications() dispatch block alongside PlaySoundFile().
function WG.AddNotification(notificationType)
	if notificationType == "energyWarning" then
		if timeouts.energy <= 0 then
			table.insert(notificationQueue, { message = "energyWarning" })
			timeouts.energy = 30
		end
	end
	if notificationType == "metalWarning" then
		if timeouts.metal <= 0 then
			table.insert(notificationQueue, { message = "metalWarning" })
			timeouts.metal = 30
		end
	end
	if notificationType == "supplyWarning" then
		if timeouts.supply <= 0 then
			table.insert(notificationQueue, { message = "supplyWarning" })
			timeouts.supply = 30
		end
	end
	if notificationType == "morphFinished" then
		if timeouts.upgrade <= 0 then
			table.insert(notificationQueue, { message = "upgradecomplete" })
			timeouts.upgrade = 10
		end
	end
end

local function updateNotifications(dt)
	-- FIX 1: Decrement all timeouts in a single loop instead of 18 individual lines.
	for key, _ in pairs(timeouts) do
		timeouts[key] = timeouts[key] - dt
	end

	-- Spring.Echo("notificationTimeout is " .. timeouts.notification)

	-- Check if the timeout has reached 0
	if timeouts.notification <= 0 then
		-- Check if there are notifications in the queue
		if #notificationQueue > 0 then
			-- Dequeue the next notification
			local nextNotification = table.remove(notificationQueue, 1)

			-- Play the sound file
			Spring.PlaySoundFile(nextNotification.message, VOLUI)
			-- Spring.Echo(nextNotification.message)

			-- Reset the timeout
			timeouts.notification = 5
		end
	end
end

local function purgeNotificationQueue()
	-- FIX 2: Replaced the fragile 100-iteration loop with a simple table reset.
	-- The old approach called table.remove() up to 100 times regardless of actual queue size.
	notificationQueue = {}
end

function widget:GameFrame(frame)
	if frame%30 == 5 then
		updateNotifications(dt)
	end

	if frame == 5 then
		local isSpectating = Spring.GetSpectatingState()
		if isSpectating then
			widgetHandler:RemoveWidget()
		end
	end

	--Let the player know that they have enough income to tech up
	if frame > 450 then
		if frame%450 == 5 then -- frame%450 = every 15 seconds
			-- Get the current resourcing stats
			-- Spring.GetTeamResources ( number teamID, string "metal" | "energy" )
			-- return: nil | number currentLevel, number storage, number pull, number income, number expense, number share, number sent, number received

			su, sm = math.round(Spring.GetTeamRulesParam(myTeamID(), "supplyUsed") or 0), math.round(Spring.GetTeamRulesParam(myTeamID(), "supplyMax") or 0)
			ec, es, ep, ei, ee = Spring.GetTeamResources(myTeamID(), "energy")
			mc, ms, mp, mi, me = Spring.GetTeamResources(myTeamID(), "metal")

			local resourcePrompts = Spring.GetConfigInt("evo_resourceprompts", 1)
			if resourcePrompts == 1 then
				-- If supply used is 85% or more, warn
				if su >= sm * 0.85 then
					WG.AddNotification("supplyWarning")
				end

				-- If Energy reserves are at 20% or below, warn
				if ec <= es * 0.2 then
					WG.AddNotification("energyWarning")
				end

				-- If Metal Storage is 80% or above, warn
				if mc >= ms * 0.8 then
					WG.AddNotification("metalWarning")
				end
			end

			-- Spring .Echo ("energy " .. ei)
			-- Spring .Echo ("metal " .. mi)
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