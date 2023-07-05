function widget:GetInfo()
	return {
		name	= "Music Player",
		desc	= "Plays music and offers volume controls",
		author	= "Damgam",
		date	= "2021/2023",
		license = "GNU GPL, v2 or later",
		layer	= -3,
		enabled	= true
	}
end

Spring.CreateDir("music/custom/loading")
Spring.CreateDir("music/custom/peace")
Spring.CreateDir("music/custom/warlow")
Spring.CreateDir("music/custom/warhigh")
Spring.CreateDir("music/custom/war")
Spring.CreateDir("music/custom/bossfight")
Spring.CreateDir("music/custom/gameover")
Spring.CreateDir("music/custom/menu")

----------------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------------

local showGUI = false
local minSilenceTime = 30
local maxSilenceTime = 120
local warLowLevel = 750
local warHighLevel = 15000
local warMeterResetTime = 60 -- seconds
local interruptionMinimumTime = 30 -- seconds
local interruptionMaximumTime = 60 -- seconds

----------------------------------------------------------------------
----------------------------------------------------------------------

local function applySpectatorThresholds()
	warLowLevel = warLowLevel*2
	warHighLevel = warHighLevel*2
	minSilenceTime = minSilenceTime*2
	maxSilenceTime = maxSilenceTime*2
	appliedSpectatorThresholds = true
	--Spring.Echo("[Music Player] Spectator mode enabled")
end

math.randomseed( os.clock() )

local peaceTracks = {}
local warhighTracks = {}
local warlowTracks = {}
local gameoverTracks = {}
local bossFightTracks = {}

local menuTracks = {}
local loadingTracks = {}

local currentTrack
local peaceTracksPlayCounter, warhighTracksPlayCounter, warlowTracksPlayCounter, bossFightTracksPlayCounter, gameoverTracksPlayCounter
local fadeOutSkipTrack = false
local interruptionEnabled
local silenceTimerEnabled
local deviceLostSafetyCheck = 0
local interruptionTime = math.random(interruptionMinimumTime, interruptionMaximumTime)
local gameFrame = 0
local serverFrame = 0
local bossHasSpawned = false

