
base, cannonturret1, cannonbarrel1, cannonfirepoint1, cannonfirepoint2  = piece('base', 'cannonturret1', 'cannonbarrel1', 'cannonfirepoint1', 'cannonfirepoint2')

local SIG_AIM = {}

function script.Create()
    StartThread(common.SmokeUnit, {base, cannonturret1, cannonbarrel1, cannonfirepoint1, cannonfirepoint2})
end

common = include("headers/common_includes_lus.lua")

local function RestoreAfterDelay()
    Sleep(2000)
    Turn(cannonturret1, y_axis, 0, 5)
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
    Turn(cannonturret1, y_axis, heading, 10)
    Turn(cannonbarrel1, x_axis, -pitch, 10)
    WaitForTurn(cannonturret1, y_axis)
    WaitForTurn(cannonbarrel1, x_axis)
    StartThread(RestoreAfterDelay)
    --Spring.Echo("AimWeapon: FireWeapon")
    return true
end

function script.Killed()
    Explode(cannonturret1, SFX.EXPLODE_ON_HIT)
    Explode(cannonbarrel1, SFX.EXPLODE_ON_HIT)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end