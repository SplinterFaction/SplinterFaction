
if addon.InGetInfo then
	return {
		name    = "Music",
		desc    = "plays music",
		author  = "jK",
		date    = "2012,2013",
		license = "GPL2",
		layer   = 0,
		depend  = {"LoadProgress"},
		enabled = true,
	}
end

------------------------------------------
math.randomseed( os.time() - os.clock() * 1000 )
math.random() math.random() math.random()
local music_volume_set = Spring.GetConfigInt("snd_volmusic", 20) * 0.01 or 0.2
Spring.SetSoundStreamVolume(music_volume_set)

musicfiles = VFS.DirList("LuaUI/Widgets_Evo/Music/loading", "*.ogg")
tracks = musicfiles
newTrack = tracks[math.random(1, #tracks)]

if newTrack == nil then
	Spring.Echo("[LuaIntro Music Player] newTrack is returning nil for some reason")
	Spring.Echo("[LuaIntro Music Player] number of tracks is " .. #tracks)
	newTrack = "LuaUI/Widgets_Evo/Music/loading/Cyberpunk - Crash.ogg"
	Spring.Echo("[LuaIntro Music Player] Now Playing " .. newTrack)
	Spring.PlaySoundStream(newTrack)
	Spring.SetSoundStreamVolume(music_volume_set)
else
	Spring.Echo("[LuaIntro Music Player] number of tracks is " .. #tracks)
	Spring.Echo("[LuaIntro Music Player] Now Playing " .. newTrack)
	Spring.PlaySoundStream(newTrack)
	Spring.SetSoundStreamVolume(music_volume_set)
end

--function addon.DrawLoadScreen()
	--Spring.SetSoundStreamVolume(100)
--end


function addon.Shutdown()
	--Spring.StopSoundStream()
	--Spring.SetSoundStreamVolume(0.5)
end
