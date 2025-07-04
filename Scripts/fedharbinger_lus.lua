-- piece definitions
base,
cannonturret1, cannonbarrel1, cannonbarrel1firepoint1, cannonbarrel1firepoint2,
cannonturret2, cannonbarrel2, cannonbarrel2firepoint1, cannonbarrel2firepoint2,
cannonturret3, cannonbarrel3, cannonbarrel3firepoint1, cannonbarrel3firepoint2,
cannonturret4, cannonbarrel4, cannonbarrel4firepoint1, cannonbarrel4firepoint2,
vlaunchturret1, vlaunchturret1firepoint1,
vlaunchturret2, vlaunchturret2firepoint2,
mainturretbase, mainturret, mainbarrel, mainfirepoint1,
gatlingturret1, gatlingbarrel1, gatlingspins1, gatlingfirepoint1,
gatlingbarrel2, gatlingspins2, gatlingfirepoint2,
wake, wake1, wake2 = piece(
		'base',
		'cannonturret1', 'cannonbarrel1', 'cannonbarrel1firepoint1', 'cannonbarrel1firepoint2',
		'cannonturret2', 'cannonbarrel2', 'cannonbarrel2firepoint1', 'cannonbarrel2firepoint2',
		'cannonturret3', 'cannonbarrel3', 'cannonbarrel3firepoint1', 'cannonbarrel3firepoint2',
		'cannonturret4', 'cannonbarrel4', 'cannonbarrel4firepoint1', 'cannonbarrel4firepoint2',
		'vlaunchturret1', 'vlaunchturret1firepoint1',
		'vlaunchturret2', 'vlaunchturret2firepoint2',
		'mainturretbase', 'mainturret', 'mainbarrel', 'mainfirepoint1',
		'gatlingturret1', 'gatlingbarrel1', 'gatlingspins1', 'gatlingfirepoint1',
		'gatlingbarrel2', 'gatlingspins2', 'gatlingfirepoint2',
		'wake', 'wake1', 'wake2'
)

common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}
local SIG_AIM_2 = {}
local SIG_AIM_4 = {}
local SIG_AIM_8 = {}
local SIG_AIM_16 = {}
local SIG_AIM_32 = {}
local SIG_AIM_64 = {}

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
		common.CustomEmitter(wake1, "bubbles")
		common.CustomEmitter(wake2, "bubbles")
		Sleep(100)
	end
end

function script.Create()
	StartThread(common.SmokeUnit, {base,
	                               cannonturret1, cannonbarrel1, cannonbarrel1firepoint1, cannonbarrel1firepoint2,
	                               cannonturret2, cannonbarrel2, cannonbarrel2firepoint1, cannonbarrel2firepoint2,
	                               cannonturret3, cannonbarrel3, cannonbarrel3firepoint1, cannonbarrel3firepoint2,
	                               cannonturret4, cannonbarrel4, cannonbarrel4firepoint1, cannonbarrel4firepoint2,
	                               vlaunchturret1, vlaunchturret1firepoint1,
	                               vlaunchturret2, vlaunchturret2firepoint2,
	                               mainturretbase, mainturret, mainbarrel, mainfirepoint1,
	                               gatlingturret1, gatlingbarrel1, gatlingspins1, gatlingfirepoint1,
	                               gatlingbarrel2, gatlingspins2, gatlingfirepoint2,
	                               wake})
end


function RestoreAfterDelay()
	Sleep(5000)
	-- Reset Turret and Barrels
	Turn(mainturret, y_axis, 0, 1)
	Turn(mainbarrel, x_axis, 0, 1)

	Turn(cannonturret1, y_axis, 0, 1)
	Turn(cannonbarrel1, x_axis, 0, 1)

	Turn(cannonturret2, y_axis, 0, 1)
	Turn(cannonbarrel2, x_axis, 0, 1)

	Turn(cannonturret3, y_axis, 0, 1)
	Turn(cannonbarrel3, x_axis, 0, 1)

	Turn(cannonturret4, y_axis, 0, 1)
	Turn(cannonbarrel4, x_axis, 0, 1)

	Turn(gatlingturret1, y_axis, 0, 1)
	Turn(gatlingbarrel1, x_axis, 0, 1)
	Turn(gatlingbarrel2, x_axis, 0, 1)
end

local gun_1 = 1
local gun_2 = 1
local gun_3 = 1
local gun_4 = 1
local gun_5 = 1
local gun_6 = 1

local gunPieces1 = {
	{ firepoint = cannonbarrel1firepoint2 },
	{ firepoint = cannonbarrel1firepoint1 },
}
local gunPieces2 = {
	{ firepoint = cannonbarrel2firepoint2 },
	{ firepoint = cannonbarrel2firepoint1 },
}
local gunPieces3 = {
	{ firepoint = cannonbarrel3firepoint2 },
	{ firepoint = cannonbarrel3firepoint1 },
}
local gunPieces4 = {
	{ firepoint = cannonbarrel4firepoint2 },
	{ firepoint = cannonbarrel4firepoint1 },
}
local gunPieces5 = {
	{ firepoint = vlaunchturret2firepoint2 },
	{ firepoint = vlaunchturret1firepoint1 },
}
local gunPieces6 = {
	{ firepoint = gatlingfirepoint2 },
	{ firepoint = gatlingfirepoint1 },
}


