base, dome, antennae = piece('base', 'dome', 'antennae')

local deathPieces = {
	base, dome, antennae,
}
local SIG_AIM = {}

-- state variables
terrainType = "terrainType"

common = include("headers/common_includes_lus.lua")

function script.Create()
	StartThread(common.SmokeUnit, {base, dome, antennae})
end

function script.Killed()
	common.ExplodePieces(deathPieces)
	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end