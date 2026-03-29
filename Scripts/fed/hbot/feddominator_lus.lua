pelvis, dirt, legs, rthigh, rleg, rfoot, lthigh, lleg, lfoot, turret, barrels1, firepoint1, firepoint2, barrels2, firepoint3, firepoint4 = piece('pelvis', 'dirt', 'legs', 'rthigh', 'rleg', 'rfoot', 'lthigh', 'lleg', 'lfoot', 'turret', 'barrels1', 'firepoint1', 'firepoint2', 'barrels2', 'firepoint3', 'firepoint4')

common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}
local SIG_AIM2 = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

-- Lessgooooo (Walk)
common.WalkScript()

function script.Create()
    StartThread(common.SmokeUnit, {pelvis, dirt, legs, rthigh, rleg, rfoot, lthigh, lleg, lfoot, turret, barrels1, firepoint1, firepoint2, barrels2, firepoint3, firepoint4})
end

function thrust()
    common.DirtTrail()
end

function RestoreAfterDelay()
    Sleep(2000)
    -- Reset Turret and Barrels
    Turn(turret, y_axis, 0, 1)
    Turn(barrels1, x_axis, 0, 1)
    Turn(barrels2, x_axis, 0, 1)
end

function script.AimFromWeapon(weaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return turret
end

local firepoints = {firepoint4, firepoint2, firepoint3, firepoint1}
local currentFirepoint = 1

function script.QueryWeapon(weaponID)
    return firepoints[currentFirepoint]
end

function script.FireWeapon(weaponID)
    currentFirepoint = currentFirepoint + 1
    if currentFirepoint >= 5 then
        currentFirepoint = 1
    end
    --Spring.Echo("Next firepoint is " .. firepoints[currentFirepoint])
end

function script.AimWeapon(weaponID, heading, pitch)
    Signal(SIG_AIM)
    SetSignalMask(SIG_AIM)
    Turn(turret, y_axis, heading, 10)
    Turn(barrels1, x_axis, -pitch, 10)
    Turn(barrels2, x_axis, -pitch, 10)
    WaitForTurn(turret, y_axis)
    WaitForTurn(barrels1, x_axis)
    WaitForTurn(barrels2, x_axis)
    StartThread(RestoreAfterDelay)
    --Spring.Echo("AimWeapon: FireWeapon")
    return true
end

function script.Killed()
    local pieces = {pelvis, dirt, legs, rthigh, rleg, rfoot, lthigh, lleg, lfoot, turret, barrels1, firepoint1, firepoint2, barrels2, firepoint3, firepoint4}
    for _, piece in ipairs(pieces) do
        Explode(piece, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    end
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end