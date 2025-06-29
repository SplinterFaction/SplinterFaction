--------------------------------------------------------------------------------
-- defs.lua
-- Central entry point for all defs + post-processing
--------------------------------------------------------------------------------

VFS.Include('init.lua')

-- DEFS table will contain all loaded raw definitions
DEFS = {}

-- Compatibility fix for old engine versions (e.g. mission editor)
if not VFS.BASE then
	VFS.BASE = "b"
	VFS.MOD  = "M"
	VFS.MAP  = "m"
end

local vfs_modes = VFS.MAP .. VFS.MOD .. VFS.BASE

-- Helper to load a single def file
local function LoadDefs(name)
	local filename = 'gamedata/' .. name .. '.lua'
	local success, result = pcall(VFS.Include, filename, nil, vfs_modes)

	if not success then
		Spring.Log("defs.lua", LOG.ERROR, "Failed to load " .. name)
		error(result)
	end

	if result == nil then
		error("Missing lua table for " .. name)
	end

	return result
end

-- Load all raw def tables
Spring.TimeCheck("Loading all definitions", function()
	DEFS.unitDefs    = LoadDefs('unitDefs')
	DEFS.weaponDefs  = LoadDefs('weaponDefs')
	DEFS.featureDefs = LoadDefs('featureDefs')
	DEFS.armorDefs   = LoadDefs('armorDefs')
	DEFS.moveDefs    = LoadDefs('moveDefs')
end)

-- Post-processing logic
local alldefs_post     = VFS.Include("gamedata/alldefs_post.lua")
local featuredefs_post = VFS.Include("gamedata/featuredefs_post.lua")

alldefs_post(DEFS.unitDefs, DEFS.weaponDefs, Spring.GetModOptions())
featuredefs_post(DEFS.featureDefs, DEFS.unitDefs)

-- Return all final def tables to the engine
return {
	unitdefs    = DEFS.unitDefs,
	weapondefs  = DEFS.weaponDefs,
	featuredefs = DEFS.featureDefs,
	armordefs   = DEFS.armorDefs,
	movedefs    = DEFS.moveDefs,
}