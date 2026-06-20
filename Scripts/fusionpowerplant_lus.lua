
base, sfxpoint1 = piece('base', 'sfxpoint1')

local deathPieces = {
	base, sfxpoint1,
}

common = include("headers/common_includes_lus.lua")

-- state variables
terrainType = "terrainType"
skyhateEffect = "powerplant-fireball-small-purple"

function script.Create()
	StartThread(common.SmokeUnit, {base, sfxpoint1})
	StartThread(script.Skyhateceg)


end

function script.Skyhateceg()
	while true do
		common.CustomEmitter(sfxpoint1, skyhateEffect) -- Second argument is the piece name, third argument needs to be a string because it will be the name of the CEG effect used
		Sleep(1000)
	end
end

function script.Killed()
	common.ExplodePieces(deathPieces)
	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end