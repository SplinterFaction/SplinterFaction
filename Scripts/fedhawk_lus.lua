
base, engine1, engine2, engine3, engine4, turretball1, laserbarrel1, laserfirepoint1 = piece ('base', 'engine1', 'engine2', 'engine3', 'engine4', 'turretball1', 'laserbarrel1', 'laserfirepoint1')

common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}
local SIG_AIM2 = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
    StartThread(common.SmokeUnit, {base, engine1, engine2, engine3, engine4, turretball1, laserbarrel1, laserfirepoint1})
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
    Turn(turretball1, x_axis, 0, 1)
end

function script.AimFromWeapon(WeaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return base
end

function script.QueryWeapon(WeaponID)
    if WeaponID == 1 then
        return laserfirepoint1
    end
end

function script.FireWeapon(WeaponID)
    if WeaponID == 1 then
        EmitSfx (laserfirepoint1, 1024)
    end
end

function script.AimWeapon(WeaponID, heading, pitch)
    -- Spring.SetUnitWeaponState(unitID, WeaponID, {reaimTime = 5}) -- Only use this if the turret is glitchy

    Turn(turretball1, y_axis, heading, 100)

    WaitForTurn(turretball1, y_axis)


    if WeaponID == 1 then
        Signal(SIG_AIM)
        SetSignalMask(SIG_AIM)
        Turn(turretball1, x_axis, -pitch, 100)
        WaitForTurn(turretball1, x_axis)
        --Spring.Echo("AimWeapon: FireWeapon")
        StartThread(RestoreAfterDelay)
        return true
    end
end


function script.Killed()
    Explode(base, SFX.EXPLODE_ON_HIT)
    Explode(turretball1, SFX.EXPLODE_ON_HIT)
    Explode(turretball2, SFX.EXPLODE_ON_HIT)
    Explode(laserbarrel1, SFX.EXPLODE_ON_HIT)
    Explode(gatlingspins2, SFX.EXPLODE_ON_HIT)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end