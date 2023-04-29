
base, engine1, engine2, bombbay, chinfirepoint, topfirepoint, bottomfirepoint, leftfirepoint, rightfirepoint, rearfirepoint = piece ('base', 'engine1', 'engine2', 'bombbay', 'chinfirepoint', 'topfirepoint', 'bottomfirepoint', 'leftfirepoint', 'rightfirepoint', 'rearfirepoint')

common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
    StartThread(common.SmokeUnit, {base, engine1, engine2, bombbay, chinfirepoint, topfirepoint, bottomfirepoint, leftfirepoint, rightfirepoint, rearfirepoint})
end

function script.StartMoving()
    isMoving = true
end

function script.StopMoving()
    isMoving = false
end

function script.AimFromWeapon(WeaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return base
end

function script.QueryWeapon(WeaponID)
    if WeaponID == 1 then
        return bombbay
    end
    if WeaponID == 2 then
        return chinfirepoint
    end
    if WeaponID == 3 then
        return topfirepoint
    end
    if WeaponID == 4 then
        return bottomfirepoint
    end
    if WeaponID == 5 then
        return leftfirepoint
    end
    if WeaponID == 6 then
        return rightfirepoint
    end
    if WeaponID == 7 then
        return rearfirepoint
    end
end

function script.FireWeapon(WeaponID)
    if WeaponID == 2 then
        EmitSfx (chinfirepoint, 'electricity')
    end
    if WeaponID == 3 then
        EmitSfx (topfirepoint, 'electricity')
    end
    if WeaponID == 4 then
        EmitSfx (bottomfirepoint, 'electricity')
    end
    if WeaponID == 5 then
        EmitSfx (leftfirepoint, 'electricity')
    end
    if WeaponID == 6 then
        EmitSfx (rightfirepoint, 'electricity')
    end
    if WeaponID == 7 then
        EmitSfx (rearfirepoint, 'electricity')
    end
end

function script.AimWeapon(WeaponID, heading, pitch)
    -- Spring.SetUnitWeaponState(unitID, WeaponID, {reaimTime = 5}) -- Only use this if the turret is glitchy
    Signal(SIG_AIM)
    SetSignalMask(SIG_AIM)
    --Spring.Echo("AimWeapon: FireWeapon")
    return true
end


function script.Killed()
    Explode(base, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end