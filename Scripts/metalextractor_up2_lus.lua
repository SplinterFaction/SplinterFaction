
base, pivotpoint, armleft, armright, armrear, armfront, sfxpoint1, bottom1, topspin1, sfxpointt1, bottom2, topspin2, sfxpointt2, bottom3, topspin3, sfxpointt3 = piece('base', 'pivotpoint', 'armleft', 'armright', 'armrear', 'armfront', 'sfxpoint1', 'bottom1', 'topspin1', 'sfxpointt1', 'bottom2', 'topspin2', 'sfxpointt2', 'bottom3', 'topspin3', 'sfxpointt3')

common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}

-- state variables
terrainType = "terrainType"
skyhateEffect = "mex-fireball-small-purple"
isOn = false

function script.Create()
	StartThread(common.SmokeUnit, {base, pivotpoint, armleft, armright, armrear, armfront, sfxpoint1, bottom1, topspin1, sfxpointt1, bottom2, topspin2, sfxpointt2, bottom3, topspin3, sfxpointt3})

	StartThread(script.Skyhateceg)

	mexSpinSpeed = math.random(20,100)
	UnitScript.Spin(pivotpoint,y_axis,math.rad(mexSpinSpeed))

	UnitScript.Spin(topspin1,y_axis,math.rad(mexSpinSpeed * 0.25))
	UnitScript.Spin(topspin2,y_axis,math.rad(-mexSpinSpeed * 0.50))
	UnitScript.Spin(topspin3,y_axis,math.rad(mexSpinSpeed * 0.75))
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

function script.AimFromWeapon(weaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return pivotpoint
end

local firepoints = {pivotpoint}
local currentFirepoint = 1

function script.QueryWeapon(weaponID)
	return firepoints[currentFirepoint]
end

function script.FireWeapon(weaponID)
	-- EmitSfx (firepoints[currentFirepoint], 1024)
end

function script.AimWeapon(weaponID, heading, pitch)
	Signal(SIG_AIM)
	SetSignalMask(SIG_AIM)
	--Spring.Echo("AimWeapon: FireWeapon")
	return false
end

function script.Killed()
	Explode(base, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(armleft, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(armright, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(armrear, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(armfront, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(topspin1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(topspin2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(topspin3, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(bottom1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(bottom2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(bottom3, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end