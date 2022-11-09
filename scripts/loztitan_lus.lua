
base, engine1, engine2, engine3, engine4, engine5, engine6, engine7, engine8, turretball1, turretball2, turretball3, turretball4, turretball5, turretball6, turretball7, turretball8, turretball9, turretball10, link = piece ('base', 'engine1', 'engine2', 'engine3', 'engine4', 'engine5', 'engine6', 'engine7', 'engine8', 'turretball1', 'turretball2', 'turretball3', 'turretball4', 'turretball5', 'turretball6', 'turretball7', 'turretball8', 'turretball9', 'turretball10', 'link')

common = include("headers/common_includes_lus.lua")

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function script.Create()
    StartThread(common.SmokeUnit, {base, engine1, engine2, engine3, engine4, engine5, engine6, engine7, engine8, turretball1, turretball2, turretball3, turretball4, turretball5, turretball6, turretball7, turretball8, turretball9, turretball10, link })
end

function script.StartMoving()
    isMoving = true
end

function script.StopMoving()
    isMoving = false
end


function script.AimFromWeapon(weaponID)
    --Spring.Echo("AimFromWeapon: FireWeapon")
    return base
end



function script.QueryWeapon(weaponID)
    if weaponID == 1 then
        return turretball1
    elseif weaponID == 2 then
        return turretball2
    elseif weaponID == 3 then
        return turretball3
    elseif weaponID == 4 then
        return turretball4
    elseif weaponID == 5 then
        return turretball5
    elseif weaponID == 6 then
        return turretball6
    elseif weaponID == 7 then
        return turretball7
    elseif weaponID == 8 then
        return turretball8
    elseif weaponID == 9 then
        return turretball9
    elseif weaponID == 10 then
        return turretball10
    end
end

function script.FireWeapon(weaponID)
    if WeaponID == 9 then
        EmitSfx (turretball9, 1024)
    elseif WeaponID == 10 then
        EmitSfx (turretball10, 1024)
    end
end

function script.AimWeapon(weaponID, heading, pitch)

    --Spring.Echo("AimWeapon: FireWeapon")
    return true
end


function script.BeginTransport(passengerID)
    local unitHeight = Spring.GetUnitHeight(passengerID)
    Move(link, y_axis, -unitHeight, 500)
end

function script.QueryTransport()
    return link
end

function script.EndTransport(passengerID)
    Move(link, y_axis, 0, 500)
end

function script.Killed()
    Explode(base, SFX.EXPLODE_ON_HIT)
    Explode(turretball1, SFX.EXPLODE_ON_HIT)
    Explode(turretball2, SFX.EXPLODE_ON_HIT)
    Explode(turretball3, SFX.EXPLODE_ON_HIT)
    Explode(turretball4, SFX.EXPLODE_ON_HIT)
    Explode(turretball5, SFX.EXPLODE_ON_HIT)
    Explode(turretball6, SFX.EXPLODE_ON_HIT)
    Explode(turretball7, SFX.EXPLODE_ON_HIT)
    Explode(turretball8, SFX.EXPLODE_ON_HIT)
    Explode(turretball9, SFX.EXPLODE_ON_HIT)
    Explode(turretball10, SFX.EXPLODE_ON_HIT)

    return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end