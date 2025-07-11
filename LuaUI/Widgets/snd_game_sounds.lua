function widget:GetInfo()
	return {
		name = "Unit Alert sounds",
		desc = "Plays various unit sounds (under attack, cloak, decloak, self-d countdown, etc.)",
		author = "DeadnightWarrior, Jools, knorke, very_bad_soldier",
		date = "Sep, 2013",
		license = "GPLv2",
		version = "1.1",
		layer = 1,
		enabled = true
	}
end
----------------------------------------------------------------------------
local alarmInterval				= 60		-- seconds, interval between sound alarms for same unit type
local positionAlarmInterval		= 60		-- seconds, interval between sound alarms for same attack zone
local commanderAlarmInterval	= 20 		-- seconds, interval for sound alarms for other units after commander was attacked
local textInterval				= 10 		-- seconds, interval for text notifications for same unit type
local SoundInterval				= 20		-- seconds, interval between all alarms (affects all alarms except commander alarms)
local commanderSoundInterval	= 7			-- seconds, interval between sound notifications for Commander
local commanderTextInterval		= 5			-- seconds, interval between text notifications for Commander or for all text notifications
----------------------------------------------------------------------------                
local GetLocalTeamID			= Spring.GetLocalTeamID
local PlaySoundFile				= Spring.PlaySoundFile
local GetTimer					= Spring.GetTimer
local DiffTimers				= Spring.DiffTimers
local IsUnitInView				= Spring.IsUnitInView
local GetUnitPosition			= Spring.GetUnitPosition
local SetLastMessagePosition	= Spring.SetLastMessagePosition
local GetSpectatingState		= Spring.GetSpectatingState
local GetTeamInfo				= Spring.GetTeamInfo
local GetGameFrame				= Spring.GetGameFrame
local AreTeamsAllied			= Spring.AreTeamsAllied
local GetUnitTeam				= Spring.GetUnitTeam
local GetUnitIsDead				= Spring.GetUnitIsDead
local random					= math.random
local Echo						= Spring.Echo
local myTeamID					= Spring.GetMyTeamID()
----------------------------------------------------------------------------
local noAlertUnits				= {}
local lastAlarmTime				= nil
local lastTextAlarm				= nil
local localTeamID				= nil
local commanderTable			= {}
local lastCommanderAlarm		= nil
local alarmTimes				= {}
alarmTimes["text"]				= {}
alarmTimes["sound"]				= {}
alarmTimes["position"]			= {}
local spamBlock					= false

----------------------------------------------------------------------------
local cloak1 = "cloak"
local decloak1 = "cloak"
local cloak2 = "cloak"
local decloak2 = "cloak"

local alert = "alert sounds 3"
local cancel = 'sounds/ui/cantdo.wav'
local movefailed = 'sounds/ui/cantdo.wav'

local ADUnits = {}
local CMD_SELFD = CMD.SELFD

local volume = 3.0
local VOLUI
local VOLBATTLE
----------------------------------------------------------------------------

local function round(num, idp)
	return string.format("%." .. (idp or 0) .. "f", num)
end

function widget:Initialize()
    localTeamID = GetLocalTeamID()   
	if (GetSpectatingState() == true) then
		widgetHandler:RemoveWidget()
		return false
	end
    lastAlarmTime = GetTimer()
    math.randomseed(os.time())
	
	for id, unitDef in ipairs(UnitDefs) do
		if unitDef.customParams.iscommander and (not unitDef.customParams.isdecoycommander) then
			if unitDef.name then
				commanderTable[id] = true
			end
		end
		
		if unitDef.customParams.noalert  then
			noAlertUnits[id] = true
		end
		
		
	end
	
	VOLUI = 0.015*Spring.GetConfigInt('snd_volui') or 1.0 					-- snd_volui = [0,200]
	VOLBATTLE = 0.015*Spring.GetConfigInt('snd_volbattle') or 1.0	 		-- snd_volbattle = [0,200]
	Echo("Unit sounds loaded. Volumes (battle,ui,[0,200]):", VOLBATTLE/0.015,VOLUI/0.015)
end

