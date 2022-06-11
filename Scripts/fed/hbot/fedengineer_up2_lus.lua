pelvis, turret, nanos, nanos2, nanopoint1, nanopoint2, nanopoint3, dirt, lthigh, rthigh, lleg, rleg, lfoot, rfoot = piece('pelvis', 'turret', 'nanos', 'nanos2', 'nanopoint1', 'nanopoint2', 'nanopoint3', 'dirt', 'lthigh', 'rthigh', 'lleg', 'rleg', 'lfoot', 'rfoot')

common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}

local nanoPieces = {[0] = nanopoint1, [1] = nanopoint2, [2] = nanopoint3}
local SIG_AIM = 2

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

-- Lessgooooo (Walk)
common.WalkScript()

function script.Create()
	StartThread(common.SmokeUnit, {pelvis, turret, barrel1})
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
		EmitSfx (nanopoint2, 1024)
		Sleep(325)
		EmitSfx (nanopoint3, 1024)
		Sleep(550)
	end
end

function RestoreAfterDelay()
	SetSignalMask(SIG_AIM)
	if building == false then
		Sleep(2000)
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

function script.Killed()
		Explode(nanos, SFX.EXPLODE_ON_HIT)
		Explode(turret, SFX.EXPLODE_ON_HIT)
		Explode(pelvis, SFX.EXPLODE_ON_HIT)
		Explode(nanos2, SFX.EXPLODE_ON_HIT)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end