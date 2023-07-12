
base, missileturret1, missilebarrel1, missilefirepoint1, missilefirepoint2 = piece('base', 'missileturret1', 'missilebarrel1', 'missilefirepoint1', 'missilefirepoint2')

local SIG_AIM = {}

common = include("headers/common_includes_lus.lua")

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
    StartThread(common.SmokeUnit, {base, missileturret1, missilebarrel1, missilefirepoint1, missilefirepoint2})
    building = false
end

local function RestoreAfterDelay()
    Sleep(2000)
    Turn(missileturret1, y_axis, 0, 5)
    Turn(missilebarrel1, x_axis, 0, 5)
end

function script.AimFromWeapon(weaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return missileturret1
end

local firepoints = {missilefirepoint1, missilefirepoint2}
local currentFirepoint = 1

function script.QueryWeapon(weaponID)
    return firepoints[currentFirepoint]
end

function script.FireWeapon(weaponID)
    currentFirepoint = 3 - currentFirepoint
    EmitSfx (firepoints[currentFirepoint], 1024)
end

function script.AimWeapon(weaponID, heading, pitch)
    Signal(SIG_AIM)
    SetSignalMask(SIG_AIM)
    Turn(missileturret1, y_axis, heading, 5)
    Turn(missilebarrel1, x_axis, -pitch, 5)

    WaitForTurn(missileturret1, y_axis)
    WaitForTurn(missilebarrel1, x_axis)

    StartThread(RestoreAfterDelay)
    --Spring.Echo("AimWeapon: FireWeapon")
    return true
end

function script.Killed()
    Explode(missileturret1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(missilebarrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end