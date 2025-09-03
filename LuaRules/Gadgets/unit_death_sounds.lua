function gadget:GetInfo()
	return {
		name    = "Randomised Death Sounds (refactor)",
		desc    = "Assign and play classes of unit death sounds",
		author  = "FLOZi (C. Lawrence), refactor by Scary le Poo",
		date    = "2025-09-02",
		license = "Public Domain",
		layer   = 1,
		enabled = true
	}
end

local random           = math.random
local GetUnitPosition  = Spring.GetUnitPosition
local PlaySoundFile    = Spring.PlaySoundFile

local SOUNDS_PATH = "sounds/deathsounds/"

-- Built at init:
local classCues   = {}   -- class -> { "cue1", "cue2", ... } (bare names, no extension)
local classSizes  = {}   -- class -> n
local unitClass   = {}   -- unitDefID -> class

-- Shuffle bag state:
local shuffleBags = {}   -- class -> { idx1, idx2, ... } (a stack; we pop from the end)
local lastIdx     = {}   -- class -> last index used (for cross-bag no-repeat)

if gadgetHandler:IsSyncedCode() then

	local function buildCueName(path)
		local fname = path:gsub("^.*/", "")
		fname = fname:gsub("%.[Ww][Aa][Vv]$", "")
		fname = fname:gsub("%.[Oo][Gg][Gg]$", "")
		return fname
	end

	local function refillBag(class)
		local n = classSizes[class]
		if not n or n == 0 then
			shuffleBags[class] = {}
			return
		end
		local bag = {}
		for i = 1, n do bag[i] = i end
		-- Fisher–Yates
		for i = n, 2, -1 do
			local j = random(i)
			bag[i], bag[j] = bag[j], bag[i]
		end
		-- Ensure first draw after refill won't repeat the last draw from previous bag
		-- We pop from the END, so "first draw" is bag[#bag]
		if n > 1 and lastIdx[class] and bag[#bag] == lastIdx[class] then
			bag[#bag], bag[1] = bag[1], bag[#bag]
		end
		shuffleBags[class] = bag
	end

	function gadget:Initialize()
		math.random() math.random() math.random()  -- throw away a few values

		-- Discover classes and cues
		local subDirs = VFS.SubDirs(SOUNDS_PATH)
		for i = 1, #subDirs do
			local subDir = subDirs[i]
			if not subDir:match("/%.svn") then
				local class = subDir:gsub(SOUNDS_PATH, ""):gsub("/", "")
				local files = VFS.DirList(subDir, nil, nil, true) or {}
				local cues = {}
				for j = 1, #files do
					cues[#cues+1] = buildCueName(files[j])
				end
				classCues[class]  = cues
				classSizes[class] = #cues
			end
		end

		-- Map unitDef -> class (folder), defaulting to "generic" if missing/empty
		for unitDefID, ud in pairs(UnitDefs) do
			local class = (ud.customParams and ud.customParams.death_sounds) or "generic"
			if not classCues[class] or classSizes[class] == 0 then
				class = "generic"
			end
			unitClass[unitDefID] = class
		end

		-- Make initial bags
		for class, _ in pairs(classCues) do
			refillBag(class)
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID)
		if not attackerID then return end

		local class = unitClass[unitDefID]
		if not class then return end
		local n = classSizes[class]
		if not n or n == 0 then return end

		local bag = shuffleBags[class]
		if not bag or #bag == 0 then
			refillBag(class)
			bag = shuffleBags[class]
			if #bag == 0 then return end -- still empty? bail safely
		end

		-- Draw: pop last index (O(1))
		local idx = bag[#bag]
		bag[#bag] = nil
		lastIdx[class] = idx

		local cue = classCues[class][idx]
		if not cue then return end

		local x, y, z = GetUnitPosition(unitID)
		PlaySoundFile(cue, 1, x, y, z)
	end
end