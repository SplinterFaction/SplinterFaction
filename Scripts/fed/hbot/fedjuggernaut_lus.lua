
pelvis, dirt, lthigh, rthigh, lleg, rleg, lfoot, rfoot, turret, gatlingturret1, gatlingbarrel1, gatlingbarrel2, gatlingfirepoint1, gatlingfirepoint2, gatlingspins1, gatlingspins2, cannonturret1, cannonturret2, cannonbarrel1, cannonbarrel2, cannonfirepoint1, cannonfirepoint2, rocketturret1, rocketturret2, rocketbarrel1, rocketbarrel2, rocketfirepoint1, rocketfirepoint2, missilebarrel1, missilebarrel2, missilefirepoint1, missilefirepoint2, armorplate1, armorplate2, backplate1, backplate2, backplate3, fueltank1, fueltank2, fueltank3, fueltank11, fueltank12, fueltank13, fueltank21, fueltank22, fueltank23, fueltank31, fueltank32, fueltank33 = piece('pelvis', 'dirt', 'lthigh', 'rthigh', 'lleg', 'rleg', 'lfoot', 'rfoot', 'turret', 'gatlingturret1', 'gatlingbarrel1', 'gatlingbarrel2', 'gatlingfirepoint1', 'gatlingfirepoint2', 'gatlingspins1', 'gatlingspins2', 'cannonturret1', 'cannonturret2', 'cannonbarrel1', 'cannonbarrel2', 'cannonfirepoint1', 'cannonfirepoint2', 'rocketturret1', 'rocketturret2', 'rocketbarrel1', 'rocketbarrel2', 'rocketfirepoint1', 'rocketfirepoint2', 'missilebarrel1', 'missilebarrel2', 'missilefirepoint1', 'missilefirepoint2', 'armorplate1', 'armorplate2', 'backplate1', 'backplate2', 'backplate3', 'fueltank1', 'fueltank2', 'fueltank3', 'fueltank11', 'fueltank12', 'fueltank13', 'fueltank21', 'fueltank22', 'fueltank23', 'fueltank31', 'fueltank32', 'fueltank33')

common = include("headers/common_includes_lus.lua")

local SIG_AIM = {}
local SIG_AIM2 = {}
local SIG_AIM3 = {}
local SIG_AIM4 = {}
local SIG_AIM5 = {}
local SIG_AIM6 = {}
local SIG_AIM7 = {}
local SIG_AIM8 = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

-- Lessgooooo (Walk)
common.WalkScript()

function script.Create()
    StartThread(common.SmokeUnit, {pelvis, dirt, lthigh, rthigh, lleg, rleg, lfoot, rfoot, turret, gatlingturret1, gatlingbarrel1, gatlingbarrel2, gatlingfirepoint1, gatlingfirepoint2, gatlingspins1, gatlingspins2, cannonturret1, cannonturret2, cannonbarrel1, cannonbarrel2, cannonfirepoint1, cannonfirepoint2, rocketturret1, rocketturret2, rocketbarrel1, rocketbarrel2, rocketfirepoint1, rocketfirepoint2, missilebarrel1, missilebarrel2, missilefirepoint1, missilefirepoint2, armorplate1, armorplate2, backplate1, backplate2, backplate3, fueltank1, fueltank2, fueltank3, fueltank11, fueltank12, fueltank13, fueltank21, fueltank22, fueltank23, fueltank31, fueltank32, fueltank33})
end

function thrust()
    common.DirtTrail()
end

function RestoreAfterDelay()
    Sleep(5000)
    -- Reset Turret and Barrels
    Turn(gatlingturret1, y_axis, 0, 1)
    Turn(gatlingbarrel1, x_axis, 0, 1)
    Turn(gatlingbarrel2, x_axis, 0, 1)
    Turn(cannonturret1, y_axis, 0, 1)
    Turn(cannonbarrel1, x_axis, 0, 1)
    Turn(cannonturret2, y_axis, 0, 1)
    Turn(cannonbarrel2, x_axis, 0, 1)
    Turn(rocketturret1, y_axis, 0, 1)
    Turn(rocketbarrel1, x_axis, 0, 1)
    Turn(rocketturret2, y_axis, 0, 1)
    Turn(rocketbarrel2, x_axis, 0, 1)
    Turn(missilebarrel1, x_axis, 0, 1)
    Turn(missilebarrel2, x_axis, 0, 1)
end

