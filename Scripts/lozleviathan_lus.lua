
base, lightningturret1, lightningbarrel1, lightningfirepoint1, lightningturret2, lightningbarrel2, lightningfirepoint2, laserturret1, laserbarrel1, laserfirepoint1, laserturret2, laserbarrel2, laserfirepoint2, laserturret3, laserbarrel3, laserfirepoint3, laserturret4, laserbarrel4, laserfirepoint4, fueltanks1, fueltanks2, wake1, wake2 = piece(
		'base', 'lightningturret1', 'lightningbarrel1', 'lightningfirepoint1', 'lightningturret2', 'lightningbarrel2', 'lightningfirepoint2',
		'laserturret1', 'laserbarrel1', 'laserfirepoint1', 'laserturret2', 'laserbarrel2', 'laserfirepoint2',
		'laserturret3', 'laserbarrel3', 'laserfirepoint3', 'laserturret4', 'laserbarrel4', 'laserfirepoint4',
		'fueltanks1', 'fueltanks2', 'wake1', 'wake2'
)

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
		common.CustomEmitter(wake1, "bubbles")
		common.CustomEmitter(wake2, "bubbles")
		Sleep(100)
	end
end

function script.Create()
	StartThread(common.SmokeUnit, {base, lightningturret1, lightningbarrel1, lightningfirepoint1, lightningturret2, lightningbarrel2, lightningfirepoint2, laserturret1, laserbarrel1, laserfirepoint1, laserturret2, laserbarrel2, laserfirepoint2, laserturret3, laserbarrel3, laserfirepoint3, laserturret4, laserbarrel4, laserfirepoint4, fueltanks1, fueltanks2})
end


function RestoreAfterDelay()
	Sleep(5000)
	-- Reset Turret and Barrels
	Turn(lightningturret1, y_axis, 0, 1)
	Turn(lightningbarrel1, x_axis, 0, 1)

	Turn(lightningturret2, y_axis, 0, 1)
	Turn(lightningbarrel2, x_axis, 0, 1)

	Turn(laserturret1, y_axis, 0, 1)
	Turn(laserbarrel1, x_axis, 0, 1)

	Turn(laserturret2, y_axis, 0, 1)
	Turn(laserbarrel2, x_axis, 0, 1)

	Turn(laserturret3, y_axis, 0, 1)
	Turn(laserbarrel3, x_axis, 0, 1)

	Turn(laserturret4, y_axis, 0, 1)
	Turn(laserbarrel4, x_axis, 0, 1)
end

function script.AimFromWeapon(WeaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return lightningturret1
end

function script.QueryWeapon(WeaponID)
	if WeaponID == 1 then
		return lightningfirepoint1
	elseif WeaponID == 2 then
		return lightningfirepoint2
	elseif WeaponID == 3 then
		return laserfirepoint1
	elseif WeaponID == 4 then
		return laserfirepoint2
	elseif WeaponID == 5 then
		return laserfirepoint3
	elseif WeaponID == 6 then
		return laserfirepoint4
	end
end

function script.FireWeapon(WeaponID)
	if WeaponID == 1 then
		EmitSfx (lightningturret1, 1024)
	elseif WeaponID == 2 then
		EmitSfx (lightningturret2, 1024)
	elseif WeaponID == 3 then
	elseif WeaponID == 4 then
	elseif WeaponID == 5 then
	elseif WeaponID == 6 then
	end
end

function script.AimWeapon(WeaponID, heading, pitch)
	if WeaponID == 1 then
		Signal(SIG_AIM)
		SetSignalMask(SIG_AIM)
		Turn(lightningturret1, y_axis, heading, 10)
		Turn(lightningbarrel1, x_axis, -pitch, 10)
		WaitForTurn(lightningturret1, y_axis)
		WaitForTurn(lightningbarrel1, x_axis)
		StartThread(RestoreAfterDelay)
		--Spring.Echo("AimWeapon: FireWeapon")
		return true
	elseif WeaponID == 2 then
		Signal(SIG_AIM2)
		SetSignalMask(SIG_AIM2)
		Turn(lightningturret2, y_axis, heading, 10)
		Turn(lightningbarrel2, x_axis, -pitch, 10)
		WaitForTurn(lightningturret2, y_axis)
		WaitForTurn(lightningbarrel2, x_axis)
		StartThread(RestoreAfterDelay)
		--Spring.Echo("AimWeapon: FireWeapon")
		return true
	elseif WeaponID == 3 then
		Signal(SIG_AIM3)
		SetSignalMask(SIG_AIM3)
		Turn(laserturret1, y_axis, heading, 10)
		Turn(laserbarrel1, x_axis, -pitch, 10)
		WaitForTurn(laserturret1, y_axis)
		WaitForTurn(laserbarrel1, x_axis)
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 4 then
		Signal(SIG_AIM4)
		SetSignalMask(SIG_AIM4)
		Turn(laserturret2, y_axis, heading, 10)
		Turn(laserbarrel2, x_axis, -pitch, 10)
		WaitForTurn(laserturret2, y_axis)
		WaitForTurn(laserbarrel2, x_axis)
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 5 then
		Signal(SIG_AIM5)
		SetSignalMask(SIG_AIM5)
		Turn(laserturret3, y_axis, heading, 10)
		Turn(laserbarrel3, x_axis, -pitch, 10)
		WaitForTurn(laserturret3, y_axis)
		WaitForTurn(laserbarrel3, x_axis)
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 6 then
		Signal(SIG_AIM6)
		SetSignalMask(SIG_AIM6)
		Turn(laserturret4, y_axis, heading, 10)
		Turn(laserbarrel4, x_axis, -pitch, 10)
		WaitForTurn(laserturret4, y_axis)
		WaitForTurn(laserbarrel4, x_axis)
		StartThread(RestoreAfterDelay)
		return true
	end
end

function script.Killed()
	Explode(lightningturret1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(lightningbarrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(lightningturret2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(lightningbarrel2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(laserturret1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(laserbarrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(laserturret2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(laserbarrel2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(laserturret3, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(laserbarrel3, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(laserturret4, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(laserbarrel4, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(fueltanks1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(fueltanks2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end