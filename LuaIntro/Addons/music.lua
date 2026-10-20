if addon.InGetInfo then
	return {
		name    = "Music",
		desc    = "Starts a soundtrack track while the game loads; the in-game player carries on with it",
		author  = "jK, Damgam; SplinterFaction Team",
		date    = "2012, 2013, 2023, 2026",
		license = "GPL2",
		layer   = 0,
		enabled = true,
	}
end

-- Same library as gui_bastion_music.lua: Music/<artist>/*.ogg|mp3, with the
-- player's artist choice (music_artist: a folder name, or "" for all).
-- The track chosen is left in music_loadscreen_track, so the player picks it
-- up instead of starting another.
function addon.Initialize()
	if Spring.GetConfigInt("music_loadscreen", 1) ~= 1 then
		return
	end
	local extensions = "{*.ogg,*.mp3}"
	local artist = Spring.GetConfigString("music_artist", "")
	local tracks = {}
	local function add(dir)
		for _, path in ipairs(VFS.DirList(dir, extensions) or {}) do
			tracks[#tracks + 1] = path
		end
	end
	if artist ~= "" then
		add("music/" .. artist)
	end
	if #tracks == 0 then
		for _, dir in ipairs(VFS.SubDirs("music/", "*") or {}) do
			add(dir)
		end
		add("music")
	end
	if #tracks == 0 then
		return
	end
	math.randomseed(os.clock() * 1000)
	local pick = tracks[math.random(#tracks)]
	local volume = math.max(0, math.min(100, Spring.GetConfigInt("snd_volmusic", 20))) * 0.01
	Spring.PlaySoundStream(pick, volume)
	Spring.SetSoundStreamVolume(volume)
	Spring.SetConfigString("music_loadscreen_track", pick)
end
