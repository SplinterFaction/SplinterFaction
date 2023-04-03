
base, engine1, engine2, engine3, engine4, turretball1, gatlingspins1, gatlingfirepoint1, turretball2, gatlingspins2, gatlingfirepoint2 = piece ('base', 'engine1', 'engine2', 'engine3', 'engine4', 'turretball1', 'gatlingspins1', 'gatlingfirepoint1', 'turretball2', 'gatlingspins2', 'gatlingfirepoint2')

common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}
local SIG_AIM2 = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
    StartThread(common.SmokeUnit, {base, engine1, engine2, engine3, engine4, turretball1, gatlingspins1, gatlingfirepoint1, turretball2, gatlingspins2, gatlingfirepoint2})
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

local firepoints1 = {gatlingfirepoint1, gatlingfirepoint2}
local currentFirepoint1 = 1
local totalNumberofFirepoints1 = 2

function script.QueryWeapon(WeaponID)
    if WeaponID == 1 then
        return firepoints1[currentFirepoint1]
    end
end

function script.FireWeapon(WeaponID)
    if WeaponID == 1 then
        currentFirepoint1 = currentFirepoint1 + 1
        if currentFirepoint1 == (totalNumberofFirepoints1 + 1) then -- when currentFirepoint gets to one more than the total number of firepoints, reset it to 1
            currentFirepoint1 = 1
        end
        -- Spring.Echo(currentFirepoint)
        EmitSfx (firepoints1[currentFirepoint1], 1024)
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
    end
end


function script.Killed()
    Explode(base, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(turretball1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(turretball2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(gatlingspins1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(gatlingspins2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end