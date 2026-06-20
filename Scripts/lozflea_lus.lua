base, rearwheels, frontwheels, dirt, emitter, firepoint1 = piece('base', 'rearwheels', 'frontwheels', 'dirt', 'emitter', 'firepoint1')

local deathPieces = {
	base, rearwheels, frontwheels, dirt, emitter, firepoint1,
}
local SIG_AIM = {}

common = include("headers/common_includes_lus.lua")

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
    StartThread(common.SmokeUnit, {base, rearwheels, frontwheels, emitter, firepoint1})
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
	common.ExplodePieces(deathPieces)
	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end