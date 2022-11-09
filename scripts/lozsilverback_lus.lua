
base, wheels1, wheels2, wheels3, wheels4, dirt1, dirt2, heavyrailturret1, heavyrailbarrel1, heavyrailfirepoint1, railturret1, railbarrel1, railfirepoint1, railturret2, railbarrel2, railfirepoint2, flameturret1, flamebarrel1, flamefirepoint1, emitter, emitterfirepoint1 = piece('base', 'wheels1', 'wheels2', 'wheels3', 'wheels4', 'dirt1', 'dirt2', 'heavyrailturret1', 'heavyrailbarrel1', 'heavyrailfirepoint1', 'railturret1', 'railbarrel1', 'railfirepoint1', 'railturret2', 'railbarrel2', 'railfirepoint2', 'flameturret1', 'flamebarrel1', 'flamefirepoint1', 'emitter', 'emitterfirepoint1')

local SIG_AIM = {}
local SIG_AIM2 = {}
local SIG_AIM3 = {}
local SIG_AIM4 = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
	StartThread(common.SmokeUnit, {base, wheels1, wheels2, wheels3, wheels4, heavyrailturret1, heavyrailbarrel1, heavyrailfirepoint1, railturret1, railbarrel1, railfirepoint1, railturret2, railbarrel2, railfirepoint2, flameturret1, flamebarrel1, flamefirepoint1, emitter, emitterfirepoint1})
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
	Turn(flameturret1, y_axis, 0, 1)

	Turn(heavyrailbarrel1, x_axis, 0, 1)
	Turn(railbarrel1, x_axis, 0, 1)
	Turn(railbarrel2, x_axis, 0, 1)
	Turn(flamebarrel1, x_axis, 0, 1)


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
		return flamefirepoint1
	elseif WeaponID == 5 then
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
	end
end

function script.AimWeapon(WeaponID, heading, pitch)
	-- Spring.SetUnitWeaponState(unitID, WeaponID, {reaimTime = 5}) -- Only use this if the turret is glitchy

	Turn(heavyrailturret1, y_axis, heading, 2)
	Turn(railturret1, y_axis, heading, 2)
	Turn(railturret2, y_axis, heading, 2)
	Turn(flamebarrel1, y_axis, heading, 2)

	WaitForTurn(heavyrailturret1, y_axis)
	WaitForTurn(railturret1, y_axis)
	WaitForTurn(railturret2, y_axis)
	WaitForTurn(flamebarrel1, y_axis)

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
		Turn(flamebarrel1, x_axis, -pitch, 10)
		WaitForTurn(flamebarrel1, x_axis)
		--Spring.Echo("AimWeapon: FireWeapon")
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 5 then

	end
end

function script.Killed()
	Explode(heavyrailbarrel1, SFX.EXPLODE_ON_HIT)
	Explode(railbarrel1, SFX.EXPLODE_ON_HIT)
	Explode(railbarrel2, SFX.EXPLODE_ON_HIT)
	Explode(flameturret1, SFX.EXPLODE_ON_HIT)
	Explode(flamebarrel1, SFX.EXPLODE_ON_HIT)
	Explode(emitter, SFX.EXPLODE_ON_HIT)
	Explode(wheels1, SFX.EXPLODE_ON_HIT)
	Explode(wheels2, SFX.EXPLODE_ON_HIT)
	Explode(wheels3, SFX.EXPLODE_ON_HIT)
	Explode(wheels4, SFX.EXPLODE_ON_HIT)
	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end