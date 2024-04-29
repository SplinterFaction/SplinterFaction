function gadget:GetInfo()
	return {
		name = "Randomised Death Sounds",
		desc = "Assign and play classes of unit death sounds",
		author = "FLOZi (C. Lawrence), rewrite of DeathSounds.lua by Argh",
		date = "19/05/2011",
		license = "Public Domain",
		layer = 1,
		enabled = true
	}
end

-- Localisations
local random = math.random

-- Synced Read
local GetUnitPosition = Spring.GetUnitPosition

-- Unsynced Ctrl
local PlaySoundFile = Spring.PlaySoundFile

-- constants
local SOUNDS_PATH = "sounds/deathsounds/"

-- variables
local soundClasses = {}
local soundClassSizes = {}
local udSoundCache = {}

if (gadgetHandler:IsSyncedCode()) then
-- SYNCED

	function gadget:Initialize()
		local subDirs = VFS.SubDirs(SOUNDS_PATH)
		for i = 1, #subDirs do
			local subDir = subDirs[i]
			if not subDir:match("/%.svn") then
				local dirName = string.gsub(subDir,SOUNDS_PATH,'')
				dirName = string.gsub(dirName,"/",'')
				-- Spring.Echo (dirName)
				soundClasses[dirName] = VFS.DirList(subDir, nil, nil, true)
				soundClassSizes[dirName] = #soundClasses[dirName]			
			end
		end
		for unitDefID, unitDef in pairs(UnitDefs) do
			local cp = unitDef.customParams
			if cp and cp.death_sounds then
				udSoundCache[unitDefID] = cp.death_sounds
			else
				udSoundCache[unitDefID] = "generic"
			end
		end
	end


	function gadget:UnitDestroyed(unitID, unitDefID, teamId,attackerID)
		if attackerID ~= nil then --Add this so that units who are destroyed via lua (like salvaging) or self destructed, will not play an overlapping sound effect
			local soundClass = udSoundCache[unitDefID]
			if soundClass then
				local choice = random(soundClassSizes[soundClass])
				local x, y, z = GetUnitPosition(unitID)
				local pickedSound = soundClasses[soundClass][choice]
				pickedSound = string.gsub(pickedSound, SOUNDS_PATH, "")
				pickedSound = string.gsub(pickedSound, soundClass, "")
				pickedSound = string.gsub(pickedSound, "/", "")
				pickedSound = string.gsub(pickedSound, ".wav", "")
				PlaySoundFile(pickedSound, 1, x, y, z)
			end
		end
	end

end