if not gadgetHandler:IsSyncedCode() then return end

function gadget:GetInfo()
	return {
		name      = "Unit Damaged Sound",
		author    = "Plays impact sound whenever unit is damaged, based on the weapon type",
		version   = "1",
		date      = "2023",
		license   = "GNU GPL, v2 or later",
		layer     = 1,
		enabled   = true,
	}
end

-- Localisations
local random = math.random

-- Synced Read
local GetUnitPosition = Spring.GetUnitPosition

-- Unsynced Ctrl
local PlaySoundFile = Spring.PlaySoundFile

-- constants
local SOUNDS_PATH = "sounds/impacts/"

-- variables
local soundClasses = {}
local soundClassSizes = {}
local wdSoundCache = {}

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
		for weaponDefID, weaponDef in pairs(WeaponDefs) do
			local cp = weaponDef.customParams
			if cp and cp.impact_sounds then
				wdSoundCache[weaponDefID] = cp.impact_sounds
            else
                if WeaponDefs[weaponDefID].type ~= "BeamLaser" then
                    wdSoundCache[weaponDefID] = "generic"
                end
            end
		end
	end

	function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
		if attackerID and weaponDefID and projectileID then --Add this so that units who are destroyed via lua (like salvaging) or self destructed, will not play an overlapping sound effect
			local soundClass = wdSoundCache[weaponDefID]
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