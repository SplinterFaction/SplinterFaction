pelvis, dirt, lthigh, rthigh, lleg, rleg, lfoot, rfoot, turret, cannonbarrel, cannonfirepoint1, rocketbarrel, rocketfirepoint1 = piece('pelvis', 'dirt', 'lthigh', 'rthigh', 'lleg', 'rleg', 'lfoot', 'rfoot', 'turret', 'cannonbarrel', 'cannonfirepoint1', 'rocketbarrel', 'rocketfirepoint1')

common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}
local SIG_AIM2 = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

-- Lessgooooo (Walk)
common.WalkScript()

function script.Create()
    StartThread(common.SmokeUnit, {pelvis, lthigh, rthigh, lleg, rleg, lfoot, rfoot, turret, cannonbarrel, cannonfirepoint1, rocketbarrel, rocketfirepoint1})
end

function thrust()
    common.DirtTrail()
end

function RestoreAfterDelay()
    Sleep(2000)
    -- Reset Turret and Barrels
    Turn(turret, y_axis, 0, 1)
    Turn(cannonbarrel, x_axis, 0, 1)
    Turn(rocketbarrel, x_axis, 0, 1)
end

function script.AimFromWeapon(WeaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return turret
end

function script.QueryWeapon(WeaponID)
    if WeaponID == 1 then
        return cannonfirepoint1
    else
        return rocketfirepoint1
    end
end

function script.FireWeapon(WeaponID)
    if WeaponID == 1 then
        EmitSfx (cannonfirepoint1, 1024)
    else
        EmitSfx (rocketfirepoint1, 1024)
    end
end

function script.AimWeapon(WeaponID, heading, pitch)

    Turn(turret, y_axis, heading, 10)

    if WeaponID == 1 then
        Signal(SIG_AIM)
        SetSignalMask(SIG_AIM)
        WaitForTurn(turret, y_axis)
        Turn(cannonbarrel, x_axis, -pitch, 10)
        WaitForTurn(cannonbarrel, x_axis)
        StartThread(RestoreAfterDelay)
        --Spring.Echo("AimWeapon: FireWeapon")
        return true
    else
        WaitForTurn(turret, y_axis)

        Turn(rocketbarrel, x_axis, -pitch, 10)
        WaitForTurn(rocketbarrel, x_axis)
        return true
    end
end

function script.Killed()
    Explode(cannonbarrel, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(rocketbarrel, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(turret, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(pelvis, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(rthigh, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(rleg, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(lthigh, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(lleg, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end