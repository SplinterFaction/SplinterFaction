
base, pivotpoint, armleft, armright, armrear, armfront, sfxpoint1, ball, tech1ring, tech2ring, tech3ring, bottom1, topspin1, sfxpointt1, techball1, bottom2, topspin2, sfxpointt2, techball2, bottom3, topspin3, sfxpointt3, techball3, bottom4, topspin4, sfxpointt4, techball4 = piece('base', 'pivotpoint', 'armleft', 'armright', 'armrear', 'armfront', 'sfxpoint1', 'ball', 'tech1ring', 'tech2ring', 'tech3ring', 'bottom1', 'topspin1', 'sfxpointt1', 'techball1', 'bottom2', 'topspin2', 'sfxpointt2', 'techball2', 'bottom3', 'topspin3', 'sfxpointt3', 'techball3', 'bottom4', 'topspin4', 'sfxpointt4', 'techball4')

common = include("headers/common_includes_lus.lua")

-- state variables
terrainType = "terrainType"
skyhateEffect = "skyhatelasert3"

function script.Create()
	StartThread(common.SmokeUnit, {base, pivotpoint, armleft, armright, armrear, armfront, sfxpoint1, ball, tech1ring, tech2ring, tech3ring, bottom1, topspin1, sfxpointt1, techball1, bottom2, topspin2, sfxpointt2, techball2, bottom3, topspin3, sfxpointt3, techball3, bottom4, topspin4, sfxpointt4, techball4})
	StartThread(common.techRingsSpin)
	StartThread(script.Skyhateceg)
	StartThread(script.Skyhateceg1)
	StartThread(script.Skyhateceg2)
	StartThread(script.Skyhateceg3)
	StartThread(script.Skyhateceg4)

	mexSpinSpeed = math.random(20,100)
	UnitScript.Spin(pivotpoint,y_axis,math.rad(mexSpinSpeed))

	UnitScript.Spin(topspin1,y_axis,math.rad(mexSpinSpeed * 0.25))
	UnitScript.Spin(topspin2,y_axis,math.rad(-mexSpinSpeed * 0.50))
	UnitScript.Spin(topspin3,y_axis,math.rad(mexSpinSpeed * 0.75))
	UnitScript.Spin(topspin4,y_axis,math.rad(-mexSpinSpeed))

	UnitScript.Spin(techball1,y_axis,math.rad(75))
	UnitScript.Spin(techball1,x_axis,math.rad(20))
	UnitScript.Spin(techball1,z_axis,math.rad(35))

	UnitScript.Spin(techball2,y_axis,math.rad(75))
	UnitScript.Spin(techball2,x_axis,math.rad(20))
	UnitScript.Spin(techball2,z_axis,math.rad(35))

	UnitScript.Spin(techball3,y_axis,math.rad(75))
	UnitScript.Spin(techball3,x_axis,math.rad(20))
	UnitScript.Spin(techball3,z_axis,math.rad(35))

	UnitScript.Spin(techball4,y_axis,math.rad(75))
	UnitScript.Spin(techball4,x_axis,math.rad(20))
	UnitScript.Spin(techball4,z_axis,math.rad(35))


end

function script.Skyhateceg()
	while true do
		common.CustomEmitter(sfxpoint1, skyhateEffect) -- Second argument is the piece name, third argument needs to be a string because it will be the name of the CEG effect used
		Sleep(500)
	end
end

sleep1 = math.random(2000,4000)
sleep2 = math.random(2000,4000)
sleep3 = math.random(2000,4000)
sleep4 = math.random(2000,4000)

function script.Skyhateceg1()
	while true do
		common.CustomEmitter(sfxpointt1, skyhateEffect)
		Sleep(sleep1)
	end
end
function script.Skyhateceg2()
	while true do
		common.CustomEmitter(sfxpointt2, skyhateEffect)
		Sleep(sleep2)
	end
end
function script.Skyhateceg3()
	while true do
		common.CustomEmitter(sfxpointt3, skyhateEffect)
		Sleep(sleep3)
	end
end
function script.Skyhateceg4()
	while true do
		common.CustomEmitter(sfxpointt4, skyhateEffect)
		Sleep(sleep4)
	end
end

function script.Killed()
	Explode(base, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(ball, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(tech1ring, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(tech2ring, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(tech3ring, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(topspin1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(topspin2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(topspin3, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(topspin4, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(techball1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(techball2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(techball3, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(techball4, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end