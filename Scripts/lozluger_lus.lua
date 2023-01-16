base, rearwheels, frontwheels, tanks, turret, cannonbarrel1, cannonfirepoint1 = piece('base', 'rearwheels', 'frontwheels', 'tanks', 'turret', 'cannonbarrel1', 'cannonfirepoint1')
local SIG_AIM = {}

common = include("headers/common_includes_lus.lua")

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
    StartThread(common.SmokeUnit, {base, rearwheels, frontwheels, tanks, turret, cannonbarrel1, cannonfirepoint1})
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

local function RestoreAfterDelay()
    Sleep(2000)
    Turn(turret, y_axis, 0, 5)
    Turn(cannonbarrel1, x_axis, 0, 5)
end

function script.AimFromWeapon(weaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return turret
end

function script.QueryWeapon(weaponID)
    --Spring.Echo("QueryWeapon: FireWeapon")
    return cannonfirepoint1
end

function script.AimWeapon(weaponID, heading, pitch)
    Signal(SIG_AIM)
    SetSignalMask(SIG_AIM)
    Turn(turret, y_axis, heading, 5)
    Turn(cannonbarrel1, x_axis, -pitch, 5)
    WaitForTurn(turret, y_axis)
    WaitForTurn(cannonbarrel1, x_axis)
    StartThread(RestoreAfterDelay)
    --Spring.Echo("AimWeapon: FireWeapon")
    return true
end

function script.FireWeapon(weaponID)
    --Spring.Echo("FireWeapon: FireWeapon")
    EmitSfx (cannonfirepoint1, 1024)
end

function script.Killed()
    Explode(rearwheels, SFX.EXPLODE_ON_HIT)
    Explode(tanks, SFX.EXPLODE_ON_HIT)
    Explode(frontwheels, SFX.EXPLODE_ON_HIT)
    Explode(cannonbarrel1, SFX.EXPLODE_ON_HIT)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end