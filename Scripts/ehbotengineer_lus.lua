base, turret, nanos, nanopoint1, nanopoint2, dirt, backpack, exhaust1, exhaust2 = piece('base', 'turret', 'nanos', 'nanopoint1', 'nanopoint2', 'dirt', 'backpack', 'exhaust1', 'exhaust2')
local SIG_AIM = {}

local nanoPieces = {[0] = nanopoint1, [1] = nanopoint2}
local SIG_AIM = 2

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
	StartThread(common.SmokeUnit, {base, turret, barrel1})
	StartThread(doYouEvenLift)
	StartThread(BuildFX)
	building = false
	Spring.SetUnitNanoPieces(unitID, nanoPieces)
end

common = include("headers/common_includes_lus.lua")

function script.StartMoving()
   isMoving = true
   	StartThread(thrust)
end

function script.StopMoving()
   isMoving = false
end   

function doYouEvenLift()
	common.HbotLift()
end

function thrust()
	common.DirtTrail()
end

function BuildFX()
	while(building == true) do
		EmitSfx (nanopoint1, 1024)
		EmitSfx (nanopoint2, 1024)
		Sleep(550)
	end
end

function RestoreAfterDelay()
	SetSignalMask(SIG_AIM)
	if building == false then
		Sleep(2000)
		Turn(base, y_axis, 0, 5)
	end
end		

function script.StopBuilding()
    SetUnitValue(COB.INBUILDSTANCE, 0)
	building = false
	StartThread(RestoreAfterDelay)
	Signal(SIG_AIM)
	SetSignalMask(SIG_AIM)
end

function script.StartBuilding(heading, pitch)
	Signal(SIG_AIM)
	Turn(base, y_axis, heading, 100)
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
		Explode(base, SFX.EXPLODE_ON_HIT)
		Explode(backpack, SFX.EXPLODE_ON_HIT)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end