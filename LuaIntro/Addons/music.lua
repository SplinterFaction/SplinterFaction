
if addon.InGetInfo then
	return {
		name    = "Music",
		desc    = "plays music",
		author  = "jK, Damgam",
		date    = "2012,2013, 2023",
		license = "GPL2",
		layer   = 0,
		enabled = true,
	}
end

function addon.Initialize()
	if Spring.GetConfigInt('music_loadscreen', 1) == 1 then
		local originalSoundtrackEnabled = Spring.GetConfigInt('UseSoundtrackNew', 1)
		local customSoundtrackEnabled	= Spring.GetConfigInt('UseSoundtrackCustom', 1)
		local allowedExtensions = "{*.ogg,*.mp3}"


		local musicPlaylist = {}
		if originalSoundtrackEnabled == 1 then
			local musicDirOriginal 		= 'music/original'
			table.append(musicPlaylist, VFS.DirList(musicDirOriginal..'/loading', allowedExtensions))
		end

		-- Custom Soundtrack List
		if customSoundtrackEnabled == 1 then
			local musicDirCustom 		= 'music/custom'
			table.append(musicPlaylist, VFS.DirList(musicDirCustom..'/loading', allowedExtensions))
		end

		if #musicPlaylist == 0 or math.random(0,3) == 0 then
			if originalSoundtrackEnabled == 1 then
				local musicDirOriginal 		= 'music/original'
				table.append(musicPlaylist, VFS.DirList(musicDirOriginal..'/peace', allowedExtensions))
			end
		end

		local musicvolume = Spring.GetConfigInt("snd_volmusic", 20) * 0.01 or 0.2
		if #musicPlaylist > 1 then
			local pickedTrack = math.ceil(#musicPlaylist*math.random())
			Spring.PlaySoundStream(musicPlaylist[pickedTrack], 1)
			Spring.SetSoundStreamVolume(musicvolume)
			Spring.SetConfigString('music_loadscreen_track', musicPlaylist[pickedTrack])
		elseif #musicPlaylist == 1 then
			Spring.PlaySoundStream(musicPlaylist[1], 1)
			Spring.SetSoundStreamVolume(musicvolume)
			Spring.SetConfigString('music_loadscreen_track', musicPlaylist[1])
		end
	end
end
