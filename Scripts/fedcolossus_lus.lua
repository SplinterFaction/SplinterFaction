
base, cannonturret1, cannonbarrel1, cannonfirepoint1, cannonturret2, cannonbarrel2, cannonfirepoint2, cannonturret3, cannonbarrel3, cannonfirepoint3, missileturret1, missilebarrel1, missilefirepoint1, missileturret2, missilebarrel2, missilefirepoint2, phalanxturret1, phalanxbarrel1, phalanxfirepoint1, phalanxfirepoint2, phalanxfirepoint3, phalanxfirepoint4, torpedofirepoint1 = piece('base', 'cannonturret1', 'cannonbarrel1', 'cannonfirepoint1', 'cannonturret2', 'cannonbarrel2', 'cannonfirepoint2', 'cannonturret3', 'cannonbarrel3', 'cannonfirepoint3', 'missileturret1', 'missilebarrel1', 'missilefirepoint1', 'missileturret2', 'missilebarrel2', 'missilefirepoint2', 'phalanxturret1', 'phalanxbarrel1', 'phalanxfirepoint1', 'phalanxfirepoint2', 'phalanxfirepoint3', 'phalanxfirepoint4', 'torpedofirepoint1')

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
		common.CustomEmitter(base, "bubbles")
		Sleep(100)
	end
end

function script.Create()
	StartThread(common.SmokeUnit, {base, cannonturret1, cannonbarrel1, cannonfirepoint1, cannonturret2, cannonbarrel2, cannonfirepoint2, cannonturret3, cannonbarrel3, cannonfirepoint3, missileturret1, missilebarrel1, missilefirepoint1, missileturret2, missilebarrel2, missilefirepoint2, phalanxturret1, phalanxbarrel1, phalanxfirepoint1, phalanxfirepoint2, phalanxfirepoint3, phalanxfirepoint4, torpedofirepoint1})
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

	Turn(missileturret1, y_axis, 0, 1)
	Turn(missilebarrel1, x_axis, 0, 1)

	Turn(missileturret2, y_axis, 0, 1)
	Turn(missilebarrel2, x_axis, 0, 1)

	Turn(phalanxturret1, y_axis, 0, 1)
	Turn(phalanxbarrel1, x_axis, 0, 1)
end

function script.AimFromWeapon(WeaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return cannonturret1
end

local firepoints = {phalanxfirepoint1, phalanxfirepoint2, phalanxfirepoint3, phalanxfirepoint4}
local currentFirepoint = 1
local totalNumberofFirepoints = 4

function script.QueryWeapon(WeaponID)
	if WeaponID == 1 then
		return cannonfirepoint1
	elseif WeaponID == 2 then
		return cannonfirepoint2
	elseif WeaponID == 3 then
		return cannonfirepoint3
	elseif WeaponID == 4 then
		return missilefirepoint1
	elseif WeaponID == 5 then
		return missilefirepoint2
	elseif WeaponID == 6 then
		return firepoints[currentFirepoint]
	elseif WeaponID == 7 then
		return torpedofirepoint1
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
		-- EmitSfx (missilefirepoint1, 1024)
	elseif WeaponID == 5 then
		-- EmitSfx (missilefirepoint2, 1024)
	elseif WeaponID == 6 then
		currentFirepoint = currentFirepoint + 1
		if currentFirepoint == (totalNumberofFirepoints + 1) then -- when currentFirepoint gets to one more than the total number of firepoints, reset it to 1
			currentFirepoint = 1
		end
		-- Spring.Echo(currentFirepoint)
		EmitSfx (firepoints[currentFirepoint], 1024)
	elseif WeaponID == 7 then
		-- EmitSfx (torpedofirepoint1, 1024)
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
		StartThread(RestoreAfterDelay)
		--Spring.Echo("AimWeapon: FireWeapon")
		return true
	elseif WeaponID == 3 then
		Signal(SIG_AIM3)
		SetSignalMask(SIG_AIM3)
		Turn(cannonturret3, y_axis, heading, 10)
		Turn(cannonbarrel3, x_axis, -pitch, 10)
		WaitForTurn(cannonturret3, y_axis)
		WaitForTurn(cannonbarrel3, x_axis)
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 4 then
		Signal(SIG_AIM4)
		SetSignalMask(SIG_AIM4)
		Turn(missileturret1, y_axis, heading, 10)
		Turn(missilebarrel1, x_axis, -pitch, 10)
		WaitForTurn(missileturret1, y_axis)
		WaitForTurn(missilebarrel1, x_axis)
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 5 then
		Signal(SIG_AIM5)
		SetSignalMask(SIG_AIM5)
		Turn(missileturret2, y_axis, heading, 10)
		Turn(missilebarrel2, x_axis, -pitch, 10)
		WaitForTurn(missileturret2, y_axis)
		WaitForTurn(missilebarrel2, x_axis)
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 6 then
		Signal(SIG_AIM6)
		SetSignalMask(SIG_AIM6)
		Turn(phalanxturret1, y_axis, heading, 10)
		Turn(phalanxbarrel1, x_axis, -pitch, 10)
		WaitForTurn(phalanxturret1, y_axis)
		WaitForTurn(phalanxbarrel1, x_axis)
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 7 then
		Signal(SIG_AIM7)
		SetSignalMask(SIG_AIM7)

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
	Explode(missileturret1, SFX.EXPLODE_ON_HIT)
	Explode(missilebarrel1, SFX.EXPLODE_ON_HIT)
	Explode(missileturret2, SFX.EXPLODE_ON_HIT)
	Explode(missilebarrel2, SFX.EXPLODE_ON_HIT)
	Explode(phalanxturret1, SFX.EXPLODE_ON_HIT)
	Explode(phalanxbarrel1, SFX.EXPLODE_ON_HIT)

	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end