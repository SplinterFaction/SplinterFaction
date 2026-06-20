
base, leg1, leg2, leg3, leg4, cannonturret1, cannonbarrel1, cannonfirepoint1, cannonfirepoint2 = piece('base', 'leg1', 'leg2', 'leg3', 'leg4', 'cannonturret1', 'cannonbarrel1', 'cannonfirepoint1', 'cannonfirepoint2')

local deathPieces = {
	base, leg1, leg2, leg3, leg4, cannonturret1, cannonbarrel1, cannonfirepoint1, cannonfirepoint2,
}

local SIG_AIM = {}

common = include("headers/common_includes_lus.lua")

function script.Create()
    StartThread(common.SmokeUnit, {base, leg1, leg2, leg3, leg4, cannonturret1, cannonbarrel1, cannonfirepoint1, cannonfirepoint2})
end

local function RestoreAfterDelay()
    Sleep(2000)
    Turn(cannonbarrel1, y_axis, 0, 5)
    Turn(cannonbarrel1, x_axis, 0, 5)
end

function script.AimFromWeapon(weaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return cannonturret1
end

local firepoints = {cannonfirepoint1, cannonfirepoint2}
local currentFirepoint = 1

function script.QueryWeapon(weaponID)
    return firepoints[currentFirepoint]
end

function script.FireWeapon(weaponID)
    currentFirepoint = 3 - currentFirepoint
    EmitSfx (firepoints[currentFirepoint], 1024)
end

function script.AimWeapon(weaponID, heading, pitch)
    Signal(SIG_AIM)
    SetSignalMask(SIG_AIM)
    Turn(cannonbarrel1, y_axis, heading, 2)
    Turn(cannonbarrel1, x_axis, -pitch, 2)
    WaitForTurn(cannonbarrel1, y_axis)
    WaitForTurn(cannonbarrel1, x_axis)
    StartThread(RestoreAfterDelay)
    --Spring.Echo("AimWeapon: FireWeapon")
    return true
end

function script.Killed()
	common.ExplodePieces(deathPieces)
	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end