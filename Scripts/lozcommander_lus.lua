

base, nano1, wheels1, wheels2, wheels3, wheels4, wheels5, laserturret1, laserbarrel1, laserfirepoint1, emitter1, emitterfirepoint1 = piece('base', 'nano1', 'wheels1', 'wheels2', 'wheels3', 'wheels4', 'wheels5', 'laserturret1', 'laserbarrel1', 'laserfirepoint1', 'emitter1', 'emitterfirepoint1')

common = include("headers/common_includes_lus.lua")

local SIG_AIM1 = {}
local SIG_AIM2 = {}


local nanoPieces = {[0] = nano1}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
    StartThread(common.SmokeUnit, {base, nano1, wheels1, wheels2, wheels3, wheels4, wheels5, laserturret1, laserbarrel1, laserfirepoint1, emitter1, emitterfirepoint1})
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
    Sleep(10000)
    Turn(laserturret1, y_axis, 0, 5)
    Turn(laserbarrel1, x_axis, 0, 5)
end

function script.AimFromWeapon(WeaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return laserturret1
end

function script.QueryWeapon(WeaponID)
    if WeaponID == 1 then
        return laserfirepoint1
    elseif WeaponID == 2 then
        return emitterfirepoint1
    end
end

function script.FireWeapon(WeaponID)
    if WeaponID == 1 then
        EmitSfx (laserfirepoint1, 1024)
    end
end

function script.AimWeapon(WeaponID, heading, pitch)
    -- Spring.SetUnitWeaponState(unitID, WeaponID, {reaimTime = 5}) -- Only use this if the turret is glitchy
    Turn(laserturret1, y_axis, heading, 50)
    Turn(laserbarrel1, x_axis, pitch, 50)
    WaitForTurn(laserturret1, y_axis)
    WaitForTurn(laserbarrel1, x_axis)
    if WeaponID == 1 then
        Signal(SIG_AIM1)
        SetSignalMask(SIG_AIM1)
        --Spring.Echo("AimWeapon: FireWeapon")
        StartThread(RestoreAfterDelay)
        return true
    elseif WeaponID == 2 then

    end
end

function script.StopBuilding()
    SetUnitValue(COB.INBUILDSTANCE, 0)
    building = false
    -- StartThread(RestoreAfterDelay)
    Signal(SIG_AIM2)
    SetSignalMask(SIG_AIM2)
end

function script.StartBuilding(heading, pitch)
    Signal(SIG_AIM2)
    SetSignalMask(SIG_AIM2)
    SetUnitValue(COB.INBUILDSTANCE, 1)
    building = true
    --StartThread(BuildFX)
end

function script.QueryNanoPiece()
    local nano = nanoPieces[nanoNum]
    return nano1
end

function script.Killed()
    Explode(laserbarrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end