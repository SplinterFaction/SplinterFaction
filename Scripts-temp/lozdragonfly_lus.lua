
base, engine1, engine2, engine3, engine4, engine5, engine6, engine7, engine8, link = piece ('base', 'engine1', 'engine2', 'engine3', 'engine4', 'engine5', 'engine6', 'engine7', 'engine8', 'link')

common = include("headers/common_includes_lus.lua")

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
    StartThread(common.SmokeUnit, {base, engine1, engine2, engine3, engine4, engine5, engine6, engine7, engine8, link})

--[[
    local engineRotate = 270
    Turn(engine1, x_axis, engineRotate, 100)
    Turn(engine2, x_axis, engineRotate, 100)
    Turn(engine3, x_axis, engineRotate, 100)
    Turn(engine4, x_axis, engineRotate, 100)
    Turn(engine5, x_axis, engineRotate, 100)
    Turn(engine6, x_axis, engineRotate, 100)
    Turn(engine7, x_axis, engineRotate, 100)
    Turn(engine8, x_axis, engineRotate, 100)
]]--
end

function script.StartMoving()
    isMoving = true
end

function script.StopMoving()
    isMoving = false
end

function script.BeginTransport(passengerID)
    local unitHeight = Spring.GetUnitHeight(passengerID)
    Move(link, y_axis, -unitHeight, 500)
end

function script.QueryTransport()
    return link
end

function script.EndTransport(passengerID)
    Move(link, y_axis, 0, 500)
end

function script.Killed()
    Explode(base, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end