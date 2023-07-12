
base = piece('base')

common = include("headers/common_includes_lus.lua")

-- state variables
terrainType = "terrainType"

function script.Create()
	StartThread(common.SmokeUnit, {base})
end

function script.Killed()
	Explode(base, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end