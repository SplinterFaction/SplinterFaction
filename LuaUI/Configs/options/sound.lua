--------------------------------------------------------------------------------
-- Sound tab
--------------------------------------------------------------------------------

-- The artists are the folders under Music/ (the player reads the same ones)
local artistNames, artistFolders = { "All artists" }, { "" }
do
	local dirs = VFS.SubDirs("music/", "*") or {}
	table.sort(dirs)
	for _, dir in ipairs(dirs) do
		local folder = dir:gsub("[/\\]+$", ""):match("[^/\\]+$")
		if folder and #(VFS.DirList(dir, "{*.ogg,*.mp3}") or {}) > 0 then
			local name = folder:gsub("^%l", string.upper)
			local custom = "music/" .. folder .. "/artist.txt"
			if VFS.FileExists(custom) then
				local n = (VFS.LoadFile(custom) or ""):match("^%s*(.-)%s*$")
				if n ~= "" then name = n end
			end
			artistNames[#artistNames + 1] = name
			artistFolders[#artistFolders + 1] = folder
		end
	end
end

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
		{ id = "musicplayer", name = "Music player", type = "bool", widget = "Bastion Music", requires = "Bastion Music",
		  children = {
			{ id = "musicartist", name = "Artist", type = "select", options = artistNames, values = artistFolders,
			  -- get returns the stored value (the folder); the options widget maps
			  -- it to the row's index through values, so returning an index here
			  -- would never match and the dropdown would always show the first entry
			  get = function()
				local folder = Spring.GetConfigString("music_artist", "elevenlabs")
				for i = 1, #artistFolders do if artistFolders[i] == folder then return folder end end
				return ""
			  end,
			  set = function(idx)
				local folder = artistFolders[idx] or ""
				if WG.music and WG.music.SetArtist then WG.music.SetArtist(folder) else Spring.SetConfigString("music_artist", folder) end
			  end,
			  desc = "Which Music folder to play from. The loading screen uses the same choice." },
			{ id = "musicprev", name = "Previous track", type = "action", label = "Previous",
			  set = function() if WG.music then WG.music.Previous() end end },
			{ id = "musicpause", name = "Play or pause", type = "action", label = "Play / Pause",
			  set = function() if WG.music then WG.music.TogglePause() end end },
			{ id = "musicnext", name = "Next track", type = "action", label = "Next",
			  set = function() if WG.music then WG.music.Next() end end },
			{ id = "musicsilence", name = "Silence between tracks", type = "bool", config = "UseSoundtrackSilenceTimer",
			  desc = "Now and then a track is followed by a stretch of quiet instead of the next one." },
			{ id = "musicsilencemax", name = "Longest silence", type = "slider", min = 10, max = 120, step = 5, config = "music_silence_max", default = 60, format = "%ds",
			  desc = "A silence lasts a random time up to this." },
			{ id = "musicfades", name = "Fade between tracks", type = "bool", config = "UseSoundtrackFades" },
			{ id = "musicloadscreen", name = "Play on loading screen", type = "bool", config = "music_loadscreen", restart = true },
		  } },
		{ id = "ambientsounds", name = "Ambient map sounds", type = "bool", widget = "Ambient Background Sound Player", requires = "Ambient Background Sound Player" },

		{ type = "separator", name = "Alerts" },
		{ id = "unitalerts", name = "Unit alert sounds", type = "bool", widget = "Unit Alert sounds", requires = "Unit Alert sounds",
		  desc = "Audio cues for units under attack, completed builds and similar events." },
		
	},
}
