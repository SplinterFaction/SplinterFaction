

wheels1, wheels2, wheels3, wheels4, wheels5, wheels6, railturret1, railbarrel1, railfirepoint1, burstturret1, burstbarrel1, burstfirepoint1, burstturret2, burstbarrel2, burstfirepoint2, missileturret1, missilebarrel1, missilefirepoint1, missileturret2, missilebarrel2, missilefirepoint2 = piece('wheels1', 'wheels2', 'wheels3', 'wheels4', 'wheels5', 'wheels6', 'railturret1', 'railbarrel1', 'railfirepoint1', 'burstturret1', 'burstbarrel1', 'burstfirepoint1', 'burstturret2', 'burstbarrel2', 'burstfirepoint2', 'missileturret1', 'missilebarrel1', 'missilefirepoint1', 'missileturret2', 'missilebarrel2', 'missilefirepoint2')

local SIG_AIM = {}
local SIG_AIM2 = {}
local SIG_AIM3 = {}
local SIG_AIM4 = {}
local SIG_AIM5 = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

common = include("headers/common_includes_lus.lua")


function script.Create()
	StartThread(common.SmokeUnit, {railturret1, railbarrel1, railfirepoint1, burstturret1, burstbarrel1, burstfirepoint1, burstturret2, burstbarrel2, burstfirepoint2, missileturret1, missilebarrel1, missilefirepoint1, missileturret2, missilebarrel2, missilefirepoint2})
end

function script.StartMoving()
	isMoving = true
	-- StartThread(thrust)
	common.WheelStartSpin6()
end

function script.StopMoving()
	isMoving = false
	common.WheelStopSpin6()
end

local function RestoreAfterDelay()
	Sleep(2000)
	Turn(railturret1, y_axis, 0, 1)
	Turn(burstturret1, y_axis, 0, 1)
	Turn(burstturret2, y_axis, 0, 1)
	Turn(missileturret1, y_axis, 0, 1)
	Turn(missileturret2, y_axis, 0, 1)
	Turn(railbarrel1, x_axis, 0, 1)
	Turn(burstbarrel1, x_axis, 0, 1)
	Turn(burstbarrel2, x_axis, 0, 1)
	Turn(missilebarrel1, x_axis, 0, 1)
	Turn(missilebarrel2, x_axis, 0, 1)
end		

function script.AimFromWeapon(WeaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return railturret1
end

function script.QueryWeapon(WeaponID)
	if WeaponID == 1 then
		return railfirepoint1
	elseif WeaponID == 2 then
		return burstfirepoint1
	elseif WeaponID == 3 then
		return burstfirepoint2
	elseif WeaponID == 4 then
		return missilefirepoint1
	elseif WeaponID == 5 then
		return missilefirepoint2
	end
end

function script.FireWeapon(WeaponID)
	if WeaponID == 1 then
		EmitSfx (railfirepoint1, 1024)
	end
end

function script.AimWeapon(WeaponID, heading, pitch)
	-- Spring.SetUnitWeaponState(unitID, WeaponID, {reaimTime = 5}) -- Only use this if the turret is glitchy

	Turn(railturret1, y_axis, heading, 2)
	Turn(burstturret1, y_axis, heading, 2)
	Turn(burstturret2, y_axis, heading, 2)
	Turn(missileturret1, y_axis, heading, 2)
	Turn(missileturret2, y_axis, heading, 2)

	WaitForTurn(railturret1, y_axis)
	WaitForTurn(burstturret1, y_axis)
	WaitForTurn(burstturret2, y_axis)
	WaitForTurn(missileturret1, y_axis)
	WaitForTurn(missileturret2, y_axis)

	if WeaponID == 1 then
		Signal(SIG_AIM)
		SetSignalMask(SIG_AIM)
		Turn(railbarrel1, x_axis, -pitch, 10)
		WaitForTurn(railbarrel1, x_axis)
		--Spring.Echo("AimWeapon: FireWeapon")
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 2 then
		Signal(SIG_AIM2)
		SetSignalMask(SIG_AIM2)
		Turn(burstbarrel1, x_axis, -pitch, 10)
		WaitForTurn(burstbarrel1, x_axis)
		--Spring.Echo("AimWeapon: FireWeapon")
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 3 then
		Signal(SIG_AIM3)
		SetSignalMask(SIG_AIM3)
		Turn(burstbarrel2, x_axis, -pitch, 10)
		WaitForTurn(burstbarrel2, x_axis)
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 4 then
		Signal(SIG_AIM4)
		SetSignalMask(SIG_AIM4)
		Turn(missilebarrel1, x_axis, -pitch, 10)
		WaitForTurn(missilebarrel1, x_axis)
		--Spring.Echo("AimWeapon: FireWeapon")
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 5 then
		Signal(SIG_AIM5)
		SetSignalMask(SIG_AIM5)
		Turn(missilebarrel2, x_axis, -pitch, 10)
		WaitForTurn(missilebarrel2, x_axis)
		StartThread(RestoreAfterDelay)
		return true
	end
end

function script.Killed()
		Explode(railturret1, SFX.EXPLODE_ON_HIT)
		Explode(railbarrel1, SFX.EXPLODE_ON_HIT)
		Explode(burstbarrel1, SFX.EXPLODE_ON_HIT)
		Explode(burstbarrel2, SFX.EXPLODE_ON_HIT)
		Explode(missilebarrel1, SFX.EXPLODE_ON_HIT)
		Explode(missilebarrel2, SFX.EXPLODE_ON_HIT)
		Explode(wheels1, SFX.EXPLODE_ON_HIT)
		Explode(wheels2, SFX.EXPLODE_ON_HIT)
		Explode(wheels3, SFX.EXPLODE_ON_HIT)
		Explode(wheels4, SFX.EXPLODE_ON_HIT)
		Explode(wheels5, SFX.EXPLODE_ON_HIT)
		Explode(wheels6, SFX.EXPLODE_ON_HIT)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end