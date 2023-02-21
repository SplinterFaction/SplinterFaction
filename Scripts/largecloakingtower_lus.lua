base, dome, antennae = piece('base', 'dome', 'antennae')
local SIG_AIM = {}

-- state variables
terrainType = "terrainType"

common = include("headers/common_includes_lus.lua")

function script.Create()
	StartThread(common.SmokeUnit, {base, dome, antennae})
end

function script.Killed()
		Explode(base, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(dome, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(antennae, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end