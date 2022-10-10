base, engine1, engine2, engine3, engine4 = piece('base', 'engine1', 'engine2', 'engine3', 'engine4')

common = include("headers/common_includes_lus.lua")

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

function script.Killed()
    Explode(base, SFX.EXPLODE_ON_HIT)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end