local function ReloadMusicPlaylists()
	deviceLostSafetyCheck = 0
	---------------------------------COLLECT MUSIC------------------------------------

	local allowedExtensions = "{*.ogg,*.mp3}"
	-- New Soundtrack List
	local musicDirNew 			= 'music/original'
	local peaceTracksNew 			= VFS.DirList(musicDirNew..'/peace', allowedExtensions)
	local warhighTracksNew 			= VFS.DirList(musicDirNew..'/warhigh', allowedExtensions)
	local warlowTracksNew 			= VFS.DirList(musicDirNew..'/warlow', allowedExtensions)
	local gameoverTracksNew 		= VFS.DirList(musicDirNew..'/gameover', allowedExtensions)
	local bossFightTracksNew   		= VFS.DirList(musicDirNew..'/bossfight', allowedExtensions)
	local menuTracksNew 			= VFS.DirList(musicDirNew..'/menu', allowedExtensions)
	local loadingTracksNew   		= VFS.DirList(musicDirNew..'/loading', allowedExtensions)

	-- Custom Soundtrack List
	local musicDirCustom 		= 'music/custom'
	local peaceTracksCustom 		= VFS.DirList(musicDirCustom..'/peace', allowedExtensions)
	local warhighTracksCustom 		= VFS.DirList(musicDirCustom..'/warhigh', allowedExtensions)
	local warlowTracksCustom 		= VFS.DirList(musicDirCustom..'/warlow', allowedExtensions)
	local warTracksCustom 			= VFS.DirList(musicDirCustom..'/war', allowedExtensions)
	local gameoverTracksCustom 		= VFS.DirList(musicDirCustom..'/gameover', allowedExtensions)
	local bossFightTracksCustom 	= VFS.DirList(musicDirCustom..'/bossfight', allowedExtensions)
	local menuTracksCustom 			= VFS.DirList(musicDirCustom..'/menu', allowedExtensions)
	local loadingTracksCustom  		= VFS.DirList(musicDirCustom..'/loading', allowedExtensions)

	-----------------------------------SETTINGS---------------------------------------

	interruptionEnabled 			= Spring.GetConfigInt('UseSoundtrackInterruption', 1) == 1
	silenceTimerEnabled 			= Spring.GetConfigInt('UseSoundtrackSilenceTimer', 1) == 1
	local newSoundtrackEnabled 		= 1
	local customSoundtrackEnabled	= 1

	-------------------------------CREATE PLAYLISTS-----------------------------------

	peaceTracks = {}
	warhighTracks = {}
	warlowTracks = {}
	gameoverTracks = {}
	bossFightTracks = {}
	menuTracks = {}
	loadingTracks = {}

	if newSoundtrackEnabled then
		table.append(peaceTracks, peaceTracksNew)
		table.append(warhighTracks, warhighTracksNew)
		table.append(warlowTracks, warlowTracksNew)
		table.append(gameoverTracks, gameoverTracksNew)
		table.append(bossFightTracks, bossFightTracksNew)
		table.append(menuTracks, menuTracksNew)
		table.append(loadingTracks, loadingTracksNew)
	end

	if customSoundtrackEnabled then
		table.append(peaceTracks, baseTracksCustom)
		table.append(warhighTracks, baseTracksCustom)
		table.append(warlowTracks, baseTracksCustom)

		table.append(peaceTracks, peaceTracksCustom)
		table.append(warhighTracks, warhighTracksCustom)
		table.append(warlowTracks, warlowTracksCustom)
		table.append(warhighTracks, warTracksCustom)
		table.append(warlowTracks, warTracksCustom)
		table.append(gameoverTracks, gameoverTracksCustom)
		table.append(bossFightTracks, bossFightTracksCustom)
		table.append(menuTracks, menuTracksCustom)
		table.append(loadingTracks, loadingTracksCustom)
	end

	if #bossFightTracks == 0 then
		bossFightTracks = warhighTracks
	end

	if #loadingTracks == 0 then
		loadingTracks = warhighTracks
	end

	if #gameoverTracks == 0 then
		gameoverTracks = peaceTracks
	end

	if #menuTracks == 0 then
		menuTracks = peaceTracks
	end
	----------------------------------SHUFFLE--------------------------------------

	local function shuffleMusic(playlist)
		local originalPlaylist = {}
		table.append(originalPlaylist, playlist)
		local shuffledPlaylist = {}
		if #originalPlaylist > 0 then
			repeat
				local r = math.random(#originalPlaylist)
				table.insert(shuffledPlaylist, originalPlaylist[r])
				table.remove(originalPlaylist, r)
			until(#originalPlaylist == 0)
		else
			shuffledPlaylist = originalPlaylist
		end
		return shuffledPlaylist
	end

	peaceTracks 	= shuffleMusic(peaceTracks)
	warhighTracks 	= shuffleMusic(warhighTracks)
	warlowTracks 	= shuffleMusic(warlowTracks)
	gameoverTracks 	= shuffleMusic(gameoverTracks)
	bossFightTracks = shuffleMusic(bossFightTracks)

	Spring.Echo("----- MUSIC PLAYER PLAYLIST -----")
	Spring.Echo("----- peaceTracks -----")
	for i = 1,#peaceTracks do
		Spring.Echo(peaceTracks[i])
	end
	Spring.Echo("----- warlowTracks -----")
	for i = 1,#warlowTracks do
		Spring.Echo(warlowTracks[i])
	end
	Spring.Echo("----- warhighTracks -----")
	for i = 1,#warhighTracks do
		Spring.Echo(warhighTracks[i])
	end
	Spring.Echo("----- gameoverTracks -----")
	for i = 1,#gameoverTracks do
		Spring.Echo(gameoverTracks[i])
	end
	Spring.Echo("----- bossFightTracks -----")
	for i = 1,#bossFightTracks do
		Spring.Echo(bossFightTracks[i])
	end

	if #peaceTracks > 1 then
		peaceTracksPlayCounter = math.random(#peaceTracks)
	else
		peaceTracksPlayCounter = 1
	end

	if #warhighTracks > 1 then
		warhighTracksPlayCounter = math.random(#warhighTracks)
	else
		warhighTracksPlayCounter = 1
	end

	if #warlowTracks > 1 then
		warlowTracksPlayCounter = math.random(#warlowTracks)
	else
		warlowTracksPlayCounter = 1
	end

	if #bossFightTracks > 1 then
		bossFightTracksPlayCounter = math.random(#bossFightTracks)
	else
		bossFightTracksPlayCounter = 1
	end

	if #gameoverTracks > 1 then
		gameoverTracksPlayCounter = math.random(#gameoverTracks)
	else
		gameoverTracksPlayCounter = 1
	end
end

local currentTrackList = peaceTracks
local currentTrackListString = "intro"

local defaultMusicVolume = 50
local warMeter = 0
local warMeterResetTimer = 0
local gameOver = false
local playedGameOverTrack = false
local fadeLevel = 100

local playedTime, totalTime = Spring.GetSoundStreamTime()
local prevPlayedTime = playedTime

local silenceTimer = math.random(minSilenceTime, maxSilenceTime)

local maxMusicVolume = Spring.GetConfigInt("snd_volmusic", 20)	-- user value, cause actual volume will change during fadein/outc
local volume = Spring.GetConfigInt("snd_volmaster", 100)

local math_isInRect = math.isInRect

local fadeDirection

local function getFastFadeSpeed()
	return 1.5 * 0.33
end
local function getSlowFadeSpeed()
	return math.max(Spring.GetGameSpeed(), 0.01)
end
local getFadeSpeed = getSlowFadeSpeed

local function fadeChange()
	return (0.33 / getFadeSpeed()) * fadeDirection
end

local function getMusicVolume()
	return Spring.GetConfigInt("snd_volmusic", defaultMusicVolume) * 0.01
end

local function setMusicVolume(fadeLevel)
	Spring.SetSoundStreamVolume(getMusicVolume() * math.max(math.min(fadeLevel, 100), 0) * 0.01)
end

local function updateFade()
	if fadeDirection then
		if Spring.GetConfigInt("UseSoundtrackFades", 1) == 1 then
			fadeLevel = fadeLevel + fadeChange()
		else
			if fadeDirection < 0 then
				fadeLevel = 0
			elseif fadeDirection > 0 then
				fadeLevel = 100
			end
		end
		setMusicVolume(fadeLevel)
		if fadeDirection < 0 and fadeLevel <= 0 then
			fadeDirection = nil
			if fadeOutSkipTrack then
				PlayNewTrack()
			else
				Spring.StopSoundStream()
			end
		elseif fadeDirection > 0 and fadeLevel >= 100 then
			fadeDirection = nil
		end
	end
end

function widget:Initialize()
	if Spring.GetGameFrame() == 0 and Spring.GetConfigInt('music_loadscreen', 1) == 1 then
		currentTrack = Spring.GetConfigString('music_loadscreen_track', '')
	end
	ReloadMusicPlaylists()
	silenceTimer = math.random(minSilenceTime,maxSilenceTime)
	-- widget:ViewResize()
	-- Spring.StopSoundStream() -- only for testing purposes
end

local playingInit = false
function widget:Update(dt)
	local frame = Spring.GetGameFrame()
	local _,_,paused = Spring.GetGameSpeed()

	playedTime, totalTime = Spring.GetSoundStreamTime()
	if not playingInit then
		playingInit = true
		if playedTime ~= prevPlayedTime then
			if not playing then
				playing = true
				--createList()
			end
		else
			if playing then
				playing = false
				--createList()
			end
		end
	end
	prevPlayedTime = playedTime

	if playing and (paused or frame < 1) then
		if totalTime == 0 then
			PlayNewTrack(true)
		end
	end
	if paused then
		updateFade()
	end

	if showGUI then
		local mx, my, mlb = Spring.GetMouseState()
		if math_isInRect(mx, my, left, bottom, right, top) then
			mouseover = true
		end
		local curVolume = Spring.GetConfigInt("snd_volmaster", 100)
		if volume ~= curVolume then
			volume = curVolume
		end
	end
end

function PlayNewTrack(paused)
	interruptionEnabled = Spring.GetConfigInt('UseSoundtrackInterruption', 1) == 1
	silenceTimerEnabled = Spring.GetConfigInt('UseSoundtrackSilenceTimer', 1) == 1
	if (not paused) and Spring.GetGameFrame() > 1 then
		deviceLostSafetyCheck = deviceLostSafetyCheck + 1
	end
	Spring.StopSoundStream()
	fadeOutSkipTrack = false
	silenceTimer = math.random(minSilenceTime,maxSilenceTime)

	if (not gameOver) and Spring.GetGameFrame() > 1 then
		fadeLevel = 0
		fadeDirection = 1
	else
		-- Fade in only when game is in progress
		fadeDirection = nil
	end
	currentTrack = nil
	currentTrackList = nil

	if gameOver then
		currentTrackList = gameoverTracks
		currentTrackListString = "gameOver"
		playedGameOverTrack = true
	elseif bossHasSpawned then
		currentTrackList = bossFightTracks
		currentTrackListString = "bossFight"
	elseif warMeter >= warHighLevel then
		currentTrackList = warhighTracks
		currentTrackListString = "warHigh"
	elseif warMeter >= warLowLevel then
		currentTrackList = warlowTracks
		currentTrackListString = "warLow"
	else
		currentTrackList = peaceTracks
		currentTrackListString = "peace"
	end

	if not currentTrackList then
		return
	end

	if #currentTrackList > 0 then
		if currentTrackListString == "peace" then
			currentTrack = currentTrackList[peaceTracksPlayCounter]
			if peaceTracksPlayCounter <= #peaceTracks then
				peaceTracksPlayCounter = peaceTracksPlayCounter + 1
			else
				peaceTracksPlayCounter = 1
			end
		end
		if currentTrackListString == "warHigh" then
			currentTrack = currentTrackList[warhighTracksPlayCounter]
			if warhighTracksPlayCounter <= #warhighTracks then
				warhighTracksPlayCounter = warhighTracksPlayCounter + 1
			else
				warhighTracksPlayCounter = 1
			end
		end
		if currentTrackListString == "warLow" then
			currentTrack = currentTrackList[warlowTracksPlayCounter]
			if warlowTracksPlayCounter <= #warlowTracks then
				warlowTracksPlayCounter = warlowTracksPlayCounter + 1
			else
				warlowTracksPlayCounter = 1
			end
		end
		if currentTrackListString == "bossFight" then
			currentTrack = currentTrackList[bossFightTracksPlayCounter]
			if bossFightTracksPlayCounter <= #bossFightTracks then
				bossFightTracksPlayCounter = bossFightTracksPlayCounter + 1
			else
				bossFightTracksPlayCounter = 1
			end
		end
		if currentTrackListString == "gameOver" then
			currentTrack = currentTrackList[gameoverTracksPlayCounter]
		end
	elseif #currentTrackList == 0 then
		return
	end

	if currentTrack then
		Spring.PlaySoundStream(currentTrack, 1)
		playing = true
		interruptionTime = math.random(interruptionMinimumTime, interruptionMaximumTime)
		if fadeDirection then
			setMusicVolume(fadeLevel)
		else
			setMusicVolume(100)
		end
	end

	--createList()
end

function widget:UnitDamaged(unitID, unitDefID, _, damage)
	if damage > 1 then
		warMeterResetTimer = 0
		local curHealth, maxHealth = Spring.GetUnitHealth(unitID)
		if damage > maxHealth then
			warMeter = math.ceil(warMeter + maxHealth)
		else
			warMeter = math.ceil(warMeter + damage)
		end
		if totalTime == 0 and silenceTimer >= 0 and damage and damage > 0 then
			silenceTimer = silenceTimer - damage*0.001
			--Spring.Echo("silenceTimer: ", silenceTimer)
		end
	end
end

function widget:GameProgress(n)
	-- happens every 150 frames
	serverFrame = n
end

function widget:GameFrame(n)
	gameFrame = n
	if n%1800 == 0 then
		deviceLostSafetyCheck = 0
	end
	updateFade()

	if gameOver and not playedGameOverTrack then
		getFadeSpeed = getFastFadeSpeed
		fadeOutSkipTrack = true
		fadeDirection = -5
	end

	if n%30 == 15 then
		if Spring.GetGameRulesParam("BossFightStarted") and Spring.GetGameRulesParam("BossFightStarted") == 1 then
			bossHasSpawned = true
		else
			bossHasSpawned = false
		end
		if deviceLostSafetyCheck >= 3 then
			return
		end

		if not appliedSpectatorThresholds and Spring.GetSpectatingState() == true then
			applySpectatorThresholds()
		end

		local musicVolume = getMusicVolume()

		if warMeter > 0 then
			warMeter = math.floor(warMeter - (warMeter * 0.04))
			if warMeter > warHighLevel*3 then
				warMeter = warHighLevel*3
			end
			warMeterResetTimer = warMeterResetTimer + 1
			if warMeterResetTimer > warMeterResetTime then
				warMeter = 0
			end
		end

		if not gameOver then
			if playedTime > 0 and totalTime > 0 then -- music is playing
				if not fadeDirection then
					Spring.SetSoundStreamVolume(musicVolume)
					if (bossHasSpawned and currentTrackListString ~= "bossFight") or ((not bossHasSpawned) and currentTrackListString == "bossFight") then
						fadeDirection = -2
						fadeOutSkipTrack = true
					elseif (interruptionEnabled and (playedTime >= interruptionTime) and gameFrame >= serverFrame-300)
					  and ((currentTrackListString == "intro" and n > 90)
						or (currentTrackListString == "peace" and warMeter > warLowLevel * 2) -- Peace in battle times, let's play some WarLow music at double of WarLow threshold
						or (currentTrackListString == "warLow" and warMeter > warHighLevel * 2) -- WarLow music is playing but battle intensity is very high, Let's switch to WarHigh at double of WarHigh threshold
						or (currentTrackListString == "warHigh" and warMeter <= warHighLevel * 0.5) -- WarHigh music is playing, but it has been quite peaceful recently. Let's switch to WarLow music at 50% of WarHigh threshold
						or (currentTrackListString == "warLow" and warMeter <= warLowLevel * 0.5 )) then -- WarLow music is playing, but it has been quite peaceful recently. Let's switch to peace music at 50% of WarLow threshold
							fadeDirection = -2
							fadeOutSkipTrack = true
					elseif (playedTime >= totalTime - 12 and Spring.GetConfigInt("UseSoundtrackFades", 1) == 1) then
						fadeDirection = -1
					end
				end
			elseif totalTime == 0 then -- there's no music
				if silenceTimerEnabled and not bossHasSpawned then
					--Spring.Echo("silenceTimer: ", silenceTimer)
					if silenceTimer > 0 then
						silenceTimer = silenceTimer - 1
					elseif silenceTimer <= 0 then
						PlayNewTrack()
					end
				else
					PlayNewTrack()
				end
			end
		end
	end
end

function widget:GameOver(winningAllyTeams)
	gameOver = true
end

function widget:UnitCreated(_, _, _, builderID)
	if builderID and warMeter < warLowLevel and silenceTimer > 0 and totalTime == 0 then
		--Spring.Echo("silenceTimer: ", silenceTimer)
		silenceTimer = silenceTimer - 2
	end
end

function widget:UnitFinished()
	if warMeter < warLowLevel and silenceTimer > 0 and totalTime == 0 then
		--Spring.Echo("silenceTimer: ", silenceTimer)
		silenceTimer = silenceTimer - 5
	end
end