function script.AimFromWeapon(WeaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return mainturret
end

function script.Shot(num)
	if num == 2 then
		gun_1 = gun_1 + 1
		if gun_1 > 2 then gun_1 = 1 end
		EmitSfx(gunPieces1[gun_1].firepoint, 1024)
	elseif num == 3 then
		gun_2 = gun_2 + 1
		if gun_2 > 2 then gun_2 = 1 end
		EmitSfx(gunPieces2[gun_2].firepoint, 1024)
	elseif num == 4 then
		gun_3 = gun_3 + 1
		if gun_3 > 2 then gun_3 = 1 end
		EmitSfx(gunPieces3[gun_3].firepoint, 1024)
	elseif num == 5 then
		gun_4 = gun_4 + 1
		if gun_4 > 2 then gun_4 = 1 end
		EmitSfx(gunPieces4[gun_4].firepoint, 1024)
	elseif num == 6 then
		gun_5 = gun_5 + 1
		if gun_5 > 2 then gun_5 = 1 end
		--EmitSfx(gunPieces5[gun_5].firepoint, 1024)
	elseif num == 7 then
		gun_6 = gun_6 + 1
		if gun_6 > 2 then gun_6 = 1 end
		EmitSfx(gunPieces6[gun_6].firepoint, 1024)
	end
end


function script.QueryWeapon(WeaponID)
	if WeaponID == 1 then
		return mainfirepoint1
	end
	if WeaponID == 2 then
		return gunPieces1[gun_1].firepoint
	end
	if WeaponID == 3 then
		return gunPieces2[gun_2].firepoint
	end
	if WeaponID == 4 then
		return gunPieces3[gun_3].firepoint
	end
	if WeaponID == 5 then
		return gunPieces4[gun_4].firepoint
	end
	if WeaponID == 6 then
		return gunPieces5[gun_5].firepoint
	end
	if WeaponID == 7 then
		return gunPieces6[gun_6].firepoint
	end
end

function script.FireWeapon(WeaponID)

end

function script.AimWeapon(WeaponID, heading, pitch)
	if WeaponID == 1 then
		Signal(SIG_AIM)
		SetSignalMask(SIG_AIM)
		Turn(mainturret, y_axis, heading, 10)
		Turn(mainbarrel, x_axis, -pitch, 10)
		WaitForTurn(mainturret, y_axis)
		WaitForTurn(mainbarrel, x_axis)
	end
	if WeaponID == 2 then
		Signal(SIG_AIM_2)
		SetSignalMask(SIG_AIM_2)
		Turn(cannonturret1, y_axis, heading, 10)
		Turn(cannonbarrel1, x_axis, -pitch, 10)
		WaitForTurn(cannonturret1, y_axis)
		WaitForTurn(cannonbarrel1, x_axis)
	end
	if WeaponID == 3 then
		Signal(SIG_AIM_4)
		SetSignalMask(SIG_AIM_4)
		Turn(cannonturret2, y_axis, heading, 10)
		Turn(cannonbarrel2, x_axis, -pitch, 10)
		WaitForTurn(cannonturret2, y_axis)
		WaitForTurn(cannonbarrel2, x_axis)
	end
	if WeaponID == 4 then
		Signal(SIG_AIM_8)
		SetSignalMask(SIG_AIM_8)
		Turn(cannonturret3, y_axis, heading, 10)
		Turn(cannonbarrel3, x_axis, -pitch, 10)
		WaitForTurn(cannonturret3, y_axis)
		WaitForTurn(cannonbarrel3, x_axis)
	end
	if WeaponID == 5 then
		Signal(SIG_AIM_16)
		SetSignalMask(SIG_AIM_16)
		Turn(cannonturret4, y_axis, heading, 10)
		Turn(cannonbarrel4, x_axis, -pitch, 10)
		WaitForTurn(cannonturret4, y_axis)
		WaitForTurn(cannonbarrel4, x_axis)
	end
	if WeaponID == 6 then
		Signal(SIG_AIM_32)
		SetSignalMask(SIG_AIM_32)
	end
	if WeaponID == 7 then
		Signal(SIG_AIM_64)
		SetSignalMask(SIG_AIM_64)
		Turn(gatlingturret1, y_axis, heading, 10)
		Turn(gatlingbarrel1, x_axis, -pitch, 10)
		Turn(gatlingbarrel2, x_axis, -pitch, 10)
		WaitForTurn(gatlingturret1, y_axis)
		WaitForTurn(gatlingbarrel1, x_axis)
		WaitForTurn(gatlingbarrel2, x_axis)

	end
	StartThread(RestoreAfterDelay)
	--Spring.Echo("AimWeapon: FireWeapon")
	return true
end

function script.Killed()

	Explode(cannonturret1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(cannonbarrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(cannonturret2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(cannonbarrel2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(cannonturret3, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(cannonbarrel3, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(cannonturret4, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(cannonbarrel4, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)

	Explode(mainturret, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(mainbarrel, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)

	Explode(vlaunchturret1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(vlaunchturret2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)

	Explode(gatlingturret1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(gatlingbarrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(gatlingbarrel2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end