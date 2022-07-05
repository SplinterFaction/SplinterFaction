pelvis, dirt, lthigh, rthigh, lleg, rleg, lfoot, rfoot, turret, gatlingbarrel1, gatlingbarrel2, gatlingfirepoint1, gatlingfirepoint2, gatlingspins1, gatlingspins2, cannonbarrel1, cannonbarrel2, cannonfirepoint1, cannonfirepoint2, rocketbarrel1, rocketbarrel2, rocketfirepoint1, rocketfirepoint2, missilebarrel1, missilebarrel2, missilefirepoint1, missilefirepoint2 = piece('pelvis', 'dirt', 'lthigh', 'rthigh', 'lleg', 'rleg', 'lfoot', 'rfoot', 'turret', 'gatlingbarrel1', 'gatlingbarrel2', 'gatlingfirepoint1', 'gatlingfirepoint2', 'gatlingspins1', 'gatlingspins2', 'cannonbarrel1', 'cannonbarrel2', 'cannonfirepoint1', 'cannonfirepoint2', 'rocketbarrel1', 'rocketbarrel2', 'rocketfirepoint1', 'rocketfirepoint2', 'missilebarrel1', 'missilebarrel2', 'missilefirepoint1', 'missilefirepoint2')

common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}
local SIG_AIM2 = {}
local SIG_AIM3 = {}
local SIG_AIM4 = {}
local SIG_AIM5 = {}
local SIG_AIM6 = {}
local SIG_AIM7 = {}
local SIG_AIM8 = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

-- Lessgooooo (Walk)
common.WalkScript()

function script.Create()
    StartThread(common.SmokeUnit, {pelvis, turret})
end

function thrust()
    common.DirtTrail()
end

function RestoreAfterDelay()
    Sleep(5000)
    -- Reset Turret and Barrels
    Turn(turret, y_axis, 0, 1)
    Turn(gatlingbarrel1, x_axis, 0, 1)
    Turn(gatlingbarrel2, x_axis, 0, 1)
    Turn(cannonbarrel1, x_axis, 0, 1)
    Turn(cannonbarrel2, x_axis, 0, 1)
    Turn(rocketbarrel1, x_axis, 0, 1)
    Turn(rocketbarrel2, x_axis, 0, 1)
    Turn(missilebarrel1, x_axis, 0, 1)
    Turn(missilebarrel2, x_axis, 0, 1)
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
    elseif WeaponID == 5 then
        return rocketfirepoint1
    elseif WeaponID == 6 then
        return rocketfirepoint2
    elseif WeaponID == 7 then
        return missilefirepoint1
    elseif WeaponID == 8 then
        return missilefirepoint2
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
    elseif WeaponID == 5 then
        EmitSfx (rocketfirepoint1, 1024)
    elseif WeaponID == 6 then
        EmitSfx (rocketfirepoint2, 1024)
    elseif WeaponID == 7 then
        EmitSfx (missilefirepoint1, 1024)
    elseif WeaponID == 8 then
        EmitSfx (missilefirepoint2, 1024)
    end
end

function script.AimWeapon(WeaponID, heading, pitch)
    Spring.SetUnitWeaponState(unitID, WeaponID, {reaimTime = 5})
    Turn(turret, y_axis, heading, 10)
    WaitForTurn(turret, y_axis)
    if WeaponID == 1 then
        Signal(SIG_AIM)
        SetSignalMask(SIG_AIM)

        Turn(gatlingbarrel1, x_axis, -pitch, 10)
        WaitForTurn(gatlingbarrel1, x_axis)
        StartThread(RestoreAfterDelay)
        --Spring.Echo("AimWeapon: FireWeapon")
        return true
    elseif WeaponID == 2 then
        Signal(SIG_AIM2)
        SetSignalMask(SIG_AIM2)

        Turn(gatlingbarrel2, x_axis, -pitch, 10)
        WaitForTurn(gatlingbarrel2, x_axis)
        StartThread(RestoreAfterDelay)
        --Spring.Echo("AimWeapon: FireWeapon")
        return true
    elseif WeaponID == 3 then
        Signal(SIG_AIM3)
        SetSignalMask(SIG_AIM3)

        Turn(cannonbarrel1, x_axis, -pitch, 10)
        WaitForTurn(cannonbarrel1, x_axis)
        return true
    elseif WeaponID == 4 then
        Signal(SIG_AIM4)
        SetSignalMask(SIG_AIM4)

        Turn(cannonbarrel2, x_axis, -pitch, 10)
        WaitForTurn(cannonbarrel2, x_axis)
        return true
    elseif WeaponID == 5 then
        Signal(SIG_AIM5)
        SetSignalMask(SIG_AIM5)

        Turn(rocketbarrel1, x_axis, -pitch, 10)
        WaitForTurn(rocketbarrel1, x_axis)
        return true
    elseif WeaponID == 6 then
        Signal(SIG_AIM6)
        SetSignalMask(SIG_AIM6)

        Turn(rocketbarrel2, x_axis, -pitch, 10)
        WaitForTurn(rocketbarrel2, x_axis)
        return true
    elseif WeaponID == 7 then
        Signal(SIG_AIM7)
        SetSignalMask(SIG_AIM7)

        Turn(missilebarrel1, x_axis, -pitch, 10)
        WaitForTurn(missilebarrel1, x_axis)
        return true
    elseif WeaponID == 8 then
        Signal(SIG_AIM8)
        SetSignalMask(SIG_AIM8)

        Turn(missilebarrel2, x_axis, -pitch, 10)
        WaitForTurn(missilebarrel2, x_axis)
        return true
    end
end

function script.Killed()
    Explode(gatlingbarrel1, SFX.EXPLODE_ON_HIT)
    Explode(cannonbarrel1, SFX.EXPLODE_ON_HIT)
    Explode(gatlingbarrel2, SFX.EXPLODE_ON_HIT)
    Explode(cannonbarrel2, SFX.EXPLODE_ON_HIT)
    Explode(missilebarrel1, SFX.EXPLODE_ON_HIT)
    Explode(missilebarrel2, SFX.EXPLODE_ON_HIT)
    Explode(rocketbarrel1, SFX.EXPLODE_ON_HIT)
    Explode(rocketbarrel2, SFX.EXPLODE_ON_HIT)
    Explode(turret, SFX.EXPLODE_ON_HIT)
    Explode(pelvis, SFX.EXPLODE_ON_HIT)
    Explode(rthigh, SFX.EXPLODE_ON_HIT)
    Explode(rleg, SFX.EXPLODE_ON_HIT)
    Explode(lthigh, SFX.EXPLODE_ON_HIT)
    Explode(lleg, SFX.EXPLODE_ON_HIT)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end