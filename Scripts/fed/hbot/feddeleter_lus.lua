
pelvis, dirt, lthigh, rthigh, lleg, rleg, lfoot, rfoot, turret, emitter1, emitterfirepoint1 = piece('pelvis', 'dirt', 'lthigh', 'rthigh', 'lleg', 'rleg', 'lfoot', 'rfoot', 'turret', 'emitter1', 'emitterfirepoint1')

common = include("headers/common_includes_lus.lua")

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

-- Lessgooooo (Walk)
common.WalkScript()

function script.Create()
    StartThread(common.SmokeUnit, {pelvis, dirt, lthigh, rthigh, lleg, rleg, lfoot, rfoot, turret, emitter1, emitterfirepoint1})
end

--function thrust()
--    common.DirtTrail()
--end

function script.AimFromWeapon(weaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return emitter1
end

function script.QueryWeapon(weaponID)
    --Spring.Echo("QueryWeapon: FireWeapon")
    return emitterfirepoint1
end

function script.AimWeapon(weaponID, heading, pitch)
    return true
end

function script.FireWeapon(weaponID)
end

function script.Killed()
    Explode(emitter1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(turret, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(pelvis, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(rthigh, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(rleg, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(lthigh, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(lleg, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end