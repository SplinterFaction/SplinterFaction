--------------------------------------------------------------------------------
-- Sound tab
--------------------------------------------------------------------------------

return {
	id = "snd", name = "Sound", order = 30,
	options = {
		{ type = "separator", name = "Volume" },
		{ id = "volmaster", name = "Master", type = "slider", min = 0, max = 200, step = 2, config = "snd_volmaster", format = "%d%%" },
		{ id = "volbattle", name = "Battle", type = "slider", min = 0, max = 100, step = 2, config = "snd_volbattle", format = "%d%%" },
		{ id = "volgeneral", name = "General", type = "slider", min = 0, max = 100, step = 2, config = "snd_volgeneral", format = "%d%%" },
		{ id = "volui", name = "Interface", type = "slider", min = 0, max = 100, step = 2, config = "snd_volui", format = "%d%%" },
		{ id = "volunitreply", name = "Unit replies", type = "slider", min = 0, max = 100, step = 2, config = "snd_volunitreply", format = "%d%%" },
		{ id = "volmusic", name = "Music", type = "slider", min = 0, max = 100, step = 2, config = "snd_volmusic", format = "%d%%",
		  onSet = function(v) if WG.music and WG.music.SetMusicVolume then WG.music.SetMusicVolume(v) end end },
		{ id = "airabsorption", name = "Air absorption", type = "slider", min = 0, max = 0.5, step = 0.01, config = "snd_airAbsorption",
		  desc = "How much distant sounds are muffled." },

		{ type = "separator", name = "Music" },
		{ id = "musicplayer", name = "Music player", type = "bool", widget = "Music Player", requires = "Music Player",
		  children = {
			{ id = "musicinterrupt", name = "Interrupt on action", type = "bool", config = "UseSoundtrackInterruption",
			  desc = "Lets the current track be cut short when combat breaks out." },
			{ id = "musicsilence", name = "Silence between tracks", type = "bool", config = "UseSoundtrackSilenceTimer" },
			{ id = "musicfades", name = "Fade between tracks", type = "bool", config = "UseSoundtrackFades" },
			{ id = "musicloadscreen", name = "Play on loading screen", type = "bool", config = "music_loadscreen", restart = true },
		  } },
		{ id = "ambientsounds", name = "Ambient map sounds", type = "bool", widget = "Ambient Background Sound Player", requires = "Ambient Background Sound Player" },

		{ type = "separator", name = "Alerts" },
		{ id = "unitalerts", name = "Unit alert sounds", type = "bool", widget = "Unit Alert sounds", requires = "Unit Alert sounds",
		  desc = "Audio cues for units under attack, completed builds and similar events." },
		
	},
}
