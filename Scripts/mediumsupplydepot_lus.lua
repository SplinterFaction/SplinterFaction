base, sfxpoint1, ball, tech1ring, tech2ring, tech3ring = piece('base', 'sfxpoint1', 'ball', 'tech1ring', 'tech2ring', 'tech3ring')

common = include("headers/common_includes_lus.lua")

-- state variables
terrainType = "terrainType"
skyhateEffect = "skyhatelasert2"

function script.Create()
	StartThread(common.SmokeUnit, {base, sfxpoint1, ball, tech1ring, tech2ring, tech3ring})
	StartThread(script.Skyhateceg)

	StartThread(common.techRingsSpin)
end

function script.Skyhateceg()
	while true do
		common.CustomEmitter(sfxpoint1, skyhateEffect) -- Second argument is the piece name, third argument needs to be a string because it will be the name of the CEG effect used
		Sleep(500)
	end
end

function script.Killed()
	Explode(base, SFX.EXPLODE_ON_HIT)
	Explode(ball, SFX.EXPLODE_ON_HIT)
	Explode(tech1ring, SFX.EXPLODE_ON_HIT)
	Explode(tech2ring, SFX.EXPLODE_ON_HIT)
	Explode(tech3ring, SFX.EXPLODE_ON_HIT)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end