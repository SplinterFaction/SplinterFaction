
base, beams, firepoint1 = piece('base', 'beams', 'firepoint1')

local deathPieces = {
	base, beams, firepoint1
}

common = include("headers/common_includes_lus.lua")

-- state variables
terrainType = "terrainType"
isOn = false

function script.Create()
	StartThread(common.SmokeUnit, {base, beams, firepoint1})
	StartThread(script.Skyhateceg)
end

function script.Skyhateceg()
	while isOn do
		common.CustomEmitter(firepoint1, "powerplant-fireball-small-orange")
		Sleep(500)
	end
end

function script.Activate()
	isOn = true
	if not skyhateThread then
		skyhateThread = StartThread(script.Skyhateceg)
	end
end

function script.Deactivate()
	isOn = false
	if skyhateThread then
		KillThread(skyhateThread)
		skyhateThread = nil
	end
end


function script.Killed()
	common.ExplodePieces(deathPieces)
	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end