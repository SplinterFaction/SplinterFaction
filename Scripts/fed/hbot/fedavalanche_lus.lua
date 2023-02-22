pelvis, dirt, lthigh, rthigh, lleg, rleg, lfoot, rfoot, turret, cannonbarrel1, cannonfirepoint1, cannonbarrel2, cannonfirepoint2, missilebarrel, missilefirepoint1 = piece('pelvis', 'dirt', 'lthigh', 'rthigh', 'lleg', 'rleg', 'lfoot', 'rfoot', 'turret', 'cannonbarrel1', 'cannonfirepoint1', 'cannonbarrel2', 'cannonfirepoint2', 'missilebarrel', 'missilefirepoint1' )

common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}
local SIG_AIM2 = {}
local SIG_AIM3 = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

-- Lessgooooo (Walk)
common.WalkScript()

function script.Create()
    StartThread(common.SmokeUnit, {pelvis, lthigh, rthigh, lleg, rleg, lfoot, rfoot, turret, cannonbarrel1, cannonfirepoint1, cannonbarrel2, cannonfirepoint2, missilebarrel, missilefirepoint1t})
end



function thrust()
    common.DirtTrail()
end

function RestoreAfterDelay()
    Sleep(2000)
    -- Reset Turret and Barrels
    Turn(turret, y_axis, 0, 1)
    Turn(cannonbarrel1, x_axis, 0, 1)
    Turn(cannonbarrel2, x_axis, 0, 1)
end

function script.AimFromWeapon(WeaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return turret
end

local firepoints1 = {cannonfirepoint1, cannonfirepoint2}
local currentFirepoint1 = 1
local totalNumberofFirepoints1 = 2

function script.QueryWeapon(WeaponID)
    if WeaponID == 1 then
        return firepoints1[currentFirepoint1]
    elseif WeaponID == 2 then
        return missilefirepoint1
    end
end

function script.FireWeapon(WeaponID)
    if WeaponID == 1 then
        currentFirepoint1 = currentFirepoint1 + 1
        if currentFirepoint1 == (totalNumberofFirepoints1 + 1) then -- when currentFirepoint gets to one more than the total number of firepoints, reset it to 1
            currentFirepoint1 = 1
        end
        EmitSfx (firepoints1[currentFirepoint1], 1024)
    elseif WeaponID == 2 then
       -- EmitSfx (missilefirepoint1, 1024)
    end
end

function script.AimWeapon(WeaponID, heading, pitch)

    Turn(turret, y_axis, heading, 10)

    if WeaponID == 1 then
        Signal(SIG_AIM)
        SetSignalMask(SIG_AIM)
        WaitForTurn(turret, y_axis)
        Turn(cannonbarrel1, x_axis, -pitch, 10)
        Turn(cannonbarrel2, x_axis, -pitch, 10)
        WaitForTurn(cannonbarrel1, x_axis)
        WaitForTurn(cannonbarrel2, x_axis)
        StartThread(RestoreAfterDelay)
        --Spring.Echo("AimWeapon: FireWeapon")
        return true
    elseif WeaponID == 2 then
        return true
    end
end

function script.Killed()
    Explode(cannonbarrel1, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(cannonbarrel2, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(missilebarrel, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(turret, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(pelvis, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(rthigh, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(rleg, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(lthigh, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    Explode(lleg, SFX.EXPLODE_ON_HIT + SFX.NO_HEATCLOUD)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end