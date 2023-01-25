
base, pivotpoint, armleft, armright, armrear, armfront, sfxpoint1, ball, tech1ring, tech2ring, tech3ring, bottom1, topspin1, sfxpointt1, techball1= piece('base', 'pivotpoint', 'armleft', 'armright', 'armrear', 'armfront', 'sfxpoint1', 'ball', 'tech1ring', 'tech2ring', 'tech3ring', 'bottom1', 'topspin1', 'sfxpointt1', 'techball1')

common = include("headers/common_includes_lus.lua")

-- state variables
terrainType = "terrainType"
skyhateEffect = "skyhatelasert0"

function script.Create()
	StartThread(common.SmokeUnit, {base, pivotpoint, armleft, armright, armrear, armfront, sfxpoint1, ball, tech1ring, tech2ring, tech3ring, bottom1, topspin1, sfxpointt1, techball1})
	StartThread(common.techRingsSpin)
	StartThread(script.Skyhateceg)
	StartThread(script.Skyhateceg1)

	mexSpinSpeed = math.random(20,100)
	UnitScript.Spin(pivotpoint,y_axis,math.rad(mexSpinSpeed))

	UnitScript.Spin(topspin1,y_axis,math.rad(mexSpinSpeed * 0.25))

	UnitScript.Spin(techball1,y_axis,math.rad(75))
	UnitScript.Spin(techball1,x_axis,math.rad(20))
	UnitScript.Spin(techball1,z_axis,math.rad(35))


end

function script.Skyhateceg()
	while true do
		common.CustomEmitter(sfxpoint1, skyhateEffect) -- Second argument is the piece name, third argument needs to be a string because it will be the name of the CEG effect used
		Sleep(500)
	end
end

sleep1 = math.random(2000,4000)

function script.Skyhateceg1()
	while true do
		common.CustomEmitter(sfxpointt1, skyhateEffect)
		Sleep(sleep1)
	end
end

function script.Killed()
	Explode(base, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(ball, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(tech1ring, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(tech2ring, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(tech3ring, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(topspin1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(techball1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end