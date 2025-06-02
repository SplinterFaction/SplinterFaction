
base, pivotpoint, armleft, armright, armrear, armfront, sfxpoint1, bottom1, topspin1, sfxpointt1 = piece('base', 'pivotpoint', 'armleft', 'armright', 'armrear', 'armfront', 'sfxpoint1', 'bottom1', 'topspin1', 'sfxpointt1')

common = include("headers/common_includes_lus.lua")

-- state variables
terrainType = "terrainType"
skyhateEffect = "mex-fireball-small-blue"
isOn = false

function script.Create()
	StartThread(common.SmokeUnit, {base, pivotpoint, armleft, armright, armrear, armfront, sfxpoint1, bottom1, topspin1, sfxpointt1})

	StartThread(script.Skyhateceg)

	mexSpinSpeed = math.random(20,100)
	UnitScript.Spin(pivotpoint,y_axis,math.rad(mexSpinSpeed))

	UnitScript.Spin(topspin1,y_axis,math.rad(mexSpinSpeed * 0.25))
end

function script.Skyhateceg()
	while isOn do
		common.CustomEmitter(sfxpoint1, skyhateEffect)
		Sleep(500)
	end
end

function script.Activate()
	isOn = true
	if not skyhateThread then
		skyhateThread = StartThread(script.Skyhateceg)
	end
end

function script.Deactivate()
	isOn = false
	if skyhateThread then
		KillThread(skyhateThread)
		skyhateThread = nil
	end
end

sleep1 = math.random(2000,4000)

function script.Killed()
	Explode(base, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(armleft, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(armright, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(armrear, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(armfront, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(topspin1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(bottom1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end