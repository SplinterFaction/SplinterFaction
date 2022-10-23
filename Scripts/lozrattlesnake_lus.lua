
base, flakturret1, flakbarrel1, flakfirepoint1 = piece('base', 'flakturret1', 'flakbarrel1', 'flakfirepoint1')

local SIG_AIM = {}

common = include("headers/common_includes_lus.lua")

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
    StartThread(common.SmokeUnit, {base, flakturret1, flakbarrel1, flakfirepoint1})
    building = false
end

local function RestoreAfterDelay()
    Sleep(2000)
    Turn(flakturret1, y_axis, 0, 5)
    Turn(flakbarrel1, x_axis, 0, 5)
end

function script.AimFromWeapon(weaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return flakturret1
end

function script.QueryWeapon(weaponID)
    --Spring.Echo("QueryWeapon: FireWeapon")
    return flakfirepoint1
end

function script.AimWeapon(weaponID, heading, pitch)
    Signal(SIG_AIM)
    SetSignalMask(SIG_AIM)
    Turn(flakturret1, y_axis, heading, 100)
    Turn(flakbarrel1, x_axis, -pitch, 100)
    WaitForTurn(flakturret1, y_axis)
    WaitForTurn(flakbarrel1, x_axis)
    StartThread(RestoreAfterDelay)
    --Spring.Echo("AimWeapon: FireWeapon")
    return true
end

function script.FireWeapon(weaponID)
    -- Spring.Echo("FireWeapon: FireWeapon")
    -- EmitSfx (flakfirepoint1, 1024)
end

function script.Killed()
    Explode(flakturret1, SFX.EXPLODE_ON_HIT)
    Explode(flakbarrel1, SFX.EXPLODE_ON_HIT)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end