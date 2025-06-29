
base, railgunturret1, railgunbarrel1, railgunfirepoint1, laserbarrel1, laserfirepoint1, wake = piece ('base', 'railgunturret1', 'railgunbarrel1', 'railgunfirepoint1', 'laserbarrel1', 'laserfirepoint1', 'wake')

local SIG_AIM = {}
local SIG_AIM2 = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
	StartThread(common.SmokeUnit, {base, railgunturret1, railgunbarrel1, railgunfirepoint1, laserbarrel1, laserfirepoint1})
end

common = include("headers/common_includes_lus.lua")

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

local function RestoreAfterDelay()
	Sleep(2000)
	Turn(laserbarrel1, y_axis, 0, 1)
	Turn(railgunturret1, y_axis, 0, 1)
	Turn(laserbarrel1, x_axis, 0, 1)
	Turn(railgunbarrel1, x_axis, 0, 1)
end

function script.AimFromWeapon(WeaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return railgunturret1
end

function script.QueryWeapon(WeaponID)
	if WeaponID == 1 then
		return railgunfirepoint1
	elseif WeaponID == 2 then
		return laserfirepoint1
	end
end

function script.FireWeapon(WeaponID)
	if WeaponID == 1 then
		EmitSfx (railgunfirepoint1, 1024)
	elseif WeaponID == 2 then
	end
end

function script.AimWeapon(WeaponID, heading, pitch)
	-- Spring.SetUnitWeaponState(unitID, WeaponID, {reaimTime = 5}) -- Only use this if the turret is glitchy

	Turn(laserbarrel1, y_axis, heading, 10)
	Turn(railgunturret1, y_axis, heading, 10)

	WaitForTurn(laserbarrel1, y_axis)
	WaitForTurn(railgunturret1, y_axis)

	if WeaponID == 1 then
		Signal(SIG_AIM)
		SetSignalMask(SIG_AIM)
		Turn(railgunbarrel1, x_axis, -pitch, 10)
		WaitForTurn(railgunbarrel1, x_axis)
		--Spring.Echo("AimWeapon: FireWeapon")
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 2 then
		Signal(SIG_AIM2)
		SetSignalMask(SIG_AIM2)
		Turn(laserbarrel1, x_axis, -pitch, 10)
		WaitForTurn(laserbarrel1, x_axis)
		--Spring.Echo("AimWeapon: FireWeapon")
		StartThread(RestoreAfterDelay)
		return true
	end
end

function script.Killed()
	Explode(laserbarrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(railgunturret1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(railgunbarrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end