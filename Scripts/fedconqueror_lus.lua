
base, cannonturret1, cannonbarrel1, cannonfirepoint1, cannonturret2, cannonbarrel2, cannonfirepoint2, cannonturret3, cannonbarrel3, cannonfirepoint3,  cannonturret4, cannonbarrel4, cannonfirepoint4 = piece('base', 'cannonturret1', 'cannonbarrel1', 'cannonfirepoint1', 'cannonturret2', 'cannonbarrel2', 'cannonfirepoint2', 'cannonturret3', 'cannonbarrel3', 'cannonfirepoint3',  'cannonturret4', 'cannonbarrel4', 'cannonfirepoint4')


common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.StartMoving()
	isMoving = true
	StartThread(script.Bubbles)
end

function script.StopMoving()
	isMoving = false
end

function script.Bubbles()
	while isMoving do
		common.CustomEmitter(base, "bubbles")
		Sleep(100)
	end
end

function script.Create()
	StartThread(common.SmokeUnit, {base, cannonturret1, cannonbarrel1, cannonfirepoint1, cannonturret2, cannonbarrel2, cannonfirepoint2, cannonturret3, cannonbarrel3, cannonfirepoint3,  cannonturret4, cannonbarrel4, cannonfirepoint4})
end


function RestoreAfterDelay()
	Sleep(5000)
	-- Reset Turret and Barrels
	Turn(cannonturret1, y_axis, 0, 1)
	Turn(cannonbarrel1, x_axis, 0, 1)

	Turn(cannonturret2, y_axis, 0, 1)
	Turn(cannonbarrel2, x_axis, 0, 1)

	Turn(cannonturret3, y_axis, 0, 1)
	Turn(cannonbarrel3, x_axis, 0, 1)

	Turn(cannonturret4, y_axis, 0, 1)
	Turn(cannonbarrel4, x_axis, 0, 1)
end

local gun_1 = 1

local gunPieces = {
	{ firepoint = cannonfirepoint2 },
	{ firepoint = cannonfirepoint1 },
	{ firepoint = cannonfirepoint3 },
	{ firepoint = cannonfirepoint4 },
}

function script.AimFromWeapon(WeaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return cannonturret2
end

function script.Shot(num)
	gun_1 = gun_1 + 1
	if gun_1 > 4 then
		gun_1 = 1
	end
	EmitSfx(gunPieces[gun_1].firepoint, 1024)
end

function script.QueryWeapon(WeaponID)
	if WeaponID == 1 then
		return gunPieces[gun_1].firepoint
	end
end

function script.FireWeapon(WeaponID)

end

function script.AimWeapon(WeaponID, heading, pitch)
	if WeaponID == 1 then
		Signal(SIG_AIM)
		SetSignalMask(SIG_AIM)
		Turn(cannonturret1, y_axis, heading, 10)
		Turn(cannonbarrel1, x_axis, -pitch, 10)
		Turn(cannonturret2, y_axis, heading, 10)
		Turn(cannonbarrel2, x_axis, -pitch, 10)
		Turn(cannonturret3, y_axis, heading, 10)
		Turn(cannonbarrel3, x_axis, -pitch, 10)
		Turn(cannonturret4, y_axis, heading, 10)
		Turn(cannonbarrel4, x_axis, -pitch, 10)
		WaitForTurn(cannonturret1, y_axis)
		WaitForTurn(cannonbarrel1, x_axis)
		WaitForTurn(cannonturret2, y_axis)
		WaitForTurn(cannonbarrel2, x_axis)
		WaitForTurn(cannonturret3, y_axis)
		WaitForTurn(cannonbarrel3, x_axis)
		WaitForTurn(cannonturret4, y_axis)
		WaitForTurn(cannonbarrel4, x_axis)
		StartThread(RestoreAfterDelay)
		--Spring.Echo("AimWeapon: FireWeapon")
		return true
	end
end

function script.Killed()

	Explode(cannonturret1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(cannonbarrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(cannonturret2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(cannonbarrel2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(cannonturret3, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(cannonbarrel3, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(cannonturret4, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(cannonbarrel4, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)

	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end