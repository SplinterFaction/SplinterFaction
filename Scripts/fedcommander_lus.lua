base, mandible, rr1, rr2, rrdirt, rf1, rf2, rfdirt, lf1, lf2, lfdirt, lr1, lr2, lrdirt, nanopoint1, firepoint1, turret2, barrel2, firepoint2 = piece('base', 'mandible', 'rr1', 'rr2', 'rrdirt', 'rf1', 'rf2', 'rfdirt', 'lf1', 'lf2', 'lfdirt', 'lr1', 'lr2', 'lrdirt', 'nanopoint1', 'firepoint1', 'turret2', 'barrel2', 'firepoint2')

common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}

local nanoPieces = {[0] = nanopoint1}
local SIG_AIM = 2

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

-- Lessgooooo (Walk)
common.WalkScript4Legged()

function script.Create()
	StartThread(common.SmokeUnit, {base, mandible, rr1, rr2, rrdirt, rf1, rf2, rfdirt, lf1, lf2, lfdirt, lr1, lr2, lrdirt, nanopoint1, firepoint1, turret2, barrel2, firepoint2})
	StartThread(BuildFX)
	building = false
	Spring.SetUnitNanoPieces(unitID, nanoPieces)
end

function thrust()
	common.DirtTrail()
end

function BuildFX()
	while(building == true) do
		EmitSfx (nanopoint1, 1024)
		Sleep(200)
	end
end

function RestoreAfterDelay()
	SetSignalMask(SIG_AIM)
	if building == false then
		Sleep(2000)

	end
end

local nanoPoints = {nanopoint1}

Spring.SetUnitNanoPieces(unitID, nanoPoints)

function script.StopBuilding()
	SetUnitValue(COB.INBUILDSTANCE, 0)
	building = false
	StartThread(RestoreAfterDelay)
	Signal(SIG_AIM)
	SetSignalMask(SIG_AIM)
end

function script.StartBuilding(heading, pitch)
	Signal(SIG_AIM)
	SetUnitValue(COB.INBUILDSTANCE, 1)
	building = true
	StartThread(BuildFX)
end

function script.QueryNanoPiece()
	local nano = nanoPieces[nanoNum]
	return nano
end

function script.AimFromWeapon(WeaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return turret2
end

function script.QueryWeapon(WeaponID)
	if WeaponID == 1 then
		return firepoint2
	end
end

function script.FireWeapon(WeaponID)
	if WeaponID == 1 then
		EmitSfx (firepoint2, 1024)
	end
end

function script.AimWeapon(WeaponID, heading, pitch)
	-- Spring.SetUnitWeaponState(unitID, WeaponID, {reaimTime = 5}) -- Only use this if the turret is glitchy
	Turn(turret2, y_axis, heading, 50)
	Turn(barrel2, x_axis, pitch, 50)
	WaitForTurn(turret2, y_axis)
	WaitForTurn(barrel2, x_axis)
	if WeaponID == 1 then
		Signal(SIG_AIM1)
		SetSignalMask(SIG_AIM1)
		--Spring.Echo("AimWeapon: FireWeapon")
		StartThread(RestoreAfterDelay)
		return true
	end
end

function script.Killed()
	Explode(base, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(turret2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(barrel2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(mandible, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end