function script.AimFromWeapon(WeaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return turret
end

local firepoints1 = {gatlingfirepoint1, gatlingfirepoint2}
local currentFirepoint1 = 1
local totalNumberofFirepoints1 = 2

local firepoints2 = {missilefirepoint1, missilefirepoint2}
local currentFirepoint2 = 1
local totalNumberofFirepoints2 = 2

function script.QueryWeapon(WeaponID)
    if WeaponID == 1 then
        return firepoints1[currentFirepoint1]
    elseif WeaponID == 2 then
        return cannonfirepoint1
    elseif WeaponID == 3 then
        return cannonfirepoint2
    elseif WeaponID == 4 then
        return rocketfirepoint1
    elseif WeaponID == 5 then
        return rocketfirepoint2
    elseif WeaponID == 6 then
        return firepoints2[currentFirepoint2]
    end
end

function script.FireWeapon(WeaponID)
    if WeaponID == 1 then
        currentFirepoint1 = currentFirepoint1 + 1
        if currentFirepoint1 == (totalNumberofFirepoints1 + 1) then -- when currentFirepoint gets to one more than the total number of firepoints, reset it to 1
            currentFirepoint1 = 1
        end
        -- Spring.Echo(currentFirepoint)
        EmitSfx (firepoints1[currentFirepoint1], 1024)
    elseif WeaponID == 2 then
        EmitSfx (cannonfirepoint1, 1024)
    elseif WeaponID == 3 then
        EmitSfx (cannonfirepoint2, 1024)
    elseif WeaponID == 4 then
        EmitSfx (rocketfirepoint1, 1024)
    elseif WeaponID == 5 then
        EmitSfx (rocketfirepoint2, 1024)
    elseif WeaponID == 6 then
        currentFirepoint2 = currentFirepoint2 + 1
        if currentFirepoint2 == (totalNumberofFirepoints2 + 1) then -- when currentFirepoint gets to one more than the total number of firepoints, reset it to 1
            currentFirepoint2 = 1
        end
        -- Spring.Echo(currentFirepoint)
    end
end

function script.AimWeapon(WeaponID, heading, pitch)


    if WeaponID == 1 then
        Signal(SIG_AIM)
        SetSignalMask(SIG_AIM)
        Turn(gatlingturret1, y_axis, heading, 10)
        Turn(gatlingbarrel1, x_axis, -pitch, 10)
        Turn(gatlingbarrel2, x_axis, -pitch, 10)
        WaitForTurn(gatlingturret1, y_axis)
        WaitForTurn(gatlingbarrel1, x_axis)
        WaitForTurn(gatlingbarrel1, x_axis)
        StartThread(RestoreAfterDelay)
        --Spring.Echo("AimWeapon: FireWeapon")
        return true
    elseif WeaponID == 2 then
        Signal(SIG_AIM2)
        SetSignalMask(SIG_AIM2)
        Turn(cannonturret1, y_axis, heading, 10)
        Turn(cannonbarrel1, x_axis, -pitch, 10)
        WaitForTurn(cannonbarrel1, x_axis)
        WaitForTurn(cannonturret1, y_axis)

        return true
    elseif WeaponID == 3 then
        Signal(SIG_AIM3)
        SetSignalMask(SIG_AIM3)
        Turn(cannonturret2, y_axis, heading, 10)
        Turn(cannonbarrel2, x_axis, -pitch, 10)
        WaitForTurn(cannonbarrel2, x_axis)
        WaitForTurn(cannonturret2, y_axis)
        return true
    elseif WeaponID == 4 then
        Signal(SIG_AIM4)
        SetSignalMask(SIG_AIM4)
        Turn(rocketturret1, y_axis, heading, 10)
        Turn(rocketbarrel1, x_axis, -pitch, 10)
        WaitForTurn(rocketbarrel1, x_axis)
        WaitForTurn(rocketturret1, y_axis)
        return true
    elseif WeaponID == 5 then
        Signal(SIG_AIM5)
        SetSignalMask(SIG_AIM5)
        Turn(rocketturret2, y_axis, heading, 10)
        Turn(rocketbarrel2, x_axis, -pitch, 10)
        WaitForTurn(rocketbarrel2, x_axis)
        WaitForTurn(rocketturret2, y_axis)
        return true
    elseif WeaponID == 6 then

        return true
    end
end

function script.Killed()
    Explode(gatlingbarrel1, SFX.EXPLODE_ON_HIT)
    Explode(cannonbarrel1, SFX.EXPLODE_ON_HIT)
    Explode(gatlingbarrel2, SFX.EXPLODE_ON_HIT)
    Explode(cannonbarrel2, SFX.EXPLODE_ON_HIT)
    Explode(missilebarrel1, SFX.EXPLODE_ON_HIT)
    Explode(missilebarrel2, SFX.EXPLODE_ON_HIT)
    Explode(rocketbarrel1, SFX.EXPLODE_ON_HIT)
    Explode(rocketbarrel2, SFX.EXPLODE_ON_HIT)
    Explode(turret, SFX.EXPLODE_ON_HIT)
    Explode(pelvis, SFX.EXPLODE_ON_HIT)
    Explode(rthigh, SFX.EXPLODE_ON_HIT)
    Explode(rleg, SFX.EXPLODE_ON_HIT)
    Explode(lthigh, SFX.EXPLODE_ON_HIT)
    Explode(lleg, SFX.EXPLODE_ON_HIT)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end