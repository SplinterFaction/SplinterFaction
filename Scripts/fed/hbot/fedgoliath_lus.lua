pelvis, dirt, lthigh, rthigh, lleg, rleg, lfoot, rfoot, turret, gatlingbarrel1, gatlingbarrel2, gatlingfirepoint1, gatlingfirepoint2, cannonturret1, cannonturret2, cannonbarrel1, cannonbarrel2, cannonfirepoint1, cannonfirepoint2 = piece('pelvis', 'dirt', 'lthigh', 'rthigh', 'lleg', 'rleg', 'lfoot', 'rfoot', 'turret', 'gatlingbarrel1', 'gatlingbarrel2', 'gatlingfirepoint1', 'gatlingfirepoint2', 'cannonturret1', 'cannonturret2', 'cannonbarrel1', 'cannonbarrel2', 'cannonfirepoint1', 'cannonfirepoint2')

common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}
local SIG_AIM2 = {}
local SIG_AIM3 = {}
local SIG_AIM4 = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

-- Lessgooooo (Walk)
common.WalkScript()

function script.Create()
    StartThread(common.SmokeUnit, {pelvis, dirt, lthigh, rthigh, lleg, rleg, lfoot, rfoot, turret, gatlingbarrel1, gatlingbarrel2, gatlingfirepoint1, gatlingfirepoint2, cannonturret1, cannonturret2, cannonbarrel1, cannonbarrel2, cannonfirepoint1, cannonfirepoint2})
end

function thrust()
    common.DirtTrail()
end

function RestoreAfterDelay()
    Sleep(2000)
    -- Reset Turret and Barrels
    Turn(cannonturret1, y_axis, 0, 1)
    Turn(cannonbarrel1, x_axis, 0, 1)
    Turn(cannonturret2, y_axis, 0, 1)
    Turn(cannonbarrel2, x_axis, 0, 1)
    Turn(gatlingbarrel1, x_axis, 0, 1)
    Turn(gatlingbarrel1, y_axis, 0, 1)
    Turn(gatlingbarrel2, x_axis, 0, 1)
    Turn(gatlingbarrel2, y_axis, 0, 1)

end

function script.AimFromWeapon(WeaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return turret
end

function script.QueryWeapon(WeaponID)
    if WeaponID == 1 then
        return gatlingfirepoint1
    elseif WeaponID == 2 then
        return gatlingfirepoint2
    elseif WeaponID == 3 then
        return cannonfirepoint1
    elseif WeaponID == 4 then
        return cannonfirepoint2
    end
end

function script.FireWeapon(WeaponID)
    if WeaponID == 1 then
        EmitSfx (gatlingfirepoint1, 1024)
    elseif WeaponID == 2 then
        EmitSfx (gatlingfirepoint2, 1024)
    elseif WeaponID == 3 then
        EmitSfx (cannonfirepoint1, 1024)
    elseif WeaponID == 4 then
        EmitSfx (cannonfirepoint2, 1024)
    end
end

function script.AimWeapon(WeaponID, heading, pitch)
    --Spring.SetUnitWeaponState(unitID, WeaponID, {reaimTime = 5})



    if WeaponID == 1 then
        Signal(SIG_AIM)
        SetSignalMask(SIG_AIM)
        Turn(gatlingbarrel1, y_axis, heading, 2)
        WaitForTurn(gatlingbarrel1, y_axis)
        Turn(gatlingbarrel1, x_axis, -pitch, 2)
        WaitForTurn(gatlingbarrel1, x_axis)

        --Spring.Echo("AimWeapon: FireWeapon")
        StartThread(RestoreAfterDelay)
        return true
    elseif WeaponID == 2 then
        Signal(SIG_AIM2)
        SetSignalMask(SIG_AIM2)
        Turn(gatlingbarrel2, y_axis, heading, 2)
        WaitForTurn(gatlingbarrel2, y_axis)
        Turn(gatlingbarrel2, x_axis, -pitch, 2)
        WaitForTurn(gatlingbarrel2, x_axis)
        --Spring.Echo("AimWeapon: FireWeapon")
        return true
    elseif WeaponID == 3 then
        Signal(SIG_AIM3)
        SetSignalMask(SIG_AIM3)
        Turn(cannonturret1, y_axis, heading, 2)
        WaitForTurn(cannonturret1, y_axis)
        Turn(cannonbarrel1, x_axis, -pitch, 2)
        WaitForTurn(cannonbarrel1, x_axis)
        return true
    elseif WeaponID == 4 then
        Signal(SIG_AIM4)
        SetSignalMask(SIG_AIM4)
        Turn(cannonturret2, y_axis, heading, 2)
        WaitForTurn(cannonturret2, y_axis)
        Turn(cannonbarrel2, x_axis, -pitch, 2)
        WaitForTurn(cannonbarrel2, x_axis)
        return true
    end
end

function script.Killed()
    Explode(gatlingbarrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(cannonbarrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(gatlingbarrel2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(cannonbarrel2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(turret, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(pelvis, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(rthigh, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(rleg, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(lthigh, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(lleg, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end