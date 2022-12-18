
base, cannonturret1, cannonbarrel1, cannonfirepoint1, cannonturret2, cannonbarrel2, cannonfirepoint2, cannonturret3, cannonbarrel3, cannonfirepoint3, laserturret1, laserbarrel1, laserfirepoint1, laserturret2, laserbarrel2, laserfirepoint2 = piece('base', 'cannonturret1', 'cannonbarrel1', 'cannonfirepoint1', 'cannonturret2', 'cannonbarrel2', 'cannonfirepoint2', 'cannonturret3', 'cannonbarrel3', 'cannonfirepoint3', 'laserturret1', 'laserbarrel1', 'laserfirepoint1', 'laserturret2', 'laserbarrel2', 'laserfirepoint2')


common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}
local SIG_AIM2 = {}
local SIG_AIM3 = {}
local SIG_AIM4 = {}
local SIG_AIM5 = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.StartMoving()
	isMoving = true
end

function script.StopMoving()
	isMoving = false
end

function script.Create()
	StartThread(common.SmokeUnit, {base, cannonturret1, cannonbarrel1, cannonfirepoint1, cannonturret2, cannonbarrel2, cannonfirepoint2, cannonturret3, cannonbarrel3, cannonfirepoint3, laserturret1, laserbarrel1, laserfirepoint1, laserturret2, laserbarrel2, laserfirepoint2})
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

	Turn(laserturret1, y_axis, 0, 1)
	Turn(laserbarrel1, x_axis, 0, 1)

	Turn(laserturret2, y_axis, 0, 1)
	Turn(laserbarrel2, x_axis, 0, 1)
end

function script.AimFromWeapon(WeaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return cannonturret1
end

function script.QueryWeapon(WeaponID)
	if WeaponID == 1 then
		return cannonfirepoint1
	elseif WeaponID == 2 then
		return cannonfirepoint2
	elseif WeaponID == 3 then
		return cannonfirepoint3
	elseif WeaponID == 4 then
		return laserfirepoint1
	elseif WeaponID == 5 then
		return laserfirepoint1
	end
end

function script.FireWeapon(WeaponID)
	if WeaponID == 1 then
		EmitSfx (cannonfirepoint1, 1024)
	elseif WeaponID == 2 then
		EmitSfx (cannonfirepoint2, 1024)
	elseif WeaponID == 3 then
		EmitSfx (cannonfirepoint3, 1024)
	elseif WeaponID == 4 then
		-- EmitSfx (laserfirepoint1, 1024)
	elseif WeaponID == 5 then
		-- EmitSfx (laserfirepoint2, 1024)
	end
end

function script.AimWeapon(WeaponID, heading, pitch)
	if WeaponID == 1 then
		Signal(SIG_AIM)
		SetSignalMask(SIG_AIM)
		Turn(cannonturret1, y_axis, heading, 10)
		Turn(cannonbarrel1, x_axis, -pitch, 10)
		WaitForTurn(cannonturret1, y_axis)
		WaitForTurn(cannonbarrel1, x_axis)
		StartThread(RestoreAfterDelay)
		--Spring.Echo("AimWeapon: FireWeapon")
		return true
	elseif WeaponID == 2 then
		Signal(SIG_AIM2)
		SetSignalMask(SIG_AIM2)
		Turn(cannonturret2, y_axis, heading, 10)
		Turn(cannonbarrel2, x_axis, -pitch, 10)
		WaitForTurn(cannonturret2, y_axis)
		WaitForTurn(cannonbarrel2, x_axis)
		-- StartThread(RestoreAfterDelay)
		-- Spring.Echo("AimWeapon: FireWeapon")
		return true
	elseif WeaponID == 3 then
		Signal(SIG_AIM3)
		SetSignalMask(SIG_AIM3)
		Turn(cannonturret3, y_axis, heading, 10)
		Turn(cannonbarrel3, x_axis, -pitch, 10)
		WaitForTurn(cannonturret3, y_axis)
		WaitForTurn(cannonbarrel3, x_axis)
		-- StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 4 then
		Signal(SIG_AIM4)
		SetSignalMask(SIG_AIM4)
		Turn(laserturret1, y_axis, heading, 10)
		Turn(laserbarrel1, x_axis, -pitch, 10)
		WaitForTurn(laserturret1, y_axis)
		WaitForTurn(laserbarrel1, x_axis)
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 5 then
		Signal(SIG_AIM5)
		SetSignalMask(SIG_AIM5)
		Turn(laserturret2, y_axis, heading, 10)
		Turn(laserbarrel2, x_axis, -pitch, 10)
		WaitForTurn(laserturret2, y_axis)
		WaitForTurn(laserbarrel2, x_axis)
		-- StartThread(RestoreAfterDelay)
		return true
	end
end

function script.Killed()
	Explode(cannonturret1, SFX.EXPLODE_ON_HIT)
	Explode(cannonbarrel1, SFX.EXPLODE_ON_HIT)
	Explode(cannonturret2, SFX.EXPLODE_ON_HIT)
	Explode(cannonbarrel2, SFX.EXPLODE_ON_HIT)
	Explode(cannonturret3, SFX.EXPLODE_ON_HIT)
	Explode(cannonbarrel3, SFX.EXPLODE_ON_HIT)
	Explode(laserturret1, SFX.EXPLODE_ON_HIT)
	Explode(laserbarrel1, SFX.EXPLODE_ON_HIT)
	Explode(laserturret2, SFX.EXPLODE_ON_HIT)
	Explode(laserbarrel2, SFX.EXPLODE_ON_HIT)

	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end