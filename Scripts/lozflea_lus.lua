base, rearwheels, frontwheels, dirt, emitter, firepoint1 = piece('base', 'rearwheels', 'frontwheels', 'dirt', 'emitter', 'firepoint1')
local SIG_AIM = {}

common = include("headers/common_includes_lus.lua")

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
    StartThread(common.SmokeUnit, {base, rearwheels, emitter})
    Spring.UnitScript.Spin(emitter,y_axis,math.rad(5))
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

function script.Killed()
    Explode(rearwheels, SFX.EXPLODE_ON_HIT)
    Explode(frontwheels, SFX.EXPLODE_ON_HIT)
    Explode(emitter, SFX.EXPLODE_ON_HIT)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end