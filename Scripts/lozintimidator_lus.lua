
base, cannonturret1, cannonbarrel1, cannonfirepoint1 = piece('base', 'cannonturret1', 'cannonbarrel1', 'cannonfirepoint1')

local SIG_AIM = {}

common = include("headers/common_includes_lus.lua")

function script.Create()
    StartThread(common.SmokeUnit, {base, cannonturret1, cannonbarrel1, cannonfirepoint1})
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

function script.QueryWeapon(weaponID)
    return cannonfirepoint1
end

function script.FireWeapon(weaponID)

    EmitSfx (cannonfirepoint1, 1024)
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
    Explode(cannonturret1, SFX.EXPLODE_ON_HIT)
    Explode(cannonbarrel1, SFX.EXPLODE_ON_HIT)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end