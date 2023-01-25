
base, cannonturret1, cannonbarrel1, cannonfirepoint1, cannonfirepoint2 = piece('base', 'cannonturret1', 'cannonbarrel1', 'cannonfirepoint1', 'cannonfirepoint2')

local SIG_AIM = {}

common = include("headers/common_includes_lus.lua")

function script.Create()
    StartThread(common.SmokeUnit, {base, cannonturret1, cannonbarrel1, cannonfirepoint1, cannonfirepoint2})
end

local function RestoreAfterDelay()
    Sleep(4000)
    Turn(cannonturret1, y_axis, 0, 0.25)
    Turn(cannonbarrel1, x_axis, 0, 0.25)
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
    Turn(cannonturret1, y_axis, heading, 0.25)
    Turn(cannonbarrel1, x_axis, -pitch, 0.25)
    WaitForTurn(cannonturret1, y_axis)
    WaitForTurn(cannonbarrel1, x_axis)
    StartThread(RestoreAfterDelay)
    --Spring.Echo("AimWeapon: FireWeapon")
    return true
end

function script.Killed()
    Explode(cannonturret1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(cannonbarrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end