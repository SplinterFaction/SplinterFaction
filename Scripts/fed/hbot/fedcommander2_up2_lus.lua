pelvis, dirt, lthigh, lleg, lfoot, rthigh, rleg, rfoot, turret, barrel1, firepoint1, nanoarm1, nano1, nanopoint1, nanoarm2, nano2, nanopoint2, nano0, nanopoint0, nanoarm3, nano3, nanopoint3, nanoarm4, nano4, nanopoint4 = piece('pelvis', 'dirt', 'lthigh', 'lleg', 'lfoot', 'rthigh', 'rleg', 'rfoot', 'turret', 'barrel1', 'firepoint1', 'nanoarm1', 'nano1', 'nanopoint1', 'nanoarm2', 'nano2', 'nanopoint2', 'nano0', 'nanopoint0', 'nanoarm3', 'nano3', 'nanopoint3', 'nanoarm4', 'nano4', 'nanopoint4')


common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}

local nanoPieces = {[0] = nanopoint0, [1] = nanopoint1, [2] = nanopoint2}
local SIG_AIM = 2
local SIG_AIM_2 = 2

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

-- Lessgooooo (Walk)
common.WalkScript()

function script.Create()
	StartThread(common.SmokeUnit, {pelvis, dirt, lthigh, lleg, lfoot, rthigh, rleg, rfoot, turret, barrel1, firepoint1, nanoarm1, nano1, nanopoint1, nanoarm2, nano2, nanopoint2, nano0, nanopoint0, nanoarm3, nano3, nanopoint3, nanoarm4, nano4, nanopoint4})
	StartThread(BuildFX)
	building = false
	Spring.SetUnitNanoPieces(unitID, nanoPieces)

	Spring.UnitScript.Hide ( nanoarm3 )
	Spring.UnitScript.Hide ( nano3 )
	Spring.UnitScript.Hide ( nanoarm4 )
	Spring.UnitScript.Hide ( nano4 )
end

function thrust()
	common.DirtTrail()
end

function BuildFX()
	while(building == true) do
		EmitSfx (nanopoint0, "nano-animated")
		EmitSfx (nanopoint1, "nano-animated")
		EmitSfx (nanopoint2, "nano-animated")
		Sleep(425)
	end
end

function RestoreAfterDelay()
	SetSignalMask(SIG_AIM)
	if building == false then
		Sleep(5000)
		Turn(turret, y_axis, 0, 5)
	end
end		

local nanoPoints = {nano1}

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
	Turn(turret, y_axis, heading, 100)
    SetUnitValue(COB.INBUILDSTANCE, 1)
	building = true
	StartThread(BuildFX)
end

function script.QueryNanoPiece()
	local nano = nanoPieces[nanoNum]
	return nano
end

local function RestoreAfterDelay()
	Sleep(2000)
	Turn(turret, y_axis, 0, 5)
	Turn(barrel1, x_axis, 0, 5)
end

function script.AimFromWeapon(weaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return turret
end

function script.QueryWeapon(weaponID)
	return firepoint1
end

function script.FireWeapon(weaponID)
end

function script.AimWeapon(weaponID, heading, pitch)
	Signal(SIG_AIM_2)
	SetSignalMask(SIG_AIM_2)
	Turn(turret, y_axis, heading, 10)
	Turn(barrel1, x_axis, -pitch, 10)
	WaitForTurn(turret, y_axis)
	WaitForTurn(barrel1, x_axis)
	StartThread(RestoreAfterDelay)

	return true
end

function script.Killed()
	Explode(pelvis, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(dirt, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(lthigh, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(lleg, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(lfoot, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(rthigh, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(rleg, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(rfoot, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(turret, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(barrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(nano0, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(nanoarm1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(nano1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(nanoarm2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(nano2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(nanoarm3, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(nano3, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(nanoarm4, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(nano4, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end