function widget:UnitCloaked(unitID, unitDefID, teamID) 
	local x,y,z = GetUnitPosition(unitID)
	local _,_,_,_,side = GetTeamInfo(teamID)
		
	--if side == "arm" then
	--	PlaySoundFile(cloak1,VOLBATTLE,x,y,z,0,0,0,'battle')
	--else
	--	PlaySoundFile(cloak2,VOLBATTLE,x,y,z,0,0,0,'battle')
	--end
end

function widget:UnitDecloaked(unitID, unitDefID, teamID) 
	local x,y,z = GetUnitPosition(unitID)
	local _,_,_,_,side = GetTeamInfo(teamID)
	
	--if side == "arm" then
	--	PlaySoundFile(decloak1,VOLBATTLE,x,y,z,0,0,0,'battle')
	--else
	--	PlaySoundFile(decloak2,VOLBATTLE,x,y,z,0,0,0,'battle')
	--end
end

function widget:GameFrame(gameFrame)
	for unitID, startFrame in pairs(ADUnits) do
		if GetUnitTeam(unitID) == myTeamID and not GetUnitIsDead(unitID) then
			if (gameFrame - startFrame) == 30 then -- adjust timing to be 10 frames before actual message, so it syncs better with engine timing
				-- Spring.Echo('30')
				PlaySoundFile(alert,VOLBATTLE,x,y,z,0,0,0,'battle')
			elseif (gameFrame - startFrame) == 60 then
				-- Spring.Echo('60')
				PlaySoundFile(alert,VOLBATTLE,x,y,z,0,0,0,'battle')
			elseif (gameFrame - startFrame) == 90 then
				-- Spring.Echo('90')
				PlaySoundFile(alert,VOLBATTLE,x,y,z,0,0,0,'battle')
			elseif (gameFrame - startFrame) == 120 then
				-- Spring.Echo('120')
				PlaySoundFile(alert,VOLBATTLE,x,y,z,0,0,0,'battle')
			elseif (gameFrame - startFrame) == 150 then
				-- Spring.Echo('150')
				PlaySoundFile(alert,VOLBATTLE,x,y,z,0,0,0,'battle')
			elseif (gameFrame - startFrame) == 180 then
				-- Spring.Echo('180')
				PlaySoundFile(alert,VOLBATTLE,x,y,z,0,0,0,'battle')
			elseif (gameFrame - startFrame) == 210 then
				-- Spring.Echo('210')
				PlaySoundFile(alert,VOLBATTLE,x,y,z,0,0,0,'battle')
			elseif (gameFrame - startFrame) == 240 then
				-- Spring.Echo('240')
				PlaySoundFile(alert,VOLBATTLE,x,y,z,0,0,0,'battle')
			elseif (gameFrame - startFrame) == 270 then
				-- Spring.Echo('270')
				PlaySoundFile(alert,VOLBATTLE,x,y,z,0,0,0,'battle')
			elseif (gameFrame - startFrame) == 300 then
				-- Spring.Echo('300')
				PlaySoundFile(alert,VOLBATTLE,x,y,z,0,0,0,'battle')
			elseif (gameFrame - startFrame) == 330 then
				-- Spring.Echo('330')
				PlaySoundFile(alert,VOLBATTLE,x,y,z,0,0,0,'battle')
			elseif (gameFrame - startFrame) == 360 then
				-- Spring.Echo('360')
				PlaySoundFile(alert,VOLBATTLE,x,y,z,0,0,0,'battle')
			elseif (gameFrame - startFrame) == 390 then
				-- Spring.Echo('390')
				PlaySoundFile(alert,VOLBATTLE,x,y,z,0,0,0,'battle')
			elseif (gameFrame - startFrame) == 420 then
				-- Spring.Echo('420')
				PlaySoundFile(alert,VOLBATTLE,x,y,z,0,0,0,'battle')
			elseif (gameFrame - startFrame) == 450 then
				-- Spring.Echo('450')
				PlaySoundFile(alert,VOLBATTLE,x,y,z,0,0,0,'battle')
			end
		end
	end
end

function widget:GameOver()
	widgetHandler:RemoveWidget()
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	if cmdID == CMD_SELFD then
		if not ADUnits[unitID] then
			local frame = GetGameFrame()			
			ADUnits[unitID] = frame
			--PlaySoundFile(CD1)
		else
			ADUnits[unitID] = nil
			PlaySoundFile(cancel, 1, nil, "ui")
		end
	end
	return true
