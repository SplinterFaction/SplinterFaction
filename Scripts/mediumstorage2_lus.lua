
base, sfxpoint1, sfxpoint2, sfxpoint3, sfxpoint4 = piece('base', 'sfxpoint1', 'sfxpoint2', 'sfxpoint3', 'sfxpoint4')

common = include("headers/common_includes_lus.lua")

-- state variables
terrainType = "terrainType"
skyhateEffect = "supplydepot-fireball-large"

function script.Create()
	StartThread(common.SmokeUnit, {base, sfxpoint1, sfxpoint2, sfxpoint3, sfxpoint4})
	StartThread(script.Skyhateceg)


end

function script.Skyhateceg()
	while true do
		common.CustomEmitter(sfxpoint1, skyhateEffect) -- Second argument is the piece name, third argument needs to be a string because it will be the name of the CEG effect used
		common.CustomEmitter(sfxpoint2, skyhateEffect) -- Second argument is the piece name, third argument needs to be a string because it will be the name of the CEG effect used
		common.CustomEmitter(sfxpoint3, skyhateEffect) -- Second argument is the piece name, third argument needs to be a string because it will be the name of the CEG effect used
		common.CustomEmitter(sfxpoint4, skyhateEffect) -- Second argument is the piece name, third argument needs to be a string because it will be the name of the CEG effect used
		Sleep(1000)
	end
end

function script.Killed()
	Explode(base, SFX.EXPLODE_ON_HIT)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end