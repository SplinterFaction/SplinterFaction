
base, railgunturret1, railgunbarrel1, railgunfirepoint1, railgunturret2, railgunbarrel2, railgunfirepoint2, railgunturret3, railgunbarrel3, railgunfirepoint3, railgunturret4, railgunbarrel4, railgunfirepoint4, cannonturret1, cannonbarrel1, cannonfirepoint1, wake = piece('base', 'railgunturret1', 'railgunbarrel1', 'railgunfirepoint1', 'railgunturret2', 'railgunbarrel2', 'railgunfirepoint2', 'railgunturret3', 'railgunbarrel3', 'railgunfirepoint3', 'railgunturret4', 'railgunbarrel4', 'railgunfirepoint4', 'cannonturret1', 'cannonbarrel1', 'cannonfirepoint1', 'wake')

common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}
local SIG_AIM2 = {}
local SIG_AIM3 = {}
local SIG_AIM4 = {}
local SIG_AIM5 = {}
local SIG_AIM6 = {}
local SIG_AIM7 = {}

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
		common.CustomEmitter(wake, "bubbles")
		Sleep(100)
	end
end

function script.Create()
	StartThread(common.SmokeUnit, {base, railgunturret1, railgunbarrel1, railgunfirepoint1, railgunturret2, railgunbarrel2, railgunfirepoint2, railgunturret3, railgunbarrel3, railgunfirepoint3, railgunturret4, railgunbarrel4, railgunfirepoint4, cannonturret1, cannonbarrel1, cannonfirepoint1})
end


function RestoreAfterDelay()
	Sleep(5000)
	-- Reset Turret and Barrels
	Turn(railgunturret1, y_axis, 0, 1)
	Turn(railgunbarrel1, x_axis, 0, 1)

	Turn(railgunturret2, y_axis, 0, 1)
	Turn(railgunbarrel2, x_axis, 0, 1)

	Turn(railgunturret3, y_axis, 0, 1)
	Turn(railgunbarrel3, x_axis, 0, 1)

	Turn(railgunturret4, y_axis, 0, 1)
	Turn(railgunbarrel4, x_axis, 0, 1)

	Turn(cannonturret1, y_axis, 0, 1)
	Turn(cannonbarrel1, x_axis, 0, 1)
end

function script.AimFromWeapon(WeaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return cannonturret1
end

function script.QueryWeapon(WeaponID)
	if WeaponID == 1 then
		return railgunfirepoint1
	elseif WeaponID == 2 then
		return railgunfirepoint2
	elseif WeaponID == 3 then
		return railgunfirepoint3
	elseif WeaponID == 4 then
		return railgunfirepoint4
	elseif WeaponID == 5 then
		return cannonfirepoint1
	end
end

function script.FireWeapon(WeaponID)
	if WeaponID == 1 then
		EmitSfx (railgunfirepoint1, 1024)
	elseif WeaponID == 2 then
		EmitSfx (railgunfirepoint2, 1024)
	elseif WeaponID == 3 then
		EmitSfx (railgunfirepoint3, 1024)
	elseif WeaponID == 4 then
		EmitSfx (railgunfirepoint4, 1024)
	elseif WeaponID == 5 then
		EmitSfx (cannonfirepoint1, 1024)
	end
end

function script.AimWeapon(WeaponID, heading, pitch)
	if WeaponID == 1 then
		Signal(SIG_AIM)
		SetSignalMask(SIG_AIM)
		Turn(railgunturret1, y_axis, heading, 10)
		Turn(railgunbarrel1, x_axis, -pitch, 10)
		WaitForTurn(railgunturret1, y_axis)
		WaitForTurn(railgunbarrel1, x_axis)
		StartThread(RestoreAfterDelay)
		--Spring.Echo("AimWeapon: FireWeapon")
		return true
	elseif WeaponID == 2 then
		Signal(SIG_AIM2)
		SetSignalMask(SIG_AIM2)
		Turn(railgunturret2, y_axis, heading, 10)
		Turn(railgunbarrel2, x_axis, -pitch, 10)
		WaitForTurn(railgunturret2, y_axis)
		WaitForTurn(railgunbarrel2, x_axis)
		StartThread(RestoreAfterDelay)
		--Spring.Echo("AimWeapon: FireWeapon")
		return true
	elseif WeaponID == 3 then
		Signal(SIG_AIM3)
		SetSignalMask(SIG_AIM3)
		Turn(railgunturret3, y_axis, heading, 10)
		Turn(railgunbarrel3, x_axis, -pitch, 10)
		WaitForTurn(railgunturret3, y_axis)
		WaitForTurn(railgunbarrel3, x_axis)
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 4 then
		Signal(SIG_AIM4)
		SetSignalMask(SIG_AIM4)
		Turn(railgunturret4, y_axis, heading, 10)
		Turn(railgunbarrel4, x_axis, -pitch, 10)
		WaitForTurn(railgunturret4, y_axis)
		WaitForTurn(railgunbarrel4, x_axis)
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 5 then
		Signal(SIG_AIM5)
		SetSignalMask(SIG_AIM5)
		Turn(cannonturret1, y_axis, heading, 10)
		Turn(cannonbarrel1, x_axis, -pitch, 10)
		WaitForTurn(cannonturret1, y_axis)
		WaitForTurn(cannonbarrel1, x_axis)
		StartThread(RestoreAfterDelay)
		return true
	end
end

function script.Killed()
	Explode(railgunturret1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(railgunturret2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(railgunturret3, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(railgunturret4, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(railgunbarrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(railgunbarrel2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(railgunbarrel3, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(railgunbarrel4, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(cannonturret1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(cannonbarrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)

	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end