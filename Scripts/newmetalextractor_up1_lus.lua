
base, spinner, sfxpoint, tank_up1, tank_up2, tank_up3, tank_up4 = piece('base', 'spinner', 'sfxpoint', 'tank_up1', 'tank_up2', 'tank_up3', 'tank_up4')

common = include("headers/common_includes_lus.lua")

-- state variables
terrainType = "terrainType"
skyhateEffect = "mex-fireball-small-orange"
isOn = false

function script.Create()
	Spring.UnitScript.Hide ( tank_up2 )
	Spring.UnitScript.Hide ( tank_up3 )
	Spring.UnitScript.Hide ( tank_up4 )
	StartThread(common.SmokeUnit, {base, spinner, sfxpoint, tank_up1, tank_up2, tank_up3, tank_up4})

	StartThread(script.Skyhateceg)

	mexSpinSpeed = math.random(20,100)
end

function script.Skyhateceg()
	while isOn do
		common.CustomEmitter(sfxpoint, skyhateEffect)
		Sleep(500)
	end
end

function script.Activate()
	isOn = true
	if not skyhateThread then
		skyhateThread = StartThread(script.Skyhateceg)
	end
	UnitScript.Spin(spinner,y_axis,math.rad(mexSpinSpeed * 0.25),math.rad(mexSpinSpeed * 0.01))
end

function script.Deactivate()
	isOn = false
	if skyhateThread then
		KillThread(skyhateThread)
		skyhateThread = nil
	end
	UnitScript.StopSpin(spinner,y_axis,math.rad(mexSpinSpeed * 0.01))
end

sleep1 = math.random(2000,4000)

function script.Killed()
	Explode(base, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(spinner, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(tank_up1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	-- Explode(tank_up2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	-- Explode(tank_up3, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	-- Explode(tank_up4, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end