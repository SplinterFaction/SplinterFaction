
base, phalanxturret1, phalanxbarrel1, phalanxfirepoint1, phalanxfirepoint2, phalanxfirepoint3, phalanxfirepoint4  = piece('base', 'phalanxturret1', 'phalanxbarrel1', 'phalanxfirepoint1', 'phalanxfirepoint2', 'phalanxfirepoint3', 'phalanxfirepoint4')

local SIG_AIM = {}

function script.Create()
    StartThread(common.SmokeUnit, {base, phalanxturret1, phalanxbarrel1, phalanxfirepoint1, phalanxfirepoint2, phalanxfirepoint3, phalanxfirepoint4})
end

common = include("headers/common_includes_lus.lua")

local function RestoreAfterDelay()
    Sleep(2000)
    Turn(phalanxturret1, y_axis, 0, 5)
    Turn(phalanxbarrel1, x_axis, 0, 5)
end

function script.AimFromWeapon(weaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return phalanxturret1
end

local firepoints = {phalanxfirepoint1, phalanxfirepoint2, phalanxfirepoint3, phalanxfirepoint4}
local currentFirepoint = 1

function script.QueryWeapon(weaponID)
    return firepoints[currentFirepoint]
end

function script.FireWeapon(weaponID)
    currentFirepoint = 5 - currentFirepoint
    EmitSfx (firepoints[currentFirepoint], 1024)
end

function script.AimWeapon(weaponID, heading, pitch)
    Signal(SIG_AIM)
    SetSignalMask(SIG_AIM)
    Turn(phalanxturret1, y_axis, heading, 10)
    Turn(phalanxbarrel1, x_axis, -pitch, 10)
    WaitForTurn(phalanxturret1, y_axis)
    WaitForTurn(phalanxbarrel1, x_axis)
    StartThread(RestoreAfterDelay)
    --Spring.Echo("AimWeapon: FireWeapon")
    return true
end

function script.Killed()
    Explode(phalanxturret1, SFX.EXPLODE_ON_HIT)
    Explode(phalanxbarrel1, SFX.EXPLODE_ON_HIT)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end