
base, gatlingturret1, gatlingbarrel1, gatlingspins1, gatlingfirepoint1, gatlingbarrel2, gatlingspins2, gatlingfirepoint2 = piece('base', 'gatlingturret1', 'gatlingbarrel1', 'gatlingspins1', 'gatlingfirepoint1', 'gatlingbarrel2', 'gatlingspins2', 'gatlingfirepoint2')

local SIG_AIM = {}

function script.Create()
    StartThread(common.SmokeUnit, {base, gatlingturret1, gatlingbarrel1, gatlingspins1, gatlingfirepoint1, gatlingbarrel2, gatlingspins2, gatlingfirepoint2})
end

common = include("headers/common_includes_lus.lua")

local function RestoreAfterDelay()
    Sleep(2000)
    Turn(gatlingturret1, y_axis, 0, 1)
    Turn(gatlingbarrel1, x_axis, 0, 1)
    Turn(gatlingbarrel2, x_axis, 0, 1)
end

function script.AimFromWeapon(WeaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return gatlingturret1
end

local firepoints = {gatlingfirepoint1, gatlingfirepoint2}
local currentFirepoint = 1

function script.QueryWeapon(weaponID)
    return firepoints[currentFirepoint]
end

function script.FireWeapon(weaponID)
    currentFirepoint = 3 - currentFirepoint
    EmitSfx (firepoints[currentFirepoint], 1024)
end

function script.AimWeapon(WeaponID, heading, pitch)
    -- Spring.SetUnitWeaponState(unitID, WeaponID, {reaimTime = 5}) -- Only use this if the turret is glitchy
    Signal(SIG_AIM)
    SetSignalMask(SIG_AIM)
    Turn(gatlingturret1, y_axis, heading, 10)
    WaitForTurn(gatlingturret1, y_axis)
    Turn(gatlingbarrel1, x_axis, -pitch, 10)
    WaitForTurn(gatlingbarrel1, x_axis)
    Turn(gatlingbarrel2, x_axis, -pitch, 10)
    WaitForTurn(gatlingbarrel2, x_axis)
    StartThread(RestoreAfterDelay)
    return true
end

function script.Killed()
    Explode(gatlingturret1, SFX.EXPLODE_ON_HIT)
    Explode(gatlingbarrel1, SFX.EXPLODE_ON_HIT)
    Explode(gatlingbarrel2, SFX.EXPLODE_ON_HIT)
    Explode(gatlingspins1, SFX.EXPLODE_ON_HIT)
    Explode(gatlingspins2, SFX.EXPLODE_ON_HIT)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end