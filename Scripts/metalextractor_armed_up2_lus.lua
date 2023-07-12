
base, pivotpoint, armleft, armright, armrear, armfront, sfxpoint1, bottom1, topspin1, sfxpointt1, bottom2, topspin2, sfxpointt2, laserturret1, laserbarrel1, laserfirepoint11, laserfirepoint12, laserturret2, laserbarrel2, laserfirepoint21, laserfirepoint22, flameturret1, flamebarrel1, flamefirepoint1 = piece('base', 'pivotpoint', 'armleft', 'armright', 'armrear', 'armfront', 'sfxpoint1', 'bottom1', 'topspin1', 'sfxpointt1', 'bottom2', 'topspin2', 'sfxpointt2', 'laserturret1', 'laserbarrel1', 'laserfirepoint11', 'laserfirepoint12', 'laserturret2', 'laserbarrel2', 'laserfirepoint21', 'laserfirepoint22', 'flameturret1', 'flamebarrel1', 'flamefirepoint1')

common = include("headers/common_includes_lus.lua")

-- state variables
terrainType = "terrainType"
skyhateEffect = "mex-fireball-small-purple"

local SIG_AIM = {}
local SIG_AIM2 = {}
local SIG_AIM3 = {}
local SIG_AIM4 = {}

function script.Create()
	StartThread(common.SmokeUnit, {base, pivotpoint, armleft, armright, armrear, armfront, sfxpoint1, bottom1, topspin1, sfxpointt1, bottom2, topspin2, sfxpointt2, laserturret1, laserbarrel1, laserfirepoint11, laserfirepoint12, laserturret2, laserbarrel2, laserfirepoint21, laserfirepoint22, flameturret1, flamebarrel1, flamefirepoint1})

	StartThread(script.Skyhateceg)

	mexSpinSpeed = math.random(20,100)
	UnitScript.Spin(pivotpoint,y_axis,math.rad(mexSpinSpeed))

	UnitScript.Spin(topspin1,y_axis,math.rad(mexSpinSpeed * 0.25))
	UnitScript.Spin(topspin2,y_axis,math.rad(-mexSpinSpeed * 0.50))
end

function script.Skyhateceg()
	while true do
		common.CustomEmitter(sfxpoint1, skyhateEffect) -- Second argument is the piece name, third argument needs to be a string because it will be the name of the CEG effect used
		Sleep(500)
	end
end


local function RestoreAfterDelay()
	Sleep(2000)
	Turn(laserturret1, y_axis, 0, 5)
	Turn(laserbarrel1, x_axis, 0, 5)
	Turn(laserturret2, y_axis, 0, 5)
	Turn(laserbarrel2, x_axis, 0, 5)
	Turn(flameturret1, y_axis, 0, 5)
	Turn(flamebarrel1, x_axis, 0, 5)
end

function script.AimFromWeapon(weaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return laserturret1
end

local firepoints1 = {laserfirepoint11, laserfirepoint12}
local currentFirepoint1 = 1
local totalNumberofFirepoints1 = 2

local firepoints2 = {laserfirepoint21, laserfirepoint22}
local currentFirepoint2 = 1
local totalNumberofFirepoints2 = 2

function script.QueryWeapon(WeaponID)
	if WeaponID == 1 then
		return flamefirepoint1

	elseif WeaponID == 2 then
		-- Spring.Echo("[[Metal Extractor (ARMED)]] Current firepoint is " .. firepoints1[currentFirepoint1])
		return firepoints1[currentFirepoint1]
	elseif WeaponID == 3 then
		return firepoints2[currentFirepoint2]
	end
end

function script.FireWeapon(WeaponID)
	if WeaponID == 2 then
		currentFirepoint1 = currentFirepoint1 + 1
		if currentFirepoint1 == (totalNumberofFirepoints1 + 1) then -- when currentFirepoint gets to one more than the total number of firepoints, reset it to 1
			currentFirepoint1 = 1
		end
		-- Spring.Echo(currentFirepoint)
		-- EmitSfx (firepoints1[currentFirepoint1], 1024)
	elseif WeaponID == 3 then
		currentFirepoint2 = currentFirepoint2 + 1
		if currentFirepoint2 == (totalNumberofFirepoints2 + 1) then -- when currentFirepoint gets to one more than the total number of firepoints, reset it to 1
			currentFirepoint2 = 1
		end
	end
	-- EmitSfx (firepoints[currentFirepoint], 1024)
end

function script.AimWeapon(WeaponID, heading, pitch)
	if WeaponID == 1 then
		Signal(SIG_AIM)
		SetSignalMask(SIG_AIM)
		Turn(flameturret1, y_axis, heading, 10)
		Turn(flamebarrel1, x_axis, -pitch, 10)
		WaitForTurn(flameturret1, y_axis)
		WaitForTurn(flamebarrel1, x_axis)
		StartThread(RestoreAfterDelay)
		return true
	elseif WeaponID == 2 then
		Signal(SIG_AIM2)
		SetSignalMask(SIG_AIM2)
		Turn(laserturret1, y_axis, heading, 10)
		Turn(laserbarrel1, x_axis, -pitch, 10)
		WaitForTurn(laserturret1, y_axis)
		WaitForTurn(laserbarrel1, x_axis)
		StartThread(RestoreAfterDelay)
		--Spring.Echo("AimWeapon: FireWeapon")
		return true
	elseif WeaponID == 3 then
		Signal(SIG_AIM3)
		SetSignalMask(SIG_AIM3)
		Turn(laserturret2, y_axis, heading, 10)
		Turn(laserbarrel2, x_axis, -pitch, 10)
		WaitForTurn(laserturret2, y_axis)
		WaitForTurn(laserbarrel2, x_axis)
		StartThread(RestoreAfterDelay)
		return true
	end
end

function script.Killed()
	Explode(base, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(armleft, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(armright, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(armrear, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(armfront, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(topspin1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(topspin2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(bottom1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(bottom2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end