base, ball, topring, middlering, lilypad = piece('base', 'ball', 'topring', 'middlering', 'lilypad')
local SIG_AIM = {}

-- state variables
terrainType = "terrainType"

function script.Create()
	StartThread(common.SmokeUnit, {ball})
	StartThread(common.shieldBallSpin)
end

common = include("headers/common_includes_lus.lua")


function script.AimFromWeapon(weaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return ball
end

local firepoints = {ball}
local currentFirepoint = 1

function script.QueryWeapon(weaponID)
	return firepoints[currentFirepoint]
end

function script.FireWeapon(weaponID)
	EmitSfx (firepoints[currentFirepoint], 1024)
end

function script.AimWeapon(weaponID, heading, pitch)
	Signal(SIG_AIM)
	SetSignalMask(SIG_AIM)
	--Spring.Echo("AimWeapon: FireWeapon")
	return false
end

function script.Killed()
		Explode(base, SFX.EXPLODE_ON_HIT)
		Explode(ball, SFX.EXPLODE_ON_HIT)
		Explode(topring, SFX.EXPLODE_ON_HIT)
		Explode(middlering, SFX.EXPLODE_ON_HIT)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end