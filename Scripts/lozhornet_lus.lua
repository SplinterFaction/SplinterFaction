
base, engine1, engine2, engine3, engine4, turretball1, railgunbarrel1, railgunfirepoint1, turretball2, railgunbarrel2, railgunfirepoint2 = piece ('base', 'engine1', 'engine2', 'engine3', 'engine4', 'turretball1', 'railgunbarrel1', 'railgunfirepoint1', 'turretball2', 'railgunbarrel2', 'railgunfirepoint2')

common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}
local SIG_AIM2 = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
    StartThread(common.SmokeUnit, {base, engine1, engine2, engine3, engine4, turretball1, railgunbarrel1, railgunfirepoint1, turretball2, railgunbarrel2, railgunfirepoint2})
end

function script.StartMoving()
    isMoving = true
end

function script.StopMoving()
    isMoving = false
end


local function RestoreAfterDelay()
    Sleep(2000)
    Turn(turretball1, y_axis, 0, 1)
    Turn(turretball2, y_axis, 0, 1)
    Turn(turretball1, x_axis, 0, 1)
    Turn(turretball2, x_axis, 0, 1)
end

function script.AimFromWeapon(WeaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return base
end

function script.QueryWeapon(WeaponID)
    if WeaponID == 1 then
        return railgunfirepoint1
    elseif WeaponID == 2 then
        return railgunfirepoint2
    end
end

function script.FireWeapon(WeaponID)
    if WeaponID == 1 then
        EmitSfx (railgunfirepoint1, 1024)
    elseif WeaponID == 2 then
        EmitSfx (railgunfirepoint2, 1024)
    end
end

function script.AimWeapon(WeaponID, heading, pitch)
    -- Spring.SetUnitWeaponState(unitID, WeaponID, {reaimTime = 5}) -- Only use this if the turret is glitchy

    Turn(turretball1, y_axis, heading, 100)
    Turn(turretball2, y_axis, heading, 100)

    WaitForTurn(turretball1, y_axis)
    WaitForTurn(turretball2, y_axis)


    if WeaponID == 1 then
        Signal(SIG_AIM)
        SetSignalMask(SIG_AIM)
        Turn(turretball1, x_axis, -pitch, 100)
        WaitForTurn(turretball1, x_axis)
        --Spring.Echo("AimWeapon: FireWeapon")
        StartThread(RestoreAfterDelay)
        return true
    elseif WeaponID == 2 then
        Signal(SIG_AIM2)
        SetSignalMask(SIG_AIM2)
        Turn(turretball2, x_axis, -pitch, 100)
        WaitForTurn(turretball2, x_axis)
        --Spring.Echo("AimWeapon: FireWeapon")
        StartThread(RestoreAfterDelay)
        return true
    end
end


function script.Killed()
    Explode(base, SFX.EXPLODE_ON_HIT)
    Explode(turretball1, SFX.EXPLODE_ON_HIT)
    Explode(turretball2, SFX.EXPLODE_ON_HIT)
    Explode(railgunbarrel1, SFX.EXPLODE_ON_HIT)
    Explode(railgunbarrel2, SFX.EXPLODE_ON_HIT)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end