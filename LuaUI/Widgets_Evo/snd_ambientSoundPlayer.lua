--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--	file: snd_ambientSoundPlayer.lua
--	brief:	Plays a looping background sound
--	author:	Forboding Angel
--
--	Copyright (C) 2019.
--	Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
math.randomseed( os.time() - os.clock() * 1000 )
math.random() math.random() math.random()

function widget:GetInfo()
	return {
		name	= "Ambient Background Sound Player",
		desc	= "Plays a looping background sound",
		author	= "Forboding Angel",
		date	= "May 2019",
		license	= "GNU GPL, v2 or later",
		layer	= 9999999999,
		enabled	= true	--	loaded by default?
	}
end

function widget:Initialize()
	-- myTeamID = Spring.GetMyTeamID()
	-- myFaction = Spring.GetTeamRulesParam(myTeamID, "faction", playerFaction)
	--if myFaction == nil then
	--	Spring.Echo("[Ambient Background Sound Player] If you're seeing this message that means that the code which sets the player's faction is absolutely fucked somewhere. On the next line I will echo the myFaction variable (It will be nil). If it says anything other than the factions listed in game_spawn.lua (it will), at least it will provide a clue. Additionally I will manually set the player faction to Federation of Kala so that it doesn't crash and burn. Happy bug hunting!")
	--	Spring.Echo(myFaction)
	--	myFaction = "Federation of Kala"
	--else
	--	Spring.Echo("[Ambient Background Sound Player] Player faction is " .. myFaction)
	--end

	randomSound = math.random(1,6)
end

function widget:GameFrame(n)

	if randomSound == 1 then
		if n == 1 then
			Spring.PlaySoundFile("sounds/ambient/magicsound/drone_dark_01.wav", 0.20, 'ui')
		elseif (n % 30) == 4 then
			Spring.PlaySoundFile("sounds/ambient/magicsound/drone_dark_01.wav", 0.20, 'ui')
		end
	elseif randomSound == 2 then
		if n == 1 then
			Spring.PlaySoundFile("sounds/ambient/magicsound/drone_drifting_01.wav", 0.20, 'ui')
		elseif (n % 30) == 4 then
			Spring.PlaySoundFile("sounds/ambient/magicsound/drone_drifting_01.wav", 0.20, 'ui')
		end
	elseif randomSound == 3 then
		if n == 1 then
			Spring.PlaySoundFile("sounds/ambient/magicsound/drone_moonlight_01.wav", 0.20, 'ui')
		elseif (n % 30) == 4 then
			Spring.PlaySoundFile("sounds/ambient/magicsound/drone_moonlight_01.wav", 0.20, 'ui')
		end
	elseif randomSound == 4 then
		if n == 1 then
			Spring.PlaySoundFile("sounds/ambient/magicsound/drone_red_planet_01.wav", 0.20, 'ui')
		elseif (n % 30) == 4 then
			Spring.PlaySoundFile("sounds/ambient/magicsound/drone_red_planet_01.wav", 0.20, 'ui')
		end
	elseif randomSound == 5 then
		if n == 1 then
			Spring.PlaySoundFile("sounds/ambient/magicsound/drone_serenity_01.wav", 0.20, 'ui')
		elseif (n % 30) == 4 then
			Spring.PlaySoundFile("sounds/ambient/magicsound/drone_serenity_01.wav", 0.20, 'ui')
		end
	elseif randomSound == 6 then
		if n == 1 then
			Spring.PlaySoundFile("sounds/ambient/magicsound/drone_space_01.wav", 0.20, 'ui')
		elseif (n % 30) == 4 then
			Spring.PlaySoundFile("sounds/ambient/magicsound/drone_space_01.wav", 0.20, 'ui')
		end
	end

end