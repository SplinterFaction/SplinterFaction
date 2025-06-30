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
wake = piece(
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
		'wake'
)

common = include("headers/common_includes_lus.lua")

-- Signals
local SIG = {}
for i = 1, 10 do SIG[i] = 2 ^ i end

-- Movement state
local isMoving = false

function script.StartMoving()
	isMoving = true
	Show(wake)
	StartThread(function()
		while isMoving do
			common.CustomEmitter(wake, "bubbles")
			Sleep(100)
		end
	end)
end

function script.StopMoving()
	isMoving = false
	Hide(wake)
end

function script.Create()
	Show(wake)
	local smokepieces = {
		base,
		cannonturret1, cannonbarrel1, cannonbarrel1firepoint1, cannonbarrel1firepoint2,
		cannonturret2, cannonbarrel2, cannonbarrel2firepoint1, cannonbarrel2firepoint2,
		cannonturret3, cannonbarrel3, cannonbarrel3firepoint1, cannonbarrel3firepoint2,
		cannonturret4, cannonbarrel4, cannonbarrel4firepoint1, cannonbarrel4firepoint2,
		vlaunchturret1, vlaunchturret1firepoint1,
		vlaunchturret2, vlaunchturret2firepoint2,
		mainturretbase, mainturret, mainbarrel, mainfirepoint1,
		gatlingturret1, gatlingbarrel1, gatlingspins1, gatlingfirepoint1,
		gatlingbarrel2, gatlingspins2, gatlingfirepoint2
	}
	StartThread(common.SmokeUnit, smokepieces)
end

function RestoreAfterDelay()
	Sleep(5000)
	for i = 1, 4 do
		Turn(_G["cannonturret"..i], y_axis, 0, 1)
		Turn(_G["cannonbarrel"..i], x_axis, 0, 1)
	end
	Turn(mainturret, y_axis, 0, 1)
	Turn(mainbarrel, x_axis, 0, 1)
end

function script.AimFromWeapon(id)
	return base
end

-- Firepoint indices for cannons, vlaunch, and gatling
local cannonFirepoints = {
	[1] = {cannonbarrel1firepoint1, cannonbarrel1firepoint2},
	[2] = {cannonbarrel2firepoint1, cannonbarrel2firepoint2},
	[3] = {cannonbarrel3firepoint1, cannonbarrel3firepoint2},
	[4] = {cannonbarrel4firepoint1, cannonbarrel4firepoint2}
}
local cannonIndex = {1,1,1,1}
local vlaunchIndex = 1
local gatlingIndex = 1

function script.QueryWeapon(id)
	if id >= 1 and id <= 4 then
		return cannonFirepoints[id][cannonIndex[id]]
	elseif id == 5 then
		return (vlaunchIndex == 1) and vlaunchturret1firepoint1 or vlaunchturret2firepoint2
	elseif id == 6 then
		return (gatlingIndex == 1) and gatlingfirepoint1 or gatlingfirepoint2
	elseif id == 7 then
		return mainfirepoint1
	end
end

function script.FireWeapon(id)
	if id >= 1 and id <= 4 then
		local idx = id
		cannonIndex[idx] = 3 - cannonIndex[idx]
		EmitSfx(cannonFirepoints[idx][cannonIndex[idx]], 1024)
	elseif id == 5 then
		vlaunchIndex = 3 - vlaunchIndex
		EmitSfx(script.QueryWeapon(id), 1024)
	elseif id == 6 then
		gatlingIndex = 3 - gatlingIndex
		Spin((gatlingIndex == 1) and gatlingspins1 or gatlingspins2, z_axis, 5)
		EmitSfx(script.QueryWeapon(id), 1024)
	elseif id == 7 then
		EmitSfx(mainfirepoint1, 1024)
	end
end

function script.AimWeapon(id, heading, pitch)
	local turret, barrel, sig = nil, nil, SIG[id]
	if id >= 1 and id <= 4 then
		turret = _G["cannonturret"..id]
		barrel = _G["cannonbarrel"..id]
	elseif id == 5 then
		turret, barrel = vlaunchturret1, vlaunchturret1
	elseif id == 6 then
		turret, barrel = gatlingturret1, gatlingbarrel1
	elseif id == 7 then
		turret, barrel = mainturret, mainbarrel
	end

	if turret then
		Signal(sig)
		SetSignalMask(sig)
		Turn(turret, y_axis, heading, 10)
		if barrel then Turn(barrel, x_axis, -pitch, 10) end
		WaitForTurn(turret, y_axis)
		if barrel then WaitForTurn(barrel, x_axis) end
		StartThread(RestoreAfterDelay)
		return true
	end
	return false
end

function script.Killed()
	for i = 1, 4 do
		Explode(_G["cannonturret"..i], SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(_G["cannonbarrel"..i], SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	end
	Explode(mainturret, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(mainbarrel, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(gatlingturret1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(gatlingspins1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(gatlingspins2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(vlaunchturret1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(vlaunchturret2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	return 1
end
