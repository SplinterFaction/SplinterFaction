
base, flameturret1, flamebarrel1, flamefirepoint1 = piece('base', 'flameturret1', 'flamebarrel1', 'flamefirepoint1')

local SIG_AIM = {}

common = include("headers/common_includes_lus.lua")

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
    StartThread(common.SmokeUnit, {base, flameturret1, flamebarrel1, flamefirepoint1})
    building = false
end

local function RestoreAfterDelay()
    Sleep(2000)
    Turn(flameturret1, y_axis, 0, 5)
    Turn(flamebarrel1, x_axis, 0, 5)
end

function script.AimFromWeapon(weaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return flameturret1
end

function script.QueryWeapon(weaponID)
    --Spring.Echo("QueryWeapon: FireWeapon")
    return flamefirepoint1
end

function script.AimWeapon(weaponID, heading, pitch)
    Signal(SIG_AIM)
    SetSignalMask(SIG_AIM)
    Turn(flameturret1, y_axis, heading, 100)
    Turn(flamebarrel1, x_axis, -pitch, 100)
    WaitForTurn(flameturret1, y_axis)
    WaitForTurn(flamebarrel1, x_axis)
    StartThread(RestoreAfterDelay)
    --Spring.Echo("AimWeapon: FireWeapon")
    return true
end

function script.FireWeapon(weaponID)
    -- Spring.Echo("FireWeapon: FireWeapon")
    -- EmitSfx (flamefirepoint1, 1024)
end

function script.Killed()
    Explode(flameturret1, SFX.EXPLODE_ON_HIT)
    Explode(flamebarrel1, SFX.EXPLODE_ON_HIT)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end