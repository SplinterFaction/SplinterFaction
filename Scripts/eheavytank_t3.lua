base, turret, barrel1, firepoint1, dirt, t3turret, t3barrel1, t3firepoint = piece('base', 'turret', 'barrel1', 'firepoint1', 'dirt', 't3turret', 't3barrel1', 't3firepoint')
local SIG_AIM = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
	StartThread(common.SmokeUnit, {base, turret, barrel1})
end

common = include("headers/common_includes_lus.lua")

function script.setSFXoccupy(setSFXoccupy_argument)
	common.setSFXoccupy(setSFXoccupy_argument)
end

function script.StartMoving()
   isMoving = true
   	StartThread(thrust)
end

function script.StopMoving()
   isMoving = false
end   

function thrust()
	common.DirtTrail()
end


local function RestoreAfterDelay()
	Sleep(2000)
	Turn(turret, y_axis, 0, 5)
	Turn(barrel1, x_axis, 0, 5)
end		

function script.AimFromWeaponPrimary(weaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return turret
end

function script.QueryWeaponPrimary(weaponID)
	--Spring.Echo("QueryWeapon: FireWeapon")
	return firepoint1
end

function script.AimWeaponPrimary(weaponID, heading, pitch)
	Signal(SIG_AIM)
	SetSignalMask(SIG_AIM)
	Turn(turret, y_axis, heading, 100)
	Turn(barrel1, x_axis, -pitch, 100)
	WaitForTurn(turret, y_axis)
	WaitForTurn(barrel1, x_axis)
	StartThread(RestoreAfterDelay)
	--Spring.Echo("AimWeapon: FireWeapon")
	return true
end

function script.FireWeaponPrimary(weaponID)
	--Spring.Echo("FireWeapon: FireWeapon")
	EmitSfx (firepoint1, 1024)
end


function script.AimFromWeaponSecondary(weaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return t3turret
end

function script.QueryWeaponSecondary(weaponID)
	--Spring.Echo("QueryWeapon: FireWeapon")
	return t3firepoint1
end

function script.AimWeaponSecondary(weaponID, heading, pitch)
	Signal(SIG_AIM)
	SetSignalMask(SIG_AIM)
	Turn(turret, y_axis, heading, 100)
	Turn(barrel1, x_axis, -pitch, 100)
	WaitForTurn(t3turret, y_axis)
	WaitForTurn(t3barrel1, x_axis)
	StartThread(RestoreAfterDelay)
	--Spring.Echo("AimWeapon: FireWeapon")
	return true
end

function script.FireWeaponSecondary(weaponID)
	--Spring.Echo("FireWeapon: FireWeapon")
	EmitSfx (t3firepoint1, 1024)
end


function script.Killed()
		Explode(barrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(turret, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(t3barrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(t3turret, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end