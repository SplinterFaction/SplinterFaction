
base, pivotpoint, armleft, armright, armrear, armfront, sfxpoint1, bottom1, topspin1, sfxpointt1, bottom2, topspin2, sfxpointt2, bottom3, topspin3, sfxpointt3, bottom4, topspin4, sfxpointt4 = piece('base', 'pivotpoint', 'armleft', 'armright', 'armrear', 'armfront', 'sfxpoint1', 'bottom1', 'topspin1', 'sfxpointt1', 'bottom2', 'topspin2', 'sfxpointt2', 'bottom3', 'topspin3', 'sfxpointt3', 'bottom4', 'topspin4', 'sfxpointt4')

local deathPieces = {
	base, pivotpoint, armleft, armright, armrear, armfront, sfxpoint1, bottom1, topspin1, sfxpointt1, bottom2, topspin2, sfxpointt2, bottom3, topspin3, sfxpointt3, bottom4, topspin4, sfxpointt4,
}

common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}

-- state variables
terrainType = "terrainType"
skyhateEffect = "mex-fireball-small-green"
isOn = false

function script.Create()
	StartThread(common.SmokeUnit, {base, pivotpoint, armleft, armright, armrear, armfront, sfxpoint1, bottom1, topspin1, sfxpointt1, bottom2, topspin2, sfxpointt2, bottom3, topspin3, sfxpointt3, bottom4, topspin4, sfxpointt4})

	StartThread(script.Skyhateceg)


	mexSpinSpeed = math.random(20,100)
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
	UnitScript.Spin(pivotpoint,y_axis,math.rad(mexSpinSpeed * 0.25),math.rad(mexSpinSpeed * 0.01))
	UnitScript.Spin(topspin1,y_axis,math.rad(mexSpinSpeed * 0.25),math.rad(mexSpinSpeed * 0.01))
	UnitScript.Spin(topspin2,y_axis,math.rad(mexSpinSpeed * 0.25),math.rad(mexSpinSpeed * 0.01))
	UnitScript.Spin(topspin3,y_axis,math.rad(mexSpinSpeed * 0.25),math.rad(mexSpinSpeed * 0.01))
	UnitScript.Spin(topspin4,y_axis,math.rad(mexSpinSpeed * 0.25),math.rad(mexSpinSpeed * 0.01))
end

function script.Deactivate()
	isOn = false
	if skyhateThread then
		KillThread(skyhateThread)
		skyhateThread = nil
	end
	UnitScript.StopSpin(pivotpoint,y_axis,math.rad(mexSpinSpeed * 0.01))
	UnitScript.StopSpin(topspin1,y_axis,math.rad(mexSpinSpeed * 0.01))
	UnitScript.StopSpin(topspin2,y_axis,math.rad(mexSpinSpeed * 0.01))
	UnitScript.StopSpin(topspin3,y_axis,math.rad(mexSpinSpeed * 0.01))
	UnitScript.StopSpin(topspin4,y_axis,math.rad(mexSpinSpeed * 0.01))
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
	common.ExplodePieces(deathPieces)
	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end