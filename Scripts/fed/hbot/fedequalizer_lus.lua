pelvis, dirt, lthigh, lleg, lfoot, rthigh, rleg, rfoot, turret, barrels, firepoint1, firepoint2 = piece('pelvis', 'dirt', 'lthigh', 'lleg', 'lfoot', 'rthigh', 'rleg', 'rfoot', 'turret', 'barrels', 'firepoint1', 'firepoint2')

common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

-- Lessgooooo (Walk)
common.WalkScript()

function script.Create()
	StartThread(common.SmokeUnit, {pelvis, dirt, lthigh, lleg, lfoot, rthigh, rleg, rfoot, turret, barrels, firepoint1, firepoint2})
end

function thrust()
	common.DirtTrail()
end

local function RestoreAfterDelay()
	Sleep(2000)
	Turn(turret, y_axis, 0, 5)
	Turn(barrels, x_axis, 0, 5)

	--EmitSfx (missile1, "nano-small-animated")
	--Spring.UnitScript.Show(missile1)
	--EmitSfx (missile4, "nano-small-animated")
	--Spring.UnitScript.Show(missile2)
	--EmitSfx (missile3, "nano-small-animated")
	--Spring.UnitScript.Show(missile3)
	--EmitSfx (missile4, "nano-small-animated")
	--Spring.UnitScript.Show(missile4)
	--currentFirepoint = 1
end		

function script.AimFromWeapon(weaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return turret
end

local firepoints = {firepoint1, firepoint2}
local currentFirepoint = 1

function script.QueryWeapon(weaponID)
	return firepoints[currentFirepoint]
end

function script.FireWeapon(weaponID)
	--Spring.Echo("Current firepoint is " .. firepoints[currentFirepoint])
	--if firepoints[currentFirepoint] == firepoint1 then
	--	Spring.UnitScript.Hide(missile1)
	--	EmitSfx (missile4, "nano-tiny-animated")
	--	Spring.UnitScript.Show(missile4)
	--end
	--if firepoints[currentFirepoint] == firepoint2 then
	--	Spring.UnitScript.Hide(missile2)
	--	EmitSfx (missile1, "nano-tiny-animated")
	--	Spring.UnitScript.Show(missile1)
	--end
	--if firepoints[currentFirepoint] == firepoint3 then
	--	Spring.UnitScript.Hide(missile3)
	--	EmitSfx (missile4, "nano-tiny-animated")
	--	Spring.UnitScript.Show(missile2)
	--end
	--if firepoints[currentFirepoint] == firepoint4 then
	--	Spring.UnitScript.Hide(missile4)
	--	EmitSfx (missile3, "nano-tiny-animated")
	--	Spring.UnitScript.Show(missile3)
	--end
	currentFirepoint = currentFirepoint + 1
	if currentFirepoint >= 3 then
		currentFirepoint = 1
	end
	--Spring.Echo("Next firepoint is " .. firepoints[currentFirepoint])
end

function script.AimWeapon(weaponID, heading, pitch)
	Signal(SIG_AIM)
	SetSignalMask(SIG_AIM)
	Turn(turret, y_axis, heading, 10)
	Turn(barrels, x_axis, -pitch, 10)
	WaitForTurn(turret, y_axis)
	WaitForTurn(barrels, x_axis)
	StartThread(RestoreAfterDelay)
	--Spring.Echo("AimWeapon: FireWeapon")
	return true
end

function script.Killed()
		Explode(barrels, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(turret, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(pelvis, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(rthigh, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(rleg, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(lthigh, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(lleg, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end