
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
end

function script.AimFromWeapon(WeaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return gatlingturret1
end

function script.QueryWeapon(WeaponID)
    if WeaponID == 1 then
        return gatlingfirepoint1
    elseif WeaponID == 2 then
        return gatlingfirepoint2
    end
end

function script.FireWeapon(WeaponID)
    if WeaponID == 1 then
        EmitSfx (gatlingfirepoint1, 1024)
    elseif WeaponID == 2 then
        EmitSfx (gatlingfirepoint2, 1024)
    end
end

function script.AimWeapon(WeaponID, heading, pitch)
    -- Spring.SetUnitWeaponState(unitID, WeaponID, {reaimTime = 5}) -- Only use this if the turret is glitchy

    Turn(gatlingturret1, y_axis, heading, 10)
    WaitForTurn(gatlingturret1, y_axis)

    if WeaponID == 1 then
        Signal(SIG_AIM)
        SetSignalMask(SIG_AIM)
        Turn(gatlingbarrel1, x_axis, -pitch, 10)
        WaitForTurn(gatlingbarrel1, x_axis)
        --Spring.Echo("AimWeapon: FireWeapon")
        StartThread(RestoreAfterDelay)
        return true
    elseif WeaponID == 2 then
        Turn(gatlingbarrel2, x_axis, -pitch, 10)
        WaitForTurn(gatlingbarrel2, x_axis)
        --Spring.Echo("AimWeapon: FireWeapon")
        return true
    end
end

function script.Killed()
    Explode(gatlingturret1, SFX.EXPLODE_ON_HIT)
    Explode(gatlingbarrel1, SFX.EXPLODE_ON_HIT)
    Explode(gatlingbarrel2, SFX.EXPLODE_ON_HIT)
    Explode(gatlingspins1, SFX.EXPLODE_ON_HIT)
    Explode(gatlingspins2, SFX.EXPLODE_ON_HIT)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end