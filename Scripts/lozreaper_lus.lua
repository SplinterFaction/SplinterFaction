base, wheels1, wheels2, wheels3, wheels4, laserturret1, laserturret2, railgunturret1, laserbarrel1, laserbarrel2, railgunbarrel1, laserfirepoint1, laserfirepoint2, railgunfirepoint1= piece('base', 'wheels1', 'wheels2', 'wheels3', 'wheels4', 'laserturret1', 'laserturret2', 'railgunturret1', 'laserbarrel1', 'laserbarrel2', 'railgunbarrel1', 'laserfirepoint1', 'laserfirepoint2', 'railgunfirepoint1')

local SIG_AIM = {}
local SIG_AIM2 = {}
local SIG_AIM3 = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
	StartThread(common.SmokeUnit, {base, wheels1, wheels2, wheels3, wheels4, laserturret1, laserturret2, railgunturret1, laserbarrel1, laserbarrel2, railgunbarrel1, laserfirepoint1, laserfirepoint2, railgunfirepoint1})
end

common = include("headers/common_includes_lus.lua")

function script.StartMoving()
   isMoving = true
	common.WheelStartSpin4()
end

function script.StopMoving()
   isMoving = false
	common.WheelStopSpin4()
end

local function RestoreAfterDelay()
	Sleep(2000)
	Turn(railgunturret1, y_axis, 0, 1)
	Turn(laserturret1, y_axis, 0, 1)
	Turn(laserturret2, y_axis, 0, 1)
	Turn(railgunbarrel1, x_axis, 0, 1)
	Turn(laserbarrel1, x_axis, 0, 1)
	Turn(laserbarrel2, x_axis, 0, 1)
end		

function script.AimFromWeapon(WeaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return railgunturret1
end

local firepoints = {laserfirepoint1, laserfirepoint2}
local currentFirepoint = 1

function script.QueryWeapon(WeaponID)
	if WeaponID == 1 then
		return railgunfirepoint1
	elseif WeaponID == 2 then
		return firepoints[currentFirepoint]
	end
end

function script.FireWeapon(WeaponID)
	if WeaponID == 1 then
		EmitSfx (railgunfirepoint1, 1024)
	elseif WeaponID == 2 then
		currentFirepoint = 3 - currentFirepoint
		EmitSfx (firepoints[currentFirepoint], 1024)
	end
end

function script.AimWeapon(WeaponID, heading, pitch)
	-- Spring.SetUnitWeaponState(unitID, WeaponID, {reaimTime = 5}) -- Only use this if the turret is glitchy

	Turn(railgunturret1, y_axis, heading, 5)
	Turn(laserturret1, y_axis, heading, 5)
	Turn(laserturret2, y_axis, heading, 5)

	WaitForTurn(railgunturret1, y_axis)
	WaitForTurn(laserturret1, y_axis)
	WaitForTurn(laserturret2, y_axis)

	if WeaponID == 1 then
		Signal(SIG_AIM)
		SetSignalMask(SIG_AIM)
		Turn(railgunbarrel1, x_axis, -pitch, 5)
		WaitForTurn(railgunbarrel1, x_axis)
		--Spring.Echo("AimWeapon: FireWeapon")
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 2 then
		Signal(SIG_AIM2)
		SetSignalMask(SIG_AIM2)
		Turn(laserbarrel1, x_axis, -pitch, 5)
		WaitForTurn(laserbarrel1, x_axis)
		Turn(laserbarrel2, x_axis, -pitch, 5)
		WaitForTurn(laserbarrel2, x_axis)
		--Spring.Echo("AimWeapon: FireWeapon")
		StartThread(RestoreAfterDelay)
		return true
	end
end

function script.Killed()
		Explode(railgunturret1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(railgunbarrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(laserbarrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(laserbarrel2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(wheels1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(wheels2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(wheels3, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(wheels4, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end