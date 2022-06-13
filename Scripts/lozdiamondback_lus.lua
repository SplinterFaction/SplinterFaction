base, rearwheels, frontwheels, dirt, turret, barrel1, firepoint1 = piece('base', 'rearwheels', 'frontwheels', 'dirt', 'turret', 'barrel1', 'firepoint1')
local SIG_AIM = {}

common = include("headers/common_includes_lus.lua")

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
    StartThread(common.SmokeUnit, {base, rearwheels, turret})
    building = false
end

function script.StartMoving()
    isMoving = true
    -- StartThread(thrust)
    common.WheelStartSpin()
end

function script.StopMoving()
    isMoving = false
    common.WheelStopSpin()
end

function thrust()
    common.DirtTrail()
end

local function RestoreAfterDelay()
    Sleep(2000)
    Turn(turret, y_axis, 0, 5)
    Turn(barrel1, x_axis, 0, 5)
end

function script.AimFromWeapon(weaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return turret
end

function script.QueryWeapon(weaponID)
    --Spring.Echo("QueryWeapon: FireWeapon")
    return firepoint1
end

function script.AimWeapon(weaponID, heading, pitch)
    Signal(SIG_AIM)
    SetSignalMask(SIG_AIM)
    Turn(turret, y_axis, heading, 100)
    Turn(barrel1, x_axis, -pitch, 100)
    WaitForTurn(turret, y_axis)
    WaitForTurn(barrel1, x_axis)
    StartThread(RestoreAfterDelay)
    --Spring.Echo("AimWeapon: FireWeapon")
    return true
end

function script.FireWeapon(weaponID)
    --Spring.Echo("FireWeapon: FireWeapon")
    EmitSfx (firepoint1, 1024)
end

function script.Killed()
    Explode(rearwheels, SFX.EXPLODE_ON_HIT)
    Explode(frontwheels, SFX.EXPLODE_ON_HIT)
    Explode(barrel1, SFX.EXPLODE_ON_HIT)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end