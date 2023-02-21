
base, rocketturret1, rocketbarrel1, rocketfirepoint1, rocketfirepoint2 = piece('base', 'rocketturret1', 'rocketbarrel1', 'rocketfirepoint1', 'rocketfirepoint2')

local SIG_AIM = {}

function script.Create()
    StartThread(common.SmokeUnit, {base, rocketturret1, rocketbarrel1, rocketfirepoint1, rocketfirepoint2})
end

common = include("headers/common_includes_lus.lua")

local function RestoreAfterDelay()
    Sleep(2000)
    Turn(rocketturret1, y_axis, 0, 5)
    Turn(rocketbarrel1, x_axis, 0, 5)
end

function script.AimFromWeapon(weaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return rocketturret1
end

local firepoints = {rocketfirepoint1, rocketfirepoint2}
local currentFirepoint = 1

function script.QueryWeapon(weaponID)
    return firepoints[currentFirepoint]
end

function script.FireWeapon(weaponID)
    currentFirepoint = 3 - currentFirepoint
   -- EmitSfx (firepoints[currentFirepoint], 1024)
end

function script.AimWeapon(weaponID, heading, pitch)
    Signal(SIG_AIM)
    SetSignalMask(SIG_AIM)
    Turn(rocketturret1, y_axis, heading, 10)
    Turn(rocketbarrel1, x_axis, -pitch, 10)
    WaitForTurn(rocketturret1, y_axis)
    WaitForTurn(rocketbarrel1, x_axis)
    StartThread(RestoreAfterDelay)
    --Spring.Echo("AimWeapon: FireWeapon")
    return true
end

function script.Killed()
    Explode(rocketturret1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(rocketbarrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end