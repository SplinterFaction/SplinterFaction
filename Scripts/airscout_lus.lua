base, engine1, engine2, engine3, engine4 = piece('base', 'engine1', 'engine2', 'engine3', 'engine4')

common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
    StartThread(common.SmokeUnit, {base, engine1, engine2, engine3, engine4})
end

function script.StartMoving()
    isMoving = true
end

function script.StopMoving()
    isMoving = false
end


-----------------
-- FAKE WEAPON -- Without this the unit will refuse to fly
-----------------

local function RestoreAfterDelay()
    Sleep(2000)
end

function script.AimFromWeapon(WeaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return base
end

function script.QueryWeapon(WeaponID)
    return base
end

function script.FireWeapon(WeaponID)
end

function script.AimWeapon(WeaponID, heading, pitch)
    -- Spring.SetUnitWeaponState(unitID, WeaponID, {reaimTime = 5}) -- Only use this if the turret is glitchy
    Signal(SIG_AIM)
    SetSignalMask(SIG_AIM)
    --Spring.Echo("AimWeapon: FireWeapon")
    StartThread(RestoreAfterDelay)
    return true
end



function script.Killed()
    Explode(base, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end