end

function widget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if ADUnits[unitID] then
		ADUnits[unitID] = nil
	end
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	
	if ADUnits[unitID] then
		ADUnits[unitID] = nil
	end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	
	if ADUnits[unitID] and (not AreTeamsAllied(unitTeam, newTeam)) then
		ADUnits[unitID] = nil
	end
end

function widget:UnitDamaged (unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, attackerID, attackerDefID, attackerTeam)
	
	if (localTeamID ~= unitTeam or IsUnitInView(unitID) or noAlertUnits[unitDefID]) then
		return --ignore other teams and units in view, and also units that have noalert tag
	end
	
	local now = GetTimer()
	local udef
	local isCommander = commanderTable[unitDefID]
	local textValue = 	(isCommander and commanderTextInterval) or textInterval
	local soundValue = 	(isCommander and commanderSoundInterval) or alarmInterval
	local x,y,z = GetUnitPosition(unitID)
	local posx = tostring(round(x/1000,0))
	local posz = tostring(round(z/1000,0))
	local zone = table.concat({posx,posz})
		
	local textBlock = alarmTimes["text"][unitDefID] and DiffTimers(now, alarmTimes["text"][unitDefID]) < textValue
	local soundBlock = alarmTimes["sound"][unitDefID] and DiffTimers(now, alarmTimes["sound"][unitDefID]) < soundValue
	local positionBlock = alarmTimes["position"][zone] and (DiffTimers(now, alarmTimes["position"][zone]) < positionAlarmInterval)
		
	-- return before text notification condition
	if textBlock then return end
	
	-- proceed to text notification
	alarmTimes["text"][unitDefID] = now
	if isCommander then 		
		udef = UnitDefs[unitDefID]
		Echo("-> " .. udef.humanName  ..": under attack!") --print notification
		
		-- return before sound notification condition
		if soundBlock then return end
		lastCommanderAlarm = now
	else
		udef = UnitDefs[unitDefID]
		
		if lastTextAlarm and (DiffTimers(now, lastTextAlarm) < commanderTextInterval) then
			if not spamBlock then Echo("Units are under attack!") end --print notification
			spamBlock	= true
		else
			Echo("-> " .. udef.humanName  ..": under attack!") --print notification
			spamBlock	= false
		end
		lastTextAlarm = now
		
		-- return before sound notification condition
		if soundBlock then return end
		if positionBlock then return end
		
		-- return if commander was attacked recently
		if lastCommanderAlarm and (DiffTimers(now, lastCommanderAlarm) < commanderAlarmInterval) then return end
		alarmTimes["sound"][unitDefID] = now
		alarmTimes["position"][zone] = now
	end
	
	-- play alarm sound if it wasnt played recently
	if (lastAlarmTime and (DiffTimers(now, lastAlarmTime) > SoundInterval)) or isCommander then		
		alarmTimes["sound"][unitDefID] = now
		alarmTimes["position"][zone] = now
		lastAlarmTime = now
		local x,y,z = GetUnitPosition(unitID)

		local snd 
		if isCommander then
			snd = 'commander_under_attack'
		else
			snd = 'units_under_attack'
		end
		-- ALL units have volume = 1.0 in unitdef. Some units, such as critters and DT:s have no volume, making the widget fail on nil index.
		-- this was the previous lookup code for volume: udef.sounds.underattack[1].volume
		-- now we read volume setting from spring config instead.
		PlaySoundFile(snd, VOLUI, nil, "ui") 

		if (x and y and z) then SetLastMessagePosition(x,y,z) end
	end
end

function widget:UnitMoveFailed(unitID, unitDefID, unitTeam)
	Echo(UnitDefs[unitDefID].humanName .. ": Can't reach destination!")
	local x,y,z = GetUnitPosition(unitID)
	if (x and y and z) then SetLastMessagePosition(x,y,z) end
	
	PlaySoundFile(movefailed, 1, nil, "ui")
end 

--changing teams, rejoin, becoming spec etc
function widget:PlayerChanged(playerID)
    localTeamID = GetLocalTeamID()  
	if (GetSpectatingState() == true) then
		widgetHandler:RemoveWidget()
		return false
	end
end