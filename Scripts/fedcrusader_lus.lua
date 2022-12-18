
base, gatlingbarrel1, gatlingspins1, gatlingfirepoint1, rocketturret1, rocketbarrel1, rocketfirepoint1 = piece ('base', 'gatlingbarrel1', 'gatlingspins1', 'gatlingfirepoint1', 'rocketturret1', 'rocketbarrel1', 'rocketfirepoint1')

local SIG_AIM = {}
local SIG_AIM2 = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
	StartThread(common.SmokeUnit, {base, gatlingbarrel1, gatlingspins1, gatlingfirepoint1, rocketturret1, rocketbarrel1, rocketfirepoint1})
end

common = include("headers/common_includes_lus.lua")

function script.StartMoving()
	isMoving = true
end

function script.StopMoving()
	isMoving = false
end

local function RestoreAfterDelay()
	Sleep(2000)
	Turn(rocketturret1, y_axis, 0, 1)
	Turn(gatlingbarrel1, y_axis, 0, 1)
	Turn(rocketbarrel1, x_axis, 0, 1)
	Turn(gatlingspins1, x_axis, 0, 1)
end

function script.AimFromWeapon(WeaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return gatlingbarrel1
end

function script.QueryWeapon(WeaponID)
	if WeaponID == 1 then
		return gatlingfirepoint1
	elseif WeaponID == 2 then
		return rocketfirepoint1
	end
end

function script.FireWeapon(WeaponID)
	if WeaponID == 1 then
		EmitSfx (gatlingfirepoint1, 1024)
	elseif WeaponID == 2 then
	end
end

function script.AimWeapon(WeaponID, heading, pitch)
	-- Spring.SetUnitWeaponState(unitID, WeaponID, {reaimTime = 5}) -- Only use this if the turret is glitchy

	Turn(rocketturret1, y_axis, heading, 10)
	Turn(gatlingbarrel1, y_axis, heading, 10)

	WaitForTurn(rocketturret1, y_axis)
	WaitForTurn(gatlingbarrel1, y_axis)

	if WeaponID == 1 then
		Signal(SIG_AIM)
		SetSignalMask(SIG_AIM)
		Turn(gatlingspins1, x_axis, -pitch, 10)
		WaitForTurn(gatlingspins1, x_axis)
		--Spring.Echo("AimWeapon: FireWeapon")
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 2 then
		Signal(SIG_AIM2)
		SetSignalMask(SIG_AIM2)
		Turn(rocketbarrel1, x_axis, -pitch, 10)
		WaitForTurn(rocketbarrel1, x_axis)
		--Spring.Echo("AimWeapon: FireWeapon")
		StartThread(RestoreAfterDelay)
		return true
	end
end

function script.Killed()
	Explode(base, SFX.EXPLODE_ON_HIT)
	Explode(rocketturret1, SFX.EXPLODE_ON_HIT)
	Explode(rocketbarrel1, SFX.EXPLODE_ON_HIT)
	Explode(gatlingbarrel1, SFX.EXPLODE_ON_HIT)
	Explode(gatlingspins1, SFX.EXPLODE_ON_HIT)
	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end