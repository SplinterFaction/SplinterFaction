pelvis,turret, nanoarm1, nanoarm2, nano1, nano2, nanopoint1, nanopoint2, dirt, lthigh, rthigh, lleg, rleg, lfoot, rfoot = piece('pelvis','turret', 'nanoarm1', 'nanoarm2', 'nano1', 'nano2', 'nanopoint1', 'nanopoint2', 'dirt', 'lthigh', 'rthigh', 'lleg', 'rleg', 'lfoot', 'rfoot')

common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}

local nanoPieces = {[0] = nanopoint1, [1] = nanopoint2}
local SIG_AIM = 2

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

-- Lessgooooo (Walk)
common.WalkScript()

function script.Create()
	StartThread(common.SmokeUnit, {pelvis,turret, nanoarm1, nanoarm2, nano1, nano2, nanopoint1, nanopoint2, dirt, lthigh, rthigh, lleg, rleg, lfoot, rfoot})
	StartThread(BuildFX)
	building = false
	Spring.SetUnitNanoPieces(unitID, nanoPieces)
end

function thrust()
	common.DirtTrail()
end

function BuildFX()
	while(building == true) do
		EmitSfx (nanopoint1, "nano-animated")
		EmitSfx (nanopoint2, "nano-animated")
		Sleep(425)
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
		Explode(nanos, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(turret, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(pelvis, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(nanoarm1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(nanoarm2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(nano1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		Explode(nano2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end