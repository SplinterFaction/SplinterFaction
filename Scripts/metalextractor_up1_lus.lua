
base, pivotpoint, armleft, armright, armrear, armfront, sfxpoint1, bottom1, topspin1, sfxpointt1, bottom2, topspin2, sfxpointt2 = piece('base', 'pivotpoint', 'armleft', 'armright', 'armrear', 'armfront', 'sfxpoint1', 'bottom1', 'topspin1', 'sfxpointt1', 'bottom2', 'topspin2', 'sfxpointt2')

common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}

-- state variables
terrainType = "terrainType"
skyhateEffect = "mex-fireball-small-orange"

function script.Create()
	StartThread(common.SmokeUnit, {base, pivotpoint, armleft, armright, armrear, armfront, sfxpoint1, bottom1, topspin1, sfxpointt1, bottom2, topspin2, sfxpointt2})

	StartThread(script.Skyhateceg)

	mexSpinSpeed = math.random(20,100)
	UnitScript.Spin(pivotpoint,y_axis,math.rad(mexSpinSpeed))

	UnitScript.Spin(topspin1,y_axis,math.rad(mexSpinSpeed * 0.25))
	UnitScript.Spin(topspin2,y_axis,math.rad(-mexSpinSpeed * 0.50))
end

function script.Skyhateceg()
	while true do
		common.CustomEmitter(sfxpoint1, skyhateEffect) -- Second argument is the piece name, third argument needs to be a string because it will be the name of the CEG effect used
		Sleep(500)
	end
end

function script.AimFromWeapon(weaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return pivotpoint
end

function script.QueryWeapon(weaponID)
	return pivotpoint
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
	Explode(bottom1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(bottom2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end