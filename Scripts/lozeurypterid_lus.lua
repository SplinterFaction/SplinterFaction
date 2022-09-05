
base, nuketurret1, nukebarrel1, wheels1, wheels2, wheels3, wheels4, wheels5, wheels6 = piece('base', 'nuketurret1', 'nukebarrel1', 'wheels1', 'wheels2', 'wheels3', 'wheels4', 'wheels5', 'wheels6')

local SIG_AIM = {}

common = include("headers/common_includes_lus.lua")

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
    StartThread(common.SmokeUnit, {base, nuketurret1})
    building = false
end

function script.StartMoving()
    isMoving = true
    -- StartThread(thrust)
    common.WheelStartSpin6()
end

function script.StopMoving()
    isMoving = false
    common.WheelStopSpin6()
end

local function RestoreAfterDelay()
    Sleep(2000)
    Turn(nuketurret1, y_axis, 0, 5)
    Turn(nukebarrel1, x_axis, 0, 5)
end

function script.AimFromWeapon(weaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return nuketurret1
end

function script.QueryWeapon(weaponID)
    --Spring.Echo("QueryWeapon: FireWeapon")
    return nukefirepoint1
end

function script.AimWeapon(weaponID, heading, pitch)
    Signal(SIG_AIM)
    SetSignalMask(SIG_AIM)
    Turn(nuketurret1, y_axis, heading, 100)
    Turn(nukebarrel1, x_axis, -pitch, 100)
    WaitForTurn(nuketurret1, y_axis)
    WaitForTurn(nukebarrel1, x_axis)
    StartThread(RestoreAfterDelay)
    --Spring.Echo("AimWeapon: FireWeapon")
    return true
end

function script.FireWeapon(weaponID)
    --Spring.Echo("FireWeapon: FireWeapon")
    EmitSfx (nukefirepoint1, 1024)
end

function script.Killed()
    Explode(nuketurret1, SFX.EXPLODE_ON_HIT)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end