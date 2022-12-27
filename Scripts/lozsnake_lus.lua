base, firepoint1 = piece('base', 'firepoint1')

local SIG_AIM = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

common = include("headers/common_includes_lus.lua")

function script.Create()
	StartThread(common.SmokeUnit, {base, firepoint1})
end

function script.StartMoving()
	isMoving = true
	StartThread(script.Bubbles)
end

function script.StopMoving()
	isMoving = false
end

function script.Bubbles()
	while isMoving do
		common.CustomEmitter(base, "bubbles")
		Sleep(100)
	end
end

function script.AimFromWeapon(WeaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return base
end

function script.QueryWeapon(WeaponID)
	if WeaponID == 1 then
		return firepoint1
	end
end

function script.FireWeapon(WeaponID)

end

function script.AimWeapon(WeaponID, heading, pitch)
	-- Spring.SetUnitWeaponState(unitID, WeaponID, {reaimTime = 5}) -- Only use this if the turret is glitchy

	if WeaponID == 1 then
		Signal(SIG_AIM)
		SetSignalMask(SIG_AIM)
		--Spring.Echo("AimWeapon: FireWeapon")
		return true
	end
end

function script.Killed()
		Explode(base, SFX.EXPLODE_ON_HIT)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end