--- Valid entries used by engine: IncomingChat, MultiSelect, MapPoint
--- other than that, you can give it any name and access it like before with filenames
local Sounds = {
	SoundItems = {

		--IncomingChat = {
		--    file = "sounds/ui/chat.wav",
		--    gain = 0.5,
		--    -- in3d = "false",
		--},
		--MultiSelect = {
		--	file = "sounds/ui/multiselect.wav",
		--	-- in3d = "false",
		--},
		MapPoint = {
			file = "sounds/ui/mappoint.wav",    -- file now equal as blank.wav, is being called by chat ui widget now (so users can adjust its volume)
			gain = 0.1,
			pitchmod = 0.02,
			gainmod  = 0.2 * 0.3,
			dopplerscale = 0,
			maxconcurrent = 1,
			rolloff = 0,
			priority = 1,
			in3d = true,
		},
		--FailedCommand = {
		--	file = "sounds/ui/cantdo.wav",
		--},
		
		--ExampleSound = {
			--- some things you can do with this file

			--- can be either ogg or wav
		--	file = "somedir/subdir/soundfile.ogg",

			--- loudness, > 1 is louder, < 1  is more quiet, you will most likely not set it to 0
		--	gain = 1,

			--- > 1 -> high pitched, < 1 lowered
		--	pitch = 1,

			--- If > 0.0 then this adds a random amount to gain each time the sound is played.
			--- Clamped between 0.0 and 1.0. The result is in the range [(gain * (1 + gainMod)), (gain * (1 - gainMod))].
		--	gainmod = 0.0,

			--- If > 0.0 then this adds a random amount to pitch each time the sound is played.
			--- Clamped between 0.0 and 1.0. The result is in the range [(pitch * (1 + pitchMod)), (pitch * (1 - pitchMod))].
		--	pitchmod = 0.0,

			--- how unit / camera speed affects the sound, to exagerate it, use values > 1
			--- dopplerscale = 0 completely disables the effect
		--	dopplerscale = 1,

			--- when lots of sounds are played, sounds with lwoer priority are more likely to get cut off
			--- priority > 0 will never be cut of (priorities can be negative)
		--	priority = 0,

			--- this sound will not be played more than 16 times at a time
		--	maxconcurrent = 16,

			--- cutoff distance
		--	maxdist = 20000,

			--- how fast it becomes more quiet in the distance (0 means aleays the same loudness regardless of dist)
		--	rolloff = 1,

			--- non-3d sounds do always came out of the front-speakers (or the center one)
			--- 3d sounds are, well, in 3d
		--	in3d = true,

			--- you can loop it for X miliseconds
		--	looptime = 0,
		--},

		--default = {
			-- new since 89.0
			-- you can overwrite the fallback profile here (used when no corresponding SoundItem is defined for a sound)
		--	gainmod = 0.35,
		--	pitchmod = 0.05,
		--	pitch = 0.7,
		--	in3d = true,
		--},
	},
}

--local files = VFS.DirList("sounds/deathsounds/generic/")
--local t = Sounds.SoundItems
--for i=1,#files do
--	local fileName = files[i]
--	t[fileName] = {
--		file     = fileName;
--		-- gain = 1 * 0.3,
--		pitchmod = 0.02,
--		-- gainmod  = 0.2 * 0.3,
--		dopplerscale = 0,
--		maxconcurrent = 64,
--		rolloff = 0,
--		priority = 1,
--		in3d = true,
--	}
--end

-- local files = VFS.DirList("sounds/explosions/")
-- local t = Sounds.SoundItems
-- for i=1,#files do
   -- local fileName = files[i]
   -- t[fileName] = {
      -- file     = fileName;
      -- pitchmod = 0.3;
      ----gainmod  = 0.2;
      -- maxconcurrent = 16;
	  -- rolloff = 2,
	  -- dopplerscale = 2,
	  -- in3d = true,
   -- }
-- end

-- local files = VFS.DirList("sounds/deathsounds/nuke/")
-- local t = Sounds.SoundItems
-- for i=1,#files do
   -- local fileName = files[i]
   -- t[fileName] = {
      -- file     = fileName;
      -- pitchmod = 0.3;
      ----gainmod  = 0.2;
      -- maxconcurrent = 16;
	  -- rolloff = 2,
	  -- dopplerscale = 2,
	  -- in3d = true,
   -- }
-- end

 --local files = VFS.DirList("sounds/weapons/")
 --local t = Sounds.SoundItems
 --for i=1,#files do
 --   local fileName = files[i]
 --   t[fileName] = {
 --      file     = fileName;
	--	-- gain = 1 * 0.3,
	--	pitchmod = 0.02,
	--	-- gainmod  = 0.2 * 0.3,
	--	dopplerscale = 0,
	--	maxconcurrent = 32,
	--	rolloff = 0,
	--	priority = 1,
	--	in3d = true,
 --   }
 --end

--local files = VFS.DirList("sounds/selfdcountdown/")
--local t = Sounds.SoundItems
--for i=1,#files do
--   local fileName = files[i]
--   t[fileName] = {
--      file     = fileName;
--      pitchmod = 0;
--      gainmod  = 0;
--      maxconcurrent = 1;
--   }
--end



local soundData = {

	['ui'] = {
		gain = 0.15,
		pitchmod = 0,
		gainmod = 0,
		dopplerscale = 0,
		maxconcurrent = 8,
		rolloff = 0,
	},

	['commands'] = {
		gain = 0.3,
		pitchmod = 0.02,
		gainmod = 0.06,  -- 0.2 * 0.3 = 0.06
		dopplerscale = 0,
		maxconcurrent = 32,
		rolloff = 0,
		priority = 1,
	},

	['unitselections'] = {
		gain = 0.1,
		pitchmod = 0.02,
		gainmod = 0.06,  -- 0.2 * 0.3 = 0.06
		dopplerscale = 0,
		maxconcurrent = 2,
		rolloff = 0,
		priority = 1,
	},

	['weapons'] = {
		gain = 0.525,  -- 1.75 * 0.3 = 0.525
		pitchmod = 0.17,
		gainmod = 0.06,  -- 0.2 * 0.3 = 0.06
		maxconcurrent = 16,
		dopplerscale = 1.0,
		rolloff = 0.5,
	},

	['weaponsloud'] = {
		gain = 1.5,  -- 5 * 0.3 = 1.5
		pitchmod = 0.17,
		gainmod = 0.06,  -- 0.2 * 0.3 = 0.06
		maxconcurrent = 16,
		dopplerscale = 1.0,
		rolloff = 0.5,
	},

	['impacts'] = {
		gain = 0.9,  -- 3 * 0.3 = 0.9
		pitchmod = 0.17,
		gainmod = 0.06,  -- 0.2 * 0.3 = 0.06
		maxconcurrent = 7,
		dopplerscale = 1.0,
		rolloff = 0.5,
	},

	['impacts/generic'] = {
		gain = 0.9,  -- 3 * 0.3 = 0.9
		pitchmod = 0.17,
		gainmod = 0.06,  -- 0.2 * 0.3 = 0.06
		maxconcurrent = 7,
		dopplerscale = 1.0,
		rolloff = 0.5,
	},

	['deathsounds/generic'] = {
		gain = 1.2,  -- 4 * 0.3 = 1.2
		pitchmod = 0.17,
		gainmod = 0.06,  -- 0.2 * 0.3 = 0.06
		maxconcurrent = 7,
		dopplerscale = 1.0,
		rolloff = 0.5,
	},

	['deathsounds/commander'] = {
		gain = 20,  -- 20 * 0.3 = 6
		pitchmod = 0.17,
		gainmod = 0.06,  -- 0.2 * 0.3 = 0.06
		maxconcurrent = 7,
		dopplerscale = 1.0,
		rolloff = 0.5,
	},

	['misc'] = {
		gain = 0.36,  -- 1.2 * 0.3 = 0.36
		pitchmod = 0.17,
		gainmod = 0.06,  -- 0.2 * 0.3 = 0.06
		maxconcurrent = 7,
		dopplerscale = 1.0,
		rolloff = 0.5,
		in3d = true,
	},

	['selfdcountdown'] = {
		gain = 0.36,  -- 1.2 * 0.3 = 0.36
		pitchmod = 0.02,
		gainmod = 0.06,  -- 0.2 * 0.3 = 0.06
		dopplerscale = 0,
		maxconcurrent = 1,
		rolloff = 0,
		priority = 1,
	},
}

local function loadSoundFiles(directory, soundAttributes)
	local soundFiles = VFS.DirList(directory)

	for _, fileName in ipairs(soundFiles) do
		local soundName = string.sub(fileName, string.len(directory) + 1, string.find(fileName, ".wav") -1)
		Sounds.SoundItems[soundName] = {}
		Sounds.SoundItems[soundName].file = fileName

		local value
		for attribute, attributeValue in pairs(soundAttributes) do
			if type(attributeValue) ~= "table" then
				value = attributeValue
			else
				value = attributeValue.default

				for soundMatchPattern, customValue in pairs(attributeValue.custom) do
					if soundName:match(soundMatchPattern) then
						value = customValue
					end
				end
			end

			Sounds.SoundItems[soundName][attribute] = value
		end
	end
end

for directory, attributes in pairs(soundData) do
	loadSoundFiles('sounds/' .. directory .. '/', attributes)
end

return Sounds