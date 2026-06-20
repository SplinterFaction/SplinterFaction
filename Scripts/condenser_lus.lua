
base, sfxpoint1 = piece('base')

local deathPieces = {
	base,
}

common = include("headers/common_includes_lus.lua")

-- state variables
terrainType = "terrainType"

function script.Create()
	StartThread(common.SmokeUnit, {base})
end

function script.Killed()
	common.ExplodePieces(deathPieces)
	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end