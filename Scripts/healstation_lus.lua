
base, nanopoint1, fins, fin1, fin2, fin3, fin4, pad1, land1, base1, spinner, firepoint1 = piece('base', 'nanopoint1', 'fins', 'fin1', 'fin2', 'fin3', 'fin4', 'pad1', 'land1', 'base1', 'spinner', 'firepoint1')

common = include("headers/common_includes_lus.lua")

-- state variables
terrainType = "terrainType"
skyhateEffect = "powerplant-fireball-small-purple"
skyhateEffect2 = "healsmall"

function script.Create()
	StartThread(common.SmokeUnit, {base, nanopoint1, fins, fin1, fin2, fin3, fin4, pad1, land1, base1, spinner, firepoint1})
	StartThread(script.Skyhateceg)
	Spin(spinner,y_axis,math.rad(20))
end

function script.Skyhateceg()
	while true do
		common.CustomEmitter(firepoint1, skyhateEffect) -- Second argument is the piece name, third argument needs to be a string because it will be the name of the CEG effect used
		common.CustomEmitter(firepoint1, skyhateEffect2) -- Second argument is the piece name, third argument needs to be a string because it will be the name of the CEG effect used
		Sleep(1000)
	end
end

function script.Killed()
	Explode(base, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(fin1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(fin2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(fin3, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(fin4, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(spinner, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(base1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end