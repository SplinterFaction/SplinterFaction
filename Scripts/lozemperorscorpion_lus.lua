base, turret, cannonbarrel1, cannonbarrelfirepoint1, wheels1, wheels2, wheels3 = piece('base', 'turret', 'cannonbarrel1', 'cannonbarrelfirepoint1', 'wheels1', 'wheels2', 'wheels3')
local SIG_AIM = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
	StartThread(common.SmokeUnit, {base, turret, cannonbarrel1, cannonbarrelfirepoint1, wheels1, wheels2, wheels3})
end

common = include("headers/common_includes_lus.lua")

function script.StartMoving()
   isMoving = true
	common.WheelStartSpin3()
end

function script.StopMoving()
   isMoving = false
	common.WheelStopSpin3()
end

local function RestoreAfterDelay()
	Sleep(2000)
	Turn(turret, y_axis, 0, 1)
	Turn(cannonbarrel1, x_axis, 0, 1)
end		

function script.AimFromWeapon(weaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return turret
end

function script.QueryWeapon(weaponID)
	--Spring.Echo("QueryWeapon: FireWeapon")
	return cannonbarrelfirepoint1
end

function script.AimWeapon(weaponID, heading, pitch)
	Signal(SIG_AIM)
	SetSignalMask(SIG_AIM)
	Turn(turret, y_axis, heading, 2)
	Turn(cannonbarrel1, x_axis, -pitch, 10)
	WaitForTurn(turret, y_axis)
	WaitForTurn(cannonbarrel1, x_axis)
	StartThread(RestoreAfterDelay)
	--Spring.Echo("AimWeapon: FireWeapon")
	return true
end

function script.FireWeapon(weaponID)
	--Spring.Echo("FireWeapon: FireWeapon")
	EmitSfx (cannonbarrelfirepoint1, 1024)
end

function script.Killed()
		Explode(cannonbarrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(turret, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(wheels1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(wheels2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(wheels3, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end