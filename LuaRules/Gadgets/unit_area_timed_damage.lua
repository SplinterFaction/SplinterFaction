function gadget:GetInfo()
    return {
        name = 'Area Timed Damage Handler',
        desc = '',
        author = 'Damgam (updated by Scary le Poo for damage attribution)',
        version = '1.1',
        date = '2025',
        license = 'GNU GPL, v2 or later',
        layer = 0,
        enabled = true
    }
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- ceg - ceg to spawn when explosion happens
-- damageCeg - ceg to spawn when damage is dealt
-- time - how long the effect should stay
-- damage - damage per second
-- range - from center to edge, in elmos
-- resistance - defines which units are resistant to this type of damage when it matches with 'areadamageresistance' customparameter in a unit.


--[[

areadamage_ceg
areadamage_damageCeg
areadamage_time
areadamage_damage
areadamage_range
areadamage_resistance

]]--

if not gadgetHandler:IsSyncedCode() then
    return
end

local TimedDamageWeapons = {}
local TimedDamageDyingUnits = {}

for unitDefID, unitDef in pairs(UnitDefs) do
    local customParams = unitDef.customParams
    local areaDef = {}

    if customParams.areadamage_ceg then
        areaDef.ceg = customParams.areadamage_ceg
    end
    if customParams.areadamage_damageceg then
        areaDef.damageCeg = customParams.areadamage_damageceg
    end
    if customParams.areadamage_time then
        areaDef.time = tonumber(customParams.areadamage_time)
    end
    if customParams.areadamage_damage then
        areaDef.damage = tonumber(customParams.areadamage_damage)
    end
    if customParams.areadamage_range then
        areaDef.range = tonumber(customParams.areadamage_range)
    end
    if customParams.areadamage_resistance then
        areaDef.resistance = customParams.areadamage_resistance
    end

    if next(areaDef) then
        TimedDamageDyingUnits[unitDefID] = areaDef
    end
end

for weaponDefID, weaponDef in pairs(WeaponDefs) do
    local customParams = weaponDef.customParams
    local areaDef = {}

    if customParams.areadamage_ceg then
        areaDef.ceg = customParams.areadamage_ceg
    end
    if customParams.areadamage_damageceg then
        areaDef.damageCeg = customParams.areadamage_damageceg
    end
    if customParams.areadamage_time then
        areaDef.time = tonumber(customParams.areadamage_time)
    end
    if customParams.areadamage_damage then
        areaDef.damage = tonumber(customParams.areadamage_damage)
    end
    if customParams.areadamage_range then
        areaDef.range = tonumber(customParams.areadamage_range)
    end
    if customParams.areadamage_resistance then
        areaDef.resistance = customParams.areadamage_resistance
    end

    if next(areaDef) then
        TimedDamageWeapons[weaponDefID] = areaDef
    end
end

local aliveExplosions = {}

function gadget:Initialize()
    for id in pairs(TimedDamageWeapons) do
        Script.SetWatchExplosion(id, true)
    end
end

function gadget:Explosion(weaponDefID, px, py, pz, attackerID, projectileID)
    if TimedDamageWeapons[weaponDefID] then
        local currentTime = Spring.GetGameSeconds()
        aliveExplosions[#aliveExplosions + 1] = {
            x = px,
            y = math.max(Spring.GetGroundHeight(px, pz), 0),
            z = pz,
            endTime = currentTime + TimedDamageWeapons[weaponDefID].time,
            damage = TimedDamageWeapons[weaponDefID].damage,
            range = TimedDamageWeapons[weaponDefID].range,
            ceg = TimedDamageWeapons[weaponDefID].ceg,
            cegSpawned = false,
            damageCeg = TimedDamageWeapons[weaponDefID].damageCeg,
            resistance = TimedDamageWeapons[weaponDefID].resistance,
            attacker = attackerID,
        }
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID)
    if TimedDamageDyingUnits[unitDefID] then
        local currentTime = Spring.GetGameSeconds()
        local px, py, pz = Spring.GetUnitPosition(unitID)
        aliveExplosions[#aliveExplosions + 1] = {
            x = px,
            y = math.max(Spring.GetGroundHeight(px, pz), 0),
            z = pz,
            endTime = currentTime + TimedDamageDyingUnits[unitDefID].time,
            damage = TimedDamageDyingUnits[unitDefID].damage,
            range = TimedDamageDyingUnits[unitDefID].range,
            ceg = TimedDamageDyingUnits[unitDefID].ceg,
            cegSpawned = false,
            damageCeg = TimedDamageDyingUnits[unitDefID].damageCeg,
            resistance = TimedDamageDyingUnits[unitDefID].resistance,
            attacker = attackerID,
        }
    end
end

function gadget:GameFrame(frame)
    if frame % 30 == 10 then
        if #aliveExplosions > 0 then
            local safeForCleanup = true
            local currentTime = Spring.GetGameSeconds()
            for i = 1, #aliveExplosions do
                local explosion = aliveExplosions[i]
                if explosion.endTime >= currentTime then
                    safeForCleanup = false

                    local x, y, z = explosion.x, explosion.y, explosion.z
                    if not explosion.cegSpawned then
                        Spring.SpawnCEG(explosion.ceg, x, y + 8, z, 0, 0, 0)
                        explosion.cegSpawned = true
                    end

                    local damage = explosion.damage * 0.733
                    local range = explosion.range
                    local resistance = explosion.resistance
                    local attacker = explosion.attacker

                    local unitsInRange = Spring.GetUnitsInSphere(x, y, z, range)
                    for j = 1, #unitsInRange do
                        local unitID = unitsInRange[j]
                        local unitDefID = Spring.GetUnitDefID(unitID)
                        local ud = UnitDefs[unitDefID]
                        if not ud.canFly and (not (ud.customParams and ud.customParams.areadamageresistance and string.find(ud.customParams.areadamageresistance, resistance))) then
                            Spring.AddUnitDamage(unitID, damage, 0, attacker)
                            local ux, uy, uz = Spring.GetUnitPosition(unitID)
                            Spring.SpawnCEG(explosion.damageCeg, ux, uy + 8, uz, 0, 0, 0)
                        end
                    end

                    local featuresInRange = Spring.GetFeaturesInSphere(x, y, z, range)
                    for j = 1, #featuresInRange do
                        local featureID = featuresInRange[j]
                        local health = Spring.GetFeatureHealth(featureID)
                        local featureDefID = Spring.GetFeatureDefID(featureID)
                        local fd = FeatureDefs[featureDefID]
                        if fd.name ~= "geovent" then
                            if health > damage then
                                Spring.SetFeatureHealth(featureID, health - damage)
                            else
                                Spring.DestroyFeature(featureID)
                            end
                            local ux, uy, uz = Spring.GetFeaturePosition(featureID)
                            Spring.SpawnCEG(explosion.damageCeg, ux, uy + 8, uz, 0, 0, 0)
                        end
                    end
                end
            end

            if aliveExplosions[1] and aliveExplosions[1].endTime < currentTime then
                table.remove(aliveExplosions, 1)
            end

            if #aliveExplosions > 1000 then
                Spring.Echo("TimedDamageExplosionTable Emergency Cleanup")
                table.remove(aliveExplosions, 1)
            end

            if safeForCleanup then
                aliveExplosions = {}
            end
        end
    end
end