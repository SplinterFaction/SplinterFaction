base, wheels1, wheels2, wheels3, emitter1, emitter2 = piece('base', 'wheels1', 'wheels2', 'wheels3', 'emitter1', 'emitter2')

local deathPieces = {
	base, wheels1, wheels2, wheels3, emitter1, emitter2,
}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
	StartThread(common.SmokeUnit, {base, wheels1, wheels2, wheels3, emitter1, emitter2})
end

common = include("headers/common_includes_lus.lua")

function script.StartMoving()
   isMoving = true
	common.WheelStartSpin3()
end

function script.StopMoving()
   isMoving = false
	common.WheelStopSpin3()
end

function script.AimFromWeapon(weaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return emitter1
end

function script.QueryWeapon(weaponID)
	--Spring.Echo("QueryWeapon: FireWeapon")
	return emitter1
end

function script.AimWeapon(weaponID, heading, pitch)
	return true
end

function script.FireWeapon(weaponID)
end

function script.Killed()
	common.ExplodePieces(deathPieces)
	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end