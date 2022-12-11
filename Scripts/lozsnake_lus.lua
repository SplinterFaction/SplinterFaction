base, firepoint1 = piece('base', 'firepoint1')
local SIG_AIM = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

common = include("headers/common_includes_lus.lua")

function script.Create()
	StartThread(common.SmokeUnit, {base, firepoint1})
end



function script.AimFromWeapon(weaponID)
	Spring.Echo("AimFromWeapon")
	return firepoint1
end

function script.QueryWeapon(weaponID)
	Spring.Echo("QueryWeapon")
	return firepoint1
end

function script.AimWeapon(weaponID, heading, pitch)
	Signal(SIG_AIM)
	SetSignalMask(SIG_AIM)
	Spring.Echo("AimWeapon")
	return true
end

function script.FireWeapon(weaponID)
	Spring.Echo("FireWeapon")
	-- EmitSfx (firepoint1, 1024)
end

function script.Killed()
		Explode(base, SFX.EXPLODE_ON_HIT)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end