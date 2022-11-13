
base, nano1, nanopoint1, nano2, nanopoint2, engine1, engine2, engine3, engine4, engine5, engine6, engine7, engine8, nanopad = piece('base', 'nano1', 'nanopoint1', 'nano2', 'nanopoint2', 'engine1', 'engine2', 'engine3', 'engine4', 'engine5', 'engine6', 'engine7', 'engine8', 'nanopad')

common = include("headers/common_includes_lus.lua")

local nanoPieces = {[0] = nanopoint1, nanopoint2}

local SIG_STATECHG = {}
local SIG_REQSTATE = {}
local statechg_StateChanging
local state = { build = 0, stop = 1}
local statechg_DesiredState

function script.Create()
	StartThread(common.SmokeUnit, {base, nano1, nanopoint1, nano2, nanopoint2, engine1, engine2, engine3, engine4, engine5, engine6, engine7, engine8, nanopad})
	StartThread(BuildFX)
	building = false
	Spring.SetUnitNanoPieces(unitID, nanoPieces)
end

function RestoreAfterDelay()
	SetSignalMask(SIG_AIM)
	if building == false then
		Sleep(2000)
	end
end

function BuildFX()
	while(building == true) do
		EmitSfx (nanopoint1, 1024)
		Sleep(200)
		EmitSfx (nanopoint2, 1024)
		Sleep(325)
	end
end

function RequestState(requestedstate, currentstate)
	Spring.UnitScript.Signal(SIG_REQSTATE)
	Spring.UnitScript.SetSignalMask(SIG_REQSTATE)
	if  statechg_StateChanging  then
		statechg_DesiredState = requestedstate
		return (0)
	end
	statechg_StateChanging = true
	currentstate = statechg_DesiredState
	statechg_DesiredState = requestedstate
	while statechg_DesiredState ~= currentstate  do
		if statechg_DesiredState == state.build then
			StartThread(Go)
			currentstate = state.build
		elseif statechg_DesiredState == state.stop then
			--Spring.Echo("Stop now")
			StartThread(Stop)
			currentstate = 1
		end
	end
	statechg_StateChanging = false
end

function Stop()
	Spring.UnitScript.Signal(SIG_STATECHG)
	Spring.UnitScript.SetSignalMask(SIG_STATECHG)
	SetUnitValue(COB.INBUILDSTANCE, 0)	--set INBUILDSTANCE to 0
	---StartThread(RestoreAfterDelay)
end

function Go()
	Spring.UnitScript.Signal(SIG_STATECHG)
	Spring.UnitScript.SetSignalMask(SIG_STATECHG)
	SetUnitValue(COB.INBUILDSTANCE, 1)
end

function script.StopBuilding()
    SetUnitValue(COB.INBUILDSTANCE, 0)
	building = false
	StartThread(RestoreAfterDelay)

end

function script.StartBuilding()
    SetUnitValue(COB.INBUILDSTANCE, 1)
	building = true
	StartThread(BuildFX)
end

function script.QueryNanoPiece()
	local nano = nanoPieces[nanoNum]
	return nano
end

function script.QueryBuildInfo()
	return nanopad
end

function script.Killed()
	Explode(base, SFX.EXPLODE_ON_HIT)
	Explode(nano1, SFX.EXPLODE_ON_HIT)
	Explode(nano2, SFX.EXPLODE_ON_HIT)
	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end