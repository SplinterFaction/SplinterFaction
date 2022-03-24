pelvis,turret, nanos, nanopoint1, nanopoint2, dirt, lthigh, rthigh, lleg, rleg, lfoot = piece('pelvis', 'turret', 'nanos', 'nanopoint1', 'nanopoint2', 'dirt', 'lthigh', 'rthigh', 'lleg', 'rleg', 'lfoot')

local SIG_AIM = {}

local nanoPieces = {[0] = nanopoint1, [1] = nanopoint2}
local SIG_AIM = 2

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
	StartThread(common.SmokeUnit, {pelvis, turret, barrel1})
	StartThread(BuildFX)
	StartThread(StopWalking)
	building = false
	Spring.SetUnitNanoPieces(unitID, nanoPieces)
end

common = include("headers/common_includes_lus.lua")


function walk()
	if (isMoving) then --Frame:8
		while(isMoving) do
			Turn(rthigh, x_axis, 5, 4 )
			Turn(rleg, x_axis, 2, 4)
			WaitForTurn(rleg, x_axis)
			WaitForTurn(rthigh, x_axis)
			Turn(rthigh, x_axis, 0, 4)
			Turn(rleg, x_axis, 0, 5)
			WaitForTurn(rleg, x_axis)
			WaitForTurn(rthigh, x_axis)

			Sleep(200)
		end
	end
end

function StopWalking()
	Turn(rthigh, x_axis, 0, 5)
	Turn(rleg, x_axis, 0, 5)
end

function script.StartMoving()
   isMoving = true
   	StartThread(thrust)
	StartThread(walk)
end

function script.StopMoving()
   isMoving = false
   StartThread(StopWalking)
end   

function thrust()
	common.DirtTrail()
end

function BuildFX()
	while(building == true) do
		EmitSfx (nanopoint1, 1024)
		Sleep(200)
		EmitSfx (nanopoint2, 1024)
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
		Explode(backpack, SFX.EXPLODE_ON_HIT)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end