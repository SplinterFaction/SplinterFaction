
base, wheels1, wheels2, wheels3, wheels4, wheels5, laserturret, laserbarrel1, laserfirepoint1, flakturret, flakbarrel1, flakfirepoint1 = piece('base', 'wheels1', 'wheels2', 'wheels3', 'wheels4', 'wheels5', 'laserturret', 'laserbarrel1', 'laserfirepoint1', 'flakturret', 'flakbarrel1', 'flakfirepoint1')

local SIG_AIM = {}
local SIG_AIM2 = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
	StartThread(common.SmokeUnit, {base, wheels1, wheels2, wheels3, wheels4, wheels5, laserturret, laserbarrel1, laserfirepoint1, flakturret, flakbarrel1, flakfirepoint1})
end

common = include("headers/common_includes_lus.lua")

function script.StartMoving()
	isMoving = true
	-- StartThread(thrust)
	common.WheelStartSpin5()
end

function script.StopMoving()
	isMoving = false
	common.WheelStopSpin5()
end

local function RestoreAfterDelay()
	Sleep(2000)
	Turn(laserturret, y_axis, 0, 1)
	Turn(flakturret, y_axis, 0, 1)
	Turn(laserbarrel1, x_axis, 0, 1)
	Turn(flakbarrel1, x_axis, 0, 1)
end		

function script.AimFromWeapon(WeaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return base
end

function script.QueryWeapon(WeaponID)
	if WeaponID == 1 then
		return laserfirepoint1
	elseif WeaponID == 2 then
		return flakfirepoint1
	end
end

function script.FireWeapon(WeaponID)
	if WeaponID == 1 then
		-- EmitSfx (laserfirepoint1, 1024)
	elseif WeaponID == 2 then
		EmitSfx (flakfirepoint1, 1024)
	end
end

function script.AimWeapon(WeaponID, heading, pitch)
	-- Spring.SetUnitWeaponState(unitID, WeaponID, {reaimTime = 5}) -- Only use this if the turret is glitchy

	Turn(laserturret, y_axis, heading, 5)
	Turn(flakturret, y_axis, heading, 5)

	WaitForTurn(laserturret, y_axis)
	WaitForTurn(flakturret, y_axis)

	if WeaponID == 1 then
		Signal(SIG_AIM)
		SetSignalMask(SIG_AIM)
		Turn(laserbarrel1, x_axis, -pitch, 5)
		WaitForTurn(laserbarrel1, x_axis)
		--Spring.Echo("AimWeapon: FireWeapon")
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 2 then
		Signal(SIG_AIM2)
		SetSignalMask(SIG_AIM2)
		Turn(flakbarrel1, x_axis, -pitch, 5)
		WaitForTurn(flakbarrel1, x_axis)
		--Spring.Echo("AimWeapon: FireWeapon")
		StartThread(RestoreAfterDelay)
		return true
	end
end

function script.Killed()
		Explode(laserturret, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(laserbarrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(flakturret, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(flakbarrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(wheels1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(wheels2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(wheels3, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(wheels4, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(wheels5, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end