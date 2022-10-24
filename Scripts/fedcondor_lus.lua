
base, engine1, engine2, engine3, engine4, turretball1, gatlingspins1, gatlingfirepoint1, turretball2, gatlingspins2, gatlingfirepoint2, turretball3, gatlingspins3, gatlingfirepoint3, turretball4, gatlingspins4, gatlingfirepoint4, link = piece ('base', 'engine1', 'engine2', 'engine3', 'engine4', 'turretball1', 'gatlingspins1', 'gatlingfirepoint1', 'turretball2', 'gatlingspins2', 'gatlingfirepoint2', 'turretball3', 'gatlingspins3', 'gatlingfirepoint3', 'turretball4', 'gatlingspins4', 'gatlingfirepoint4', 'link')

common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}
local SIG_AIM2 = {}
local SIG_AIM3 = {}
local SIG_AIM4 = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
    StartThread(common.SmokeUnit, {base, engine1, engine2, engine3, engine4, turretball1, gatlingspins1, gatlingfirepoint1, turretball2, gatlingspins2, gatlingfirepoint2, turretball3, gatlingspins3, gatlingfirepoint3, turretball4, gatlingspins4, gatlingfirepoint4, link})
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
    Turn(turretball2, y_axis, 0, 1)
    Turn(turretball2, x_axis, 0, 1)
    Turn(turretball3, y_axis, 0, 1)
    Turn(turretball3, x_axis, 0, 1)
    Turn(turretball4, y_axis, 0, 1)
    Turn(turretball4, x_axis, 0, 1)
end

function script.AimFromWeapon(weaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return base
end

local firepoints = {gatlingfirepoint1, gatlingfirepoint2, gatlingfirepoint3, gatlingfirepoint4}
local currentFirepoint = 1

function script.QueryWeapon(weaponID)
    return firepoints[currentFirepoint]
end

function script.FireWeapon(weaponID)
    currentFirepoint = 5 - currentFirepoint
    EmitSfx (firepoints[currentFirepoint], 1024)
end

function script.AimWeapon(weaponID, heading, pitch)
    Signal(SIG_AIM)
    SetSignalMask(SIG_AIM)
    Turn(turretball1, y_axis, heading, 100)
    Turn(turretball2, y_axis, heading, 100)
    Turn(turretball3, y_axis, heading, 100)
    Turn(turretball4, y_axis, heading, 100)
    Turn(turretball1, x_axis, -pitch, 100)
    Turn(turretball2, x_axis, -pitch, 100)
    Turn(turretball3, x_axis, -pitch, 100)
    Turn(turretball4, x_axis, -pitch, 100)

    WaitForTurn(turretball1, y_axis)
    WaitForTurn(turretball2, y_axis)
    WaitForTurn(turretball3, y_axis)
    WaitForTurn(turretball4, y_axis)

    WaitForTurn(turretball1, x_axis)
    WaitForTurn(turretball2, x_axis)
    WaitForTurn(turretball3, x_axis)
    WaitForTurn(turretball4, x_axis)

    StartThread(RestoreAfterDelay)
    --Spring.Echo("AimWeapon: FireWeapon")
    return true
end

--[[
-- Old Weapons Block. Looks cool because each turret will often attack a different target, but makes for a lot of visual clutter
local function RestoreAfterDelay()
    Sleep(2000)
    Turn(turretball1, y_axis, 0, 1)
    Turn(turretball1, x_axis, 0, 1)
    Turn(turretball2, y_axis, 0, 1)
    Turn(turretball2, x_axis, 0, 1)
    Turn(turretball3, y_axis, 0, 1)
    Turn(turretball3, x_axis, 0, 1)
    Turn(turretball4, y_axis, 0, 1)
    Turn(turretball4, x_axis, 0, 1)
end

function script.AimFromWeapon(WeaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return base
end

function script.QueryWeapon(WeaponID)
    if WeaponID == 1 then
        return gatlingfirepoint1
    elseif WeaponID == 2 then
        return gatlingfirepoint2
    elseif WeaponID == 3 then
        return gatlingfirepoint3
    elseif WeaponID == 4 then
        return gatlingfirepoint4
    end
end

function script.FireWeapon(WeaponID)
    if WeaponID == 1 then
        EmitSfx (gatlingfirepoint1, 1024)
        -- Spring.Echo("1")
    elseif WeaponID == 2 then
        EmitSfx (gatlingfirepoint2, 1024)
        -- Spring.Echo("2")
    elseif WeaponID == 3 then
        EmitSfx (gatlingfirepoint3, 1024)
        -- Spring.Echo("3")
    elseif WeaponID == 4 then
        EmitSfx (gatlingfirepoint4, 1024)
        -- Spring.Echo("4")
    end
end

function script.AimWeapon(WeaponID, heading, pitch)
    -- Spring.SetUnitWeaponState(unitID, WeaponID, {reaimTime = 5}) -- Only use this if the turret is glitchy

    Turn(turretball1, y_axis, heading, 100)
    Turn(turretball2, y_axis, heading, 100)
    Turn(turretball3, y_axis, heading, 100)
    Turn(turretball4, y_axis, heading, 100)

    WaitForTurn(turretball1, y_axis)
    WaitForTurn(turretball2, y_axis)
    WaitForTurn(turretball3, y_axis)
    WaitForTurn(turretball4, y_axis)


    if WeaponID == 1 then
        Turn(turretball1, x_axis, -pitch, 100)
        WaitForTurn(turretball1, x_axis)
        --Spring.Echo("AimWeapon: FireWeapon")
        StartThread(RestoreAfterDelay)
        return true
    elseif WeaponID == 2 then
        Turn(turretball2, x_axis, -pitch, 100)
        WaitForTurn(turretball2, x_axis)
        return true
    elseif WeaponID == 3 then
        Turn(turretball3, x_axis, -pitch, 100)
        WaitForTurn(turretball3, x_axis)
        return true
    elseif WeaponID == 4 then
        Turn(turretball4, x_axis, -pitch, 100)
        WaitForTurn(turretball4, x_axis)
        return true
    end
end
]]--

local passenger
local transporter
function script.BeginTransport(passengerID)
    transporter = transporterID
    passenger = passengerID
    -- Spring.UnitAttach(transporterID, passengerID, link)
end

function script.EndTransport()
   -- Spring.UnitDetachFromAir(passenger)
end

function script.QueryTransport(passengerID)
    return link
end

function script.Killed()
    Explode(base, SFX.EXPLODE_ON_HIT)
    Explode(turretball1, SFX.EXPLODE_ON_HIT)
    Explode(turretball2, SFX.EXPLODE_ON_HIT)
    Explode(turretball3, SFX.EXPLODE_ON_HIT)
    Explode(turretball4, SFX.EXPLODE_ON_HIT)
    Explode(gatlingspins1, SFX.EXPLODE_ON_HIT)
    Explode(gatlingspins2, SFX.EXPLODE_ON_HIT)
    Explode(gatlingspins3, SFX.EXPLODE_ON_HIT)
    Explode(gatlingspins4, SFX.EXPLODE_ON_HIT)

    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end