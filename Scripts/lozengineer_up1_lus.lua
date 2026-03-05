base, nanopoint1, nanopoint2, frontwheels, rearwheels, dirt = piece('base', 'nanopoint1', 'nanopoint2', 'frontwheels', 'rearwheels', 'dirt')
local SIG_AIM = {}

local nanoPieces = {[0] = nanopoint1, nanopoint2}
local SIG_AIM = 2

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

common = include("headers/common_includes_lus.lua")

function script.Create()
	StartThread(common.SmokeUnit, {base, nanopoint1, nanopoint2, frontwheels, rearwheels, dirt})
	StartThread(BuildFX)
	building = false
	Spring.SetUnitNanoPieces(unitID, nanoPieces)
end

function script.StartMoving()
   isMoving = true
   	StartThread(thrust)
	Spin( frontwheels, 1, 50)
	Spin( rearwheels, 1, 50)
end

function script.StopMoving()
   isMoving = false
	StopSpin( frontwheels, 1, 50)
	StopSpin( rearwheels, 1, 50)
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

function script.StopBuilding()
    SetUnitValue(COB.INBUILDSTANCE, 0)
	building = false
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

function script.Killed()
		Explode(base, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end