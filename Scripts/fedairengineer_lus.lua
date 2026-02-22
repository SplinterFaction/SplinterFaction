base, wing1, wing2, nanoarm1, nano1, nanopoint1, nanoarm2, nano2, nanopoint2, nanoarm3, nano3, nanopoint3, nanoarm4, nano4, nanopoint4, thruster1, thruster2 = piece('base', 'wing1', 'wing2', 'nanoarm1', 'nano1', 'nanopoint1', 'nanoarm2', 'nano2', 'nanopoint2', 'nanoarm3', 'nano3', 'nanopoint3', 'nanoarm4', 'nano4', 'nanopoint4', 'thruster1', 'thruster2')
local SIG_AIM = {}

local nanoPieces = {[0] = nanopoint1, nanopoint2, nanopoint3, nanopoint4}
local SIG_AIM = 2

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

common = include("headers/common_includes_lus.lua")

function script.Create()
	StartThread(common.SmokeUnit, {base, wing1, wing2, nanoarm1, nano1, nanopoint1, nanoarm2, nano2, nanopoint2, nanoarm3, nano3, nanopoint3, nanoarm4, nano4, nanopoint4, thruster1, thruster2})
	StartThread(BuildFX)
	building = false
	Spring.SetUnitNanoPieces(unitID, nanoPieces)
end

function script.StartMoving()
   isMoving = true
end

function script.StopMoving()
   isMoving = false
end   

function thrust()
end

function BuildFX()
	while(building == true) do
		EmitSfx (nanopoint1, "nano-animated")
		EmitSfx (nanopoint2, "nano-animated")
		EmitSfx (nanopoint3, "nano-animated")
		EmitSfx (nanopoint4, "nano-animated")
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
	Explode(wing1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
	Explode(wing2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
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