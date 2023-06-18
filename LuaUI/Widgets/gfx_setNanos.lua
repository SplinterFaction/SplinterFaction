--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function widget:GetInfo()
    return {
        name      = "Gfx - Set Nanos",
        desc      = "Sets nano particles rotation parameters",
        author    = "MaDDoX",
        date      = "Aug 2021",
        license   = "GNU GPL, v2 or later",
        version   = 1,
        layer     = -100,
        enabled   = true  --  loaded by default?
    }
end

function widget:Initialize()
    if Spring.SetNanoProjectileParams then --checking if it has support for the command
        Spring.Echo("Setting Nano Projectile rotation Params")
        Spring.SetNanoProjectileParams(0.5, 0, 0.5)  -- speed, accel, startRot |deg/s, deg/s2, deg|
        --rotVal0, rotVel0, rotAcc
    end
end



