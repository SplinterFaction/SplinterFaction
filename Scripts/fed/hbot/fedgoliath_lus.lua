pelvis, dirt, lthigh, rthigh, lleg, rleg, lfoot, rfoot, turret, gatlingbarrel1, gatlingbarrel2, gatlingfirepoint1, gatlingfirepoint2, cannonbarrel1, cannonbarrel2, cannonfirepoint1, cannonfirepoint2 = piece('pelvis', 'dirt', 'lthigh', 'rthigh', 'lleg', 'rleg', 'lfoot', 'rfoot', 'turret', 'gatlingbarrel1', 'gatlingbarrel2', 'gatlingfirepoint1', 'gatlingfirepoint2', 'cannonbarrel1', 'cannonbarrel2', 'cannonfirepoint1', 'cannonfirepoint2')
local SIG_AIM = {}
local SIG_AIM2 = {}
local SIG_AIM3 = {}
local SIG_AIM4 = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
    StartThread(common.SmokeUnit, {pelvis, turret})
end

common = include("headers/common_includes_lus.lua")

function thrust()
    common.DirtTrail()
end

function RestoreAfterDelay()
    Sleep(2000)
    -- Reset Turret and Barrels
    Turn(turret, y_axis, 0, 1)
    Turn(gatlingbarrel1, x_axis, 0, 1)
    Turn(cannonbarrel1, x_axis, 0, 1)
    Turn(gatlingbarrel2, x_axis, 0, 1)
    Turn(cannonbarrel2, x_axis, 0, 1)
end

function script.AimFromWeapon(WeaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return turret
end

function script.QueryWeapon(WeaponID)
    if WeaponID == 1 then
        return gatlingfirepoint1
    elseif WeaponID == 2 then
        return gatlingfirepoint2
    elseif WeaponID == 3 then
        return cannonfirepoint1
    elseif WeaponID == 4 then
        return cannonfirepoint2
    end
end

function script.FireWeapon(WeaponID)
    if WeaponID == 1 then
        EmitSfx (gatlingfirepoint1, 1024)
    elseif WeaponID == 2 then
        EmitSfx (gatlingfirepoint2, 1024)
    elseif WeaponID == 3 then
        EmitSfx (cannonfirepoint1, 1024)
    elseif WeaponID == 4 then
        EmitSfx (cannonfirepoint2, 1024)
    end
end

function script.AimWeapon(WeaponID, heading, pitch)
    if WeaponID == 1 then
        Signal(SIG_AIM)
        SetSignalMask(SIG_AIM)
        Turn(turret, y_axis, heading, 10)
        WaitForTurn(turret, y_axis)
        Turn(gatlingbarrel1, x_axis, -pitch, 10)
        WaitForTurn(gatlingbarrel1, x_axis)
        StartThread(RestoreAfterDelay)
        --Spring.Echo("AimWeapon: FireWeapon")
        return true
    elseif WeaponID == 2 then
        Signal(SIG_AIM2)
        SetSignalMask(SIG_AIM2)

        Turn(gatlingbarrel2, x_axis, -pitch, 10)
        WaitForTurn(gatlingbarrel2, x_axis)
        StartThread(RestoreAfterDelay)
        --Spring.Echo("AimWeapon: FireWeapon")
        return true
    elseif WeaponID == 3 then
        Signal(SIG_AIM3)
        SetSignalMask(SIG_AIM3)

        Turn(cannonbarrel1, x_axis, -pitch, 10)
        WaitForTurn(cannonbarrel1, x_axis)
        return true
    elseif WeaponID == 4 then
        Signal(SIG_AIM4)
        SetSignalMask(SIG_AIM4)

        Turn(cannonbarrel2, x_axis, -pitch, 10)
        WaitForTurn(cannonbarrel2, x_axis)
        return true
    end
end

function script.Killed()
    Explode(gatlingbarrel1, SFX.EXPLODE_ON_HIT)
    Explode(cannonbarrel1, SFX.EXPLODE_ON_HIT)
    Explode(gatlingbarrel2, SFX.EXPLODE_ON_HIT)
    Explode(cannonbarrel2, SFX.EXPLODE_ON_HIT)
    Explode(turret, SFX.EXPLODE_ON_HIT)
    Explode(pelvis, SFX.EXPLODE_ON_HIT)
    Explode(rthigh, SFX.EXPLODE_ON_HIT)
    Explode(rleg, SFX.EXPLODE_ON_HIT)
    Explode(lthigh, SFX.EXPLODE_ON_HIT)
    Explode(lleg, SFX.EXPLODE_ON_HIT)
    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
-- START THE WALK SCRIPT
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
-- For T:\Objects3D\blender files\2_legged_walk_animation_vb1.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 7))
local ANIM_FRAMES = 4
local SIG_WALK = 1

local walking = false -- prevent script.StartMoving from spamming threads if already walking

local function GetSpeedParams()
    local maxSpeed = UnitDefs[Spring.GetUnitDefID(unitID)].speed
    local maxSpeed = maxSpeed *0.01
    -- Spring.Echo(maxSpeed)
    local attMod = (maxSpeed)
    if attMod <= 0 then
        return 0, 300
    end
    local sleepFrames = math.floor(ANIM_FRAMES / attMod + 0.5)
    if sleepFrames < 1 then
        sleepFrames = 1
    end
    local speedMod = 1 / sleepFrames
    return speedMod, 33*sleepFrames
end

local function Walk()
    Signal(SIG_WALK)
    SetSignalMask(SIG_WALK)

    local speedMult, sleepTime = GetSpeedParams()

    -- Frame: 4 (first step)
    Turn(lfoot, x_axis, 0.386673, 11.600187 * speedMult) -- delta=-22.15
    Turn(lfoot, z_axis, 0.020291, 0.608727 * speedMult) -- delta=1.16
    Turn(lfoot, y_axis, 0.006228, 0.186828 * speedMult) -- delta=0.36
    Turn(lleg, x_axis, -0.052934, 1.588034 * speedMult) -- delta=3.03
    Turn(lthigh, x_axis, -0.549209, 16.476281 * speedMult) -- delta=31.47
    Turn(lthigh, z_axis, -0.007471, 0.224126 * speedMult) -- delta=-0.43
    Turn(lthigh, y_axis, -0.051735, 1.552063 * speedMult) -- delta=-2.96
    Turn(rfoot, x_axis, -0.665976, 19.979280 * speedMult) -- delta=38.16
    Turn(rfoot, z_axis, 0.018466, 0.553971 * speedMult) -- delta=1.06
    Turn(rfoot, y_axis, -0.009378, 0.281346 * speedMult) -- delta=-0.54
    Turn(rleg, x_axis, 0.298197, 8.945923 * speedMult) -- delta=-17.09
    Turn(rthigh, x_axis, 0.367865, 11.035942 * speedMult) -- delta=-21.08
    Turn(rthigh, z_axis, -0.013571, 0.407139 * speedMult) -- delta=-0.78
    Turn(rthigh, y_axis, 0.002489, 0.074657 * speedMult) -- delta=0.14
    Sleep(sleepTime)

    while true do
        speedMult, sleepTime = GetSpeedParams()
        -- Frame:8
        Turn(lfoot, x_axis, -0.154627, 16.238990 * speedMult) -- delta=31.01
        Turn(lfoot, z_axis, -0.054409, 2.240985 * speedMult) -- delta=-4.28
        Turn(lfoot, y_axis, 0.009575, 0.100422 * speedMult) -- delta=0.19
        Turn(lleg, x_axis, 1.085282, 34.146493 * speedMult) -- delta=-65.21
        Turn(lthigh, x_axis, -1.380327, 24.933515 * speedMult) -- delta=47.62
        Turn(lthigh, z_axis, 0.472109, 14.387383 * speedMult) -- delta=27.48
        Turn(lthigh, y_axis, -0.555316, 15.107415 * speedMult) -- delta=-28.85
        Move(pelvis, y_axis, -0.450000, 13.500000 * speedMult) -- delta=-0.45
        Turn(pelvis, x_axis, -0.043633, 1.308997 * speedMult) -- delta=2.50
        Turn(rfoot, x_axis, -0.739945, 2.219067 * speedMult) -- delta=4.24
        Turn(rfoot, z_axis, -0.016019, 1.034543 * speedMult) -- delta=-1.98
        Turn(rfoot, y_axis, 0.000272, 0.289500 * speedMult) -- delta=0.55
        Turn(rleg, x_axis, 0.659397, 10.835993 * speedMult) -- delta=-20.70
        Turn(rthigh, x_axis, 0.513957, 4.382776 * speedMult) -- delta=-8.37
        Turn(rthigh, z_axis, 0.029370, 1.288250 * speedMult) -- delta=2.46
        Turn(rthigh, y_axis, 0.091910, 2.682649 * speedMult) -- delta=5.12
        Sleep(sleepTime)
        -- Frame:12
        Turn(lfoot, x_axis, 0.437922, 17.776462 * speedMult) -- delta=-33.95
        Turn(lfoot, z_axis, -0.016324, 1.142525 * speedMult) -- delta=2.18
        Turn(lfoot, y_axis, -0.000710, 0.308550 * speedMult) -- delta=-0.59
        Turn(lleg, x_axis, 0.377103, 21.245376 * speedMult) -- delta=40.58
        Turn(lthigh, x_axis, -0.725615, 19.641336 * speedMult) -- delta=-37.51
        Turn(lthigh, z_axis, 0.006083, 13.980763 * speedMult) -- delta=-26.70
        Turn(lthigh, y_axis, -0.134483, 12.624983 * speedMult) -- delta=24.11
        Move(pelvis, y_axis, -1.180000, 21.899999 * speedMult) -- delta=-0.73
        Turn(pelvis, x_axis, -0.087266, 1.308997 * speedMult) -- delta=2.50
        Turn(pelvis, y_axis, 0.130900, 3.926991 * speedMult) -- delta=7.50
        Turn(rfoot, x_axis, -0.615458, 3.734599 * speedMult) -- delta=-7.13
        Turn(rfoot, z_axis, 0.091209, 3.216853 * speedMult) -- delta=6.14
        Turn(rfoot, y_axis, -0.027718, 0.839696 * speedMult) -- delta=-1.60
        Turn(rleg, x_axis, -0.351186, 30.317481 * speedMult) -- delta=57.90
        Turn(rthigh, x_axis, 1.194566, 20.418252 * speedMult) -- delta=-39.00
        Turn(rthigh, z_axis, -0.211673, 7.231300 * speedMult) -- delta=-13.81
        Turn(rthigh, y_axis, -0.256113, 10.440699 * speedMult) -- delta=-19.94
        Sleep(sleepTime)
        -- Frame:16
        Turn(lfoot, x_axis, -0.019264, 13.715583 * speedMult) -- delta=26.19
        Turn(lfoot, z_axis, 0.001721, 0.541366 * speedMult) -- delta=1.03
        Turn(lleg, x_axis, -0.103857, 14.428786 * speedMult) -- delta=27.56
        Turn(lthigh, x_axis, 0.169631, 26.857386 * speedMult) -- delta=-51.29
        Turn(lthigh, z_axis, -0.001782, 0.235951 * speedMult) -- delta=-0.45
        Turn(lthigh, y_axis, 0.000409, 4.046767 * speedMult) -- delta=7.73
        Move(pelvis, y_axis, -0.450000, 21.899999 * speedMult) -- delta=0.73
        Turn(pelvis, x_axis, -0.043633, 1.308997 * speedMult) -- delta=-2.50
        Turn(pelvis, y_axis, -0.000000, 3.926991 * speedMult) -- delta=-7.50
        Turn(rfoot, x_axis, 0.204855, 24.609403 * speedMult) -- delta=-47.00
        Turn(rfoot, z_axis, 0.086631, 0.137354 * speedMult) -- delta=-0.26
        Turn(rfoot, y_axis, 0.013244, 1.228848 * speedMult) -- delta=2.35
        Turn(rleg, x_axis, -0.674452, 9.697984 * speedMult) -- delta=18.52
        Turn(rthigh, x_axis, 0.564478, 18.902634 * speedMult) -- delta=36.10
        Turn(rthigh, z_axis, -0.100809, 3.325912 * speedMult) -- delta=6.35
        Turn(rthigh, y_axis, -0.046769, 6.280313 * speedMult) -- delta=11.99
        Sleep(sleepTime)
        -- Frame:20
        Turn(lfoot, x_axis, -0.665976, 19.401356 * speedMult) -- delta=37.05
        Turn(lfoot, z_axis, 0.018466, 0.502338 * speedMult) -- delta=0.96
        Turn(lfoot, y_axis, -0.009378, 0.281402 * speedMult) -- delta=-0.54
        Turn(lleg, x_axis, 0.298197, 12.061626 * speedMult) -- delta=-23.04
        Turn(lthigh, x_axis, 0.367865, 5.947015 * speedMult) -- delta=-11.36
        Turn(lthigh, z_axis, -0.013571, 0.353682 * speedMult) -- delta=-0.68
        Turn(lthigh, y_axis, 0.002489, 0.062384 * speedMult) -- delta=0.12
        Move(pelvis, y_axis, 0.000000, 13.500000 * speedMult) -- delta=0.45
        Turn(pelvis, x_axis, -0.000000, 1.308997 * speedMult) -- delta=-2.50
        Turn(rfoot, x_axis, 0.386673, 5.454532 * speedMult) -- delta=-10.42
        Turn(rfoot, z_axis, 0.020291, 1.990199 * speedMult) -- delta=-3.80
        Turn(rfoot, y_axis, 0.006228, 0.210479 * speedMult) -- delta=-0.40
        Turn(rleg, x_axis, -0.052934, 18.645515 * speedMult) -- delta=-35.61
        Turn(rthigh, x_axis, -0.549209, 33.410617 * speedMult) -- delta=63.81
        Turn(rthigh, z_axis, -0.007471, 2.800151 * speedMult) -- delta=5.35
        Turn(rthigh, y_axis, -0.051735, 0.148983 * speedMult) -- delta=-0.28
        Sleep(sleepTime)
        -- Frame:24
        Turn(lfoot, x_axis, -0.739910, 2.218022 * speedMult) -- delta=4.24
        Turn(lfoot, z_axis, -0.016862, 1.059831 * speedMult) -- delta=-2.02
        Turn(lfoot, y_axis, 0.002672, 0.361509 * speedMult) -- delta=0.69
        Turn(lleg, x_axis, 0.659308, 10.833325 * speedMult) -- delta=-20.69
        Turn(lthigh, x_axis, 0.427135, 1.778097 * speedMult) -- delta=-3.40
        Turn(lthigh, z_axis, 0.019141, 0.981359 * speedMult) -- delta=1.87
        Turn(lthigh, y_axis, 0.085938, 2.503492 * speedMult) -- delta=4.78
        Move(pelvis, y_axis, -0.450000, 13.500000 * speedMult) -- delta=-0.45
        Turn(pelvis, x_axis, 0.043633, 1.308997 * speedMult) -- delta=-2.50
        Turn(rfoot, x_axis, -0.154634, 16.239202 * speedMult) -- delta=31.01
        Turn(rfoot, z_axis, -0.053564, 2.215641 * speedMult) -- delta=-4.23
        Turn(rleg, x_axis, 1.085281, 34.146468 * speedMult) -- delta=-65.21
        Turn(rthigh, x_axis, -1.446902, 26.930777 * speedMult) -- delta=51.43
        Turn(rthigh, z_axis, 0.842898, 25.511077 * speedMult) -- delta=48.72
        Turn(rthigh, y_axis, -0.920677, 26.068238 * speedMult) -- delta=-49.79-- WARNING: possible gimbal lock issue detected in frame 24 bone rthigh

        Turn(turret, x_axis, -0.056945, 1.708342 * speedMult) -- delta=3.26
        Sleep(sleepTime)
        -- Frame:28
        Turn(lfoot, x_axis, -0.615282, 3.738856 * speedMult) -- delta=-7.14
        Turn(lfoot, z_axis, 0.077944, 2.844185 * speedMult) -- delta=5.43
        Turn(lfoot, y_axis, -0.043541, 1.386386 * speedMult) -- delta=-2.65
        Turn(lleg, x_axis, -0.353060, 30.371062 * speedMult) -- delta=58.00
        Turn(lthigh, x_axis, 1.027544, 18.012296 * speedMult) -- delta=-34.40
        Turn(lthigh, z_axis, -0.127417, 4.396728 * speedMult) -- delta=-8.40
        Turn(lthigh, y_axis, 0.091642, 0.171125 * speedMult) -- delta=0.33
        Move(pelvis, y_axis, -1.180000, 21.899999 * speedMult) -- delta=-0.73
        Turn(pelvis, x_axis, 0.087266, 1.308997 * speedMult) -- delta=-2.50
        Turn(pelvis, y_axis, -0.130900, 3.926991 * speedMult) -- delta=-7.50
        Turn(rfoot, x_axis, 0.438119, 17.782571 * speedMult) -- delta=-33.96
        Turn(rfoot, z_axis, -0.005193, 1.451115 * speedMult) -- delta=2.77
        Turn(rfoot, y_axis, -0.003253, 0.334022 * speedMult) -- delta=-0.64
        Turn(rleg, x_axis, 0.376708, 21.257190 * speedMult) -- delta=40.60
        Turn(rthigh, x_axis, -0.898402, 16.454989 * speedMult) -- delta=-31.43
        Turn(rthigh, z_axis, -0.012550, 25.663462 * speedMult) -- delta=-49.01
        Turn(rthigh, y_axis, 0.143999, 31.940272 * speedMult) -- delta=61.00-- WARNING: possible gimbal lock issue detected in frame 28 bone rthigh
        Sleep(sleepTime)
        -- Frame:32
        Turn(lfoot, x_axis, 0.204854, 24.604069 * speedMult) -- delta=-46.99
        Turn(lfoot, z_axis, 0.086656, 0.261359 * speedMult) -- delta=0.50
        Turn(lfoot, y_axis, 0.013546, 1.712617 * speedMult) -- delta=3.27
        Turn(lleg, x_axis, -0.674454, 9.641817 * speedMult) -- delta=18.41
        Turn(lthigh, x_axis, 0.477281, 16.507893 * speedMult) -- delta=31.53
        Turn(lthigh, z_axis, -0.096186, 0.936936 * speedMult) -- delta=1.79
        Turn(lthigh, y_axis, -0.044768, 4.092329 * speedMult) -- delta=-7.82
        Move(pelvis, y_axis, -0.450000, 21.899999 * speedMult) -- delta=0.73
        Turn(pelvis, x_axis, 0.043633, 1.308997 * speedMult) -- delta=2.50
        Turn(pelvis, y_axis, -0.000000, 3.926991 * speedMult) -- delta=7.50
        Turn(rfoot, x_axis, -0.019264, 13.721480 * speedMult) -- delta=26.21
        Turn(rfoot, z_axis, 0.001721, 0.207440 * speedMult) -- delta=0.40
        Turn(rfoot, y_axis, -0.000005, 0.097432 * speedMult) -- delta=0.19
        Turn(rleg, x_axis, -0.103857, 14.416955 * speedMult) -- delta=27.53
        Turn(rthigh, x_axis, 0.082365, 29.423007 * speedMult) -- delta=-56.19
        Turn(rthigh, z_axis, -0.001818, 0.321968 * speedMult) -- delta=0.61
        Turn(rthigh, y_axis, 0.000412, 4.307626 * speedMult) -- delta=-8.23
        Sleep(sleepTime)
        -- Frame:36
        Turn(lfoot, x_axis, 0.386673, 5.454564 * speedMult) -- delta=-10.42
        Turn(lfoot, z_axis, 0.020291, 1.990957 * speedMult) -- delta=-3.80
        Turn(lfoot, y_axis, 0.006228, 0.219566 * speedMult) -- delta=-0.42
        Turn(lleg, x_axis, -0.052934, 18.645597 * speedMult) -- delta=-35.61
        Turn(lthigh, x_axis, -0.549209, 30.794722 * speedMult) -- delta=58.81
        Turn(lthigh, z_axis, -0.007471, 2.661446 * speedMult) -- delta=5.08
        Turn(lthigh, y_axis, -0.051735, 0.209008 * speedMult) -- delta=-0.40
        Move(pelvis, y_axis, 0.000000, 13.500000 * speedMult) -- delta=0.45
        Turn(pelvis, x_axis, -0.000000, 1.308997 * speedMult) -- delta=2.50
        Turn(rfoot, x_axis, -0.665976, 19.401357 * speedMult) -- delta=37.05
        Turn(rfoot, z_axis, 0.018466, 0.502329 * speedMult) -- delta=0.96
        Turn(rfoot, y_axis, -0.009378, 0.281196 * speedMult) -- delta=-0.54
        Turn(rleg, x_axis, 0.298197, 12.061633 * speedMult) -- delta=-23.04
        Turn(rthigh, x_axis, 0.367865, 8.565003 * speedMult) -- delta=-16.36
        Turn(rthigh, z_axis, -0.013571, 0.352596 * speedMult) -- delta=-0.67
        Turn(rthigh, y_axis, 0.002489, 0.062312 * speedMult) -- delta=0.12
        Sleep(sleepTime)
    end
end

local function StopWalking()
    Signal(SIG_WALK)
    SetSignalMask(SIG_WALK)

    local speedMult = 0.5 * GetSpeedParams() -- slower restore speed for last step

    Move(pelvis, y_axis, 0.000000, 54.749997 * speedMult)
    Turn(lfoot, x_axis, 0.000000, 61.510172 * speedMult)
    Turn(lfoot, y_axis, 0.000000, 4.281542 * speedMult)
    Turn(lfoot, z_axis, 0.000000, 7.110463 * speedMult)
    Turn(lleg, x_axis, 0.000000, 85.366233 * speedMult)
    Turn(lthigh, x_axis, 0.000000, 76.986806 * speedMult)
    Turn(lthigh, y_axis, 0.000000, 37.768536 * speedMult)
    Turn(lthigh, z_axis, 0.000000, 35.968458 * speedMult)
    Turn(pelvis, x_axis, 0.000000, 3.272493 * speedMult)
    Turn(pelvis, y_axis, 0.000000, 9.817477 * speedMult)
    Turn(rfoot, x_axis, 0.000000, 61.523507 * speedMult)
    Turn(rfoot, y_axis, 0.000000, 3.072120 * speedMult)
    Turn(rfoot, z_axis, 0.000000, 8.042132 * speedMult)
    Turn(rleg, x_axis, 0.000000, 85.366171 * speedMult)
    Turn(rthigh, x_axis, 0.000000, 83.526541 * speedMult)
    Turn(rthigh, y_axis, 0.000000, 79.850681 * speedMult)
    Turn(rthigh, z_axis, 0.000000, 64.158654 * speedMult)
end

function script.StartMoving()
    if not walking then
        walking = true
        StartThread(Walk)
    end
end

function script.StopMoving()
    walking = false
    StartThread(StopWalking)
end

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
-- END THE WALK SCRIPT
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------