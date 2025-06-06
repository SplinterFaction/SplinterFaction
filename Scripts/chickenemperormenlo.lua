base, turret, barrel1, firepoint1, firepoint2, dirt, gat1, gat2 = piece('base', 'turret', 'barrel1', 'firepoint1', 'firepoint2', 'dirt', 'gat1', 'gat2')
local SIG_AIM = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
	StartThread(common.SmokeUnit, {base, turret, barrel1})
	Move(base, y_axis, -2, 50)
end

common = include("headers/common_includes_lus.lua")

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
	Turn(base, y_axis, 0, 5)
	Turn(barrel1, x_axis, 0, 5)
	Spring.UnitScript.StopSpin( gat1, z_axis, 0.01)
	Spring.UnitScript.StopSpin( gat2, z_axis, 0.01)
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
	currentFirepoint = 3 - currentFirepoint
	Spring.UnitScript.Spin( gat1, z_axis, 5 )
	Spring.UnitScript.Spin( gat2, z_axis, -5 )
	EmitSfx (firepoints[currentFirepoint], 1024)
end

function script.AimWeapon(weaponID, heading, pitch)
	Signal(SIG_AIM)
	SetSignalMask(SIG_AIM)
	Turn(turret, y_axis, heading, 100)
	Turn(barrel1, x_axis, -pitch, 100)
	WaitForTurn(base, y_axis)
	WaitForTurn(barrel1, x_axis)
	StartThread(RestoreAfterDelay)
	--Spring.Echo("AimWeapon: FireWeapon")
	return true
end

function script.Killed()
		Explode(barrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(turret, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(base, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(gat1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(gat2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end