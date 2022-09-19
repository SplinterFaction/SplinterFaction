
base, railgunturret1, railgunbarrel1, railgunfirepoint1 = piece('base', 'railgunturret1', 'railgunbarrel1', 'railgunfirepoint1')

local SIG_AIM = {}

common = include("headers/common_includes_lus.lua")

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
    StartThread(common.SmokeUnit, {base, railgunturret1, railgunbarrel1, railgunfirepoint1})
    building = false
end

local function RestoreAfterDelay()
    Sleep(2000)
    Turn(railgunturret1, y_axis, 0, 5)
    Turn(railgunbarrel1, x_axis, 0, 5)
end

function script.AimFromWeapon(weaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return railgunturret1
end

function script.QueryWeapon(weaponID)
    --Spring.Echo("QueryWeapon: FireWeapon")
    return railgunfirepoint1
end

function script.AimWeapon(weaponID, heading, pitch)
    Signal(SIG_AIM)
    SetSignalMask(SIG_AIM)
    Turn(railgunturret1, y_axis, heading, 100)
    Turn(railgunbarrel1, x_axis, -pitch, 100)
    WaitForTurn(railgunturret1, y_axis)
    WaitForTurn(railgunbarrel1, x_axis)
    StartThread(RestoreAfterDelay)
    --Spring.Echo("AimWeapon: FireWeapon")
    return true
end

function script.FireWeapon(weaponID)
    -- Spring.Echo("FireWeapon: FireWeapon")
    -- EmitSfx (railgunfirepoint1, 1024)
end

function script.Killed()
    Explode(railgunturret1, SFX.EXPLODE_ON_HIT)
    Explode(railgunbarrel1, SFX.EXPLODE_ON_HIT)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end