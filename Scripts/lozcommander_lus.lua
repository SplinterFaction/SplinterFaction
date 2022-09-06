

base, nano1, wheels1, wheels2, wheels3, wheels4, wheels5, laserturret1, laserbarrel1, laserfirepoint1 = piece('base', 'nano1', 'wheels1', 'wheels2', 'wheels3', 'wheels4', 'wheels5', 'laserturret1', 'laserbarrel1', 'laserfirepoint1')

local SIG_AIM = {}
local nanoPieces = {[0] = nano1}

common = include("headers/common_includes_lus.lua")

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
    StartThread(common.SmokeUnit, {base, nano1, wheels1, wheels2, wheels3, wheels4, wheels5, laserturret1, laserbarrel1, laserfirepoint1})
    building = false
end

function script.StartMoving()
    isMoving = true
    -- StartThread(thrust)
    common.WheelStartSpin5()
end

function script.StopMoving()
    isMoving = false
    common.WheelStopSpin5()
end

local function RestoreAfterDelay()
    Sleep(2000)
    Turn(laserturret1, y_axis, 0, 5)
    Turn(laserbarrel1, x_axis, 0, 5)
end

function script.AimFromWeapon(weaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return laserturret1
end

function script.QueryWeapon(weaponID)
    --Spring.Echo("QueryWeapon: FireWeapon")
    return laserfirepoint1
end

function script.AimWeapon(weaponID, heading, pitch)
    Signal(SIG_AIM)
    SetSignalMask(SIG_AIM)
    Turn(laserturret1, y_axis, heading, 100)
    Turn(laserbarrel1, x_axis, -pitch, 100)
    WaitForTurn(laserturret1, y_axis)
    WaitForTurn(laserbarrel1, x_axis)
    StartThread(RestoreAfterDelay)
    --Spring.Echo("AimWeapon: FireWeapon")
    return true
end

function script.FireWeapon(weaponID)
    --Spring.Echo("FireWeapon: FireWeapon")
    EmitSfx (laserfirepoint1, 1027)
end

function BuildFX()
    while(building == true) do
        EmitSfx (nano1, 1024)
        Sleep(550)
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
    SetUnitValue(COB.INBUILDSTANCE, 1)
    building = true
    StartThread(BuildFX)
end

function script.QueryNanoPiece()
    local nano = nanoPieces[nanoNum]
    return nano
end

function script.Killed()
    Explode(laserbarrel1, SFX.EXPLODE_ON_HIT)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end