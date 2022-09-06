
base, wheels1, wheels2, wheels3, wheels4, dirt1, dirt2, heavyrailturret1, heavyrailbarrel1, heavyrailfirepoint1, railturret1, railbarrel1, railfirepoint1, railturret2, railbarrel2, railfirepoint2, gatlingbarrel1, gatlingspins1, gatlingfirepoint1, gatlingbarrel2, gatlingspins2, gatlingfirepoint2, emitter, emitterfirepoint1 = piece('base', 'wheels1', 'wheels2', 'wheels3', 'wheels4', 'dirt1', 'dirt2', 'heavyrailturret1', 'heavyrailbarrel1', 'heavyrailfirepoint1', 'railturret1', 'railbarrel1', 'railfirepoint1', 'railturret2', 'railbarrel2', 'railfirepoint2', 'gatlingbarrel1', 'gatlingspins1', 'gatlingfirepoint1', 'gatlingbarrel2', 'gatlingspins2', 'gatlingfirepoint2', 'emitter', 'emitterfirepoint1')

local SIG_AIM = {}
local SIG_AIM2 = {}
local SIG_AIM3 = {}
local SIG_AIM4 = {}
local SIG_AIM5 = {}
local SIG_AIM6 = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
	StartThread(common.SmokeUnit, {base, wheels1, wheels2, wheels3, wheels4, heavyrailturret1, heavyrailbarrel1, heavyrailfirepoint1, railturret1, railbarrel1, railfirepoint1, railturret2, railbarrel2, railfirepoint2, gatlingbarrel1, gatlingspins1, gatlingfirepoint1, gatlingbarrel2, gatlingspins2, gatlingfirepoint2, emitter, emitterfirepoint1})
end

common = include("headers/common_includes_lus.lua")

function script.StartMoving()
	isMoving = true
	-- StartThread(thrust)
	common.WheelStartSpin4()
end

function script.StopMoving()
	isMoving = false
	common.WheelStopSpin4()
end

local function RestoreAfterDelay()
	Sleep(2000)
	Turn(heavyrailturret1, y_axis, 0, 1)
	Turn(railturret1, y_axis, 0, 1)
	Turn(railturret2, y_axis, 0, 1)
	Turn(gatlingbarrel1, y_axis, 0, 1)
	Turn(gatlingbarrel2, y_axis, 0, 1)

	Turn(heavyrailbarrel1, x_axis, 0, 1)
	Turn(railbarrel1, x_axis, 0, 1)
	Turn(railbarrel2, x_axis, 0, 1)
	Turn(gatlingbarrel1, x_axis, 0, 1)
	Turn(gatlingbarrel2, x_axis, 0, 1)

end		

function script.AimFromWeapon(WeaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return heavyrailturret1
end

function script.QueryWeapon(WeaponID)
	if WeaponID == 1 then
		return heavyrailfirepoint1
	elseif WeaponID == 2 then
		return railfirepoint1
	elseif WeaponID == 3 then
		return railfirepoint2
	elseif WeaponID == 4 then
		return gatlingfirepoint1
	elseif WeaponID == 5 then
		return gatlingfirepoint2
	elseif WeaponID == 6 then
		return emitterfirepoint1
	end
end

function script.FireWeapon(WeaponID)
	if WeaponID == 1 then
		EmitSfx (heavyrailfirepoint1, 1024)
	elseif WeaponID == 2 then
		EmitSfx (railfirepoint1, 1024)
	elseif WeaponID == 3 then
		EmitSfx (railfirepoint2, 1024)
	elseif WeaponID == 4 then
		EmitSfx (gatlingfirepoint1, 1024)
	elseif WeaponID == 5 then
		EmitSfx (gatlingfirepoint2, 1024)
	end
end

function script.AimWeapon(WeaponID, heading, pitch)
	-- Spring.SetUnitWeaponState(unitID, WeaponID, {reaimTime = 5}) -- Only use this if the turret is glitchy

	Turn(heavyrailturret1, y_axis, heading, 10)
	Turn(railturret1, y_axis, heading, 10)
	Turn(railturret2, y_axis, heading, 10)
	Turn(gatlingbarrel1, y_axis, heading, 10)
	Turn(gatlingbarrel2, y_axis, heading, 10)

	WaitForTurn(heavyrailturret1, y_axis)
	WaitForTurn(railturret1, y_axis)
	WaitForTurn(railturret2, y_axis)
	WaitForTurn(gatlingbarrel1, y_axis)
	WaitForTurn(gatlingbarrel2, y_axis)

	if WeaponID == 1 then
		Signal(SIG_AIM)
		SetSignalMask(SIG_AIM)
		Turn(heavyrailbarrel1, x_axis, -pitch, 10)
		WaitForTurn(heavyrailbarrel1, x_axis)
		--Spring.Echo("AimWeapon: FireWeapon")
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 2 then
		Signal(SIG_AIM2)
		SetSignalMask(SIG_AIM2)
		Turn(railbarrel1, x_axis, -pitch, 10)
		WaitForTurn(railbarrel1, x_axis)
		--Spring.Echo("AimWeapon: FireWeapon")
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 3 then
		Signal(SIG_AIM3)
		SetSignalMask(SIG_AIM3)
		Turn(railbarrel2, x_axis, -pitch, 10)
		WaitForTurn(railbarrel2, x_axis)
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 4 then
		Signal(SIG_AIM4)
		SetSignalMask(SIG_AIM4)
		Turn(gatlingbarrel1, x_axis, -pitch, 10)
		WaitForTurn(gatlingbarrel1, x_axis)
		--Spring.Echo("AimWeapon: FireWeapon")
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 5 then
		Signal(SIG_AIM5)
		SetSignalMask(SIG_AIM5)
		Turn(gatlingbarrel2, x_axis, -pitch, 10)
		WaitForTurn(gatlingbarrel2, x_axis)
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 6 then
		Signal(SIG_AIM6)
		SetSignalMask(SIG_AIM6)
	end
end

function script.Killed()
	Explode(heavyrailbarrel1, SFX.EXPLODE_ON_HIT)
	Explode(railbarrel1, SFX.EXPLODE_ON_HIT)
	Explode(railbarrel2, SFX.EXPLODE_ON_HIT)
	Explode(gatlingbarrel1, SFX.EXPLODE_ON_HIT)
	Explode(gatlingbarrel2, SFX.EXPLODE_ON_HIT)
	Explode(emitter, SFX.EXPLODE_ON_HIT)
	Explode(wheels1, SFX.EXPLODE_ON_HIT)
	Explode(wheels2, SFX.EXPLODE_ON_HIT)
	Explode(wheels3, SFX.EXPLODE_ON_HIT)
	Explode(wheels4, SFX.EXPLODE_ON_HIT)
	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end