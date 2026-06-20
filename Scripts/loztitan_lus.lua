
base, engine1, engine2, engine3, engine4, engine5, engine6, engine7, engine8, turretball1, turretball2, turretball3, turretball4, turretball5, turretball6, turretball7, turretball8, turretball9, turretball10, link = piece ('base', 'engine1', 'engine2', 'engine3', 'engine4', 'engine5', 'engine6', 'engine7', 'engine8', 'turretball1', 'turretball2', 'turretball3', 'turretball4', 'turretball5', 'turretball6', 'turretball7', 'turretball8', 'turretball9', 'turretball10', 'link')

local deathPieces = {
	base, engine1, engine2, engine3, engine4, engine5, engine6, engine7, engine8, turretball1, turretball2, turretball3, turretball4, turretball5, turretball6, turretball7, turretball8, turretball9, turretball10, link,
}

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

local firepoints = {turretball1, turretball2, turretball3, turretball4, turretball5, turretball6, turretball7, turretball8, turretball9, turretball10}
local currentFirepoint = 1
local totalNumberofFirepoints = 10

function script.QueryWeapon(weaponID)
    return firepoints[currentFirepoint]
end

function script.FireWeapon(weaponID)
    currentFirepoint = currentFirepoint + 1
    if currentFirepoint == (totalNumberofFirepoints + 1) then -- when currentFirepoint gets to one more than the total number of firepoints, reset it to 1
        currentFirepoint = 1
    end
    -- Spring.Echo(currentFirepoint)
    -- EmitSfx (firepoints[currentFirepoint], 1024)
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
	common.ExplodePieces(deathPieces)
	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end