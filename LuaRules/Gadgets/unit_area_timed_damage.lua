function gadget:GetInfo()
	return {
		name = 'Area Timed Damage Handler',
		desc = '',
		author = 'Damgam',
		version = '1.0',
		date = '2022',
		license = 'GNU GPL, v2 or later',
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
    return
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
areadamage_reistance

]]--


local TimedDamageWeapons = {}
local TimedDamageDyingUnits = {}

for unitDefID, unitDef in pairs(UnitDefs) do
    if unitDef.customParams.areadamage_ceg then
        TimedDamageDyingUnits[unitDefID].ceg = unitDef.customParams.areadamage_ceg
    end
    if unitDef.customParams.areadamage_damageCeg then
        TimedDamageDyingUnits[unitDefID].damageCeg = unitDef.customParams.areadamage_damageCeg
    end
    if unitDef.customParams.areadamage_time then
        TimedDamageDyingUnits[unitDefID].time = unitDef.customParams.areadamage_time
    end
    if unitDef.customParams.areadamage_damage then
        TimedDamageDyingUnits[unitDefID].damage = unitDef.customParams.areadamage_damage
    end
    if unitDef.customParams.areadamage_range then
        TimedDamageDyingUnits[unitDefID].range = unitDef.customParams.areadamage_range
    end
    if unitDef.customParams.areadamage_reistance then
        TimedDamageDyingUnits[unitDefID].resistance = unitDef.customParams.areadamage_reistance
    end
end

for weaponDefID, weaponDef in pairs(WeaponDefs) do
    if weaponDef.customParams.areadamage_ceg then
        TimedDamageWeapons[weaponDefID].ceg = weaponDef.customParams.areadamage_ceg
    end
    if weaponDef.customParams.areadamage_damageCeg then
        TimedDamageWeapons[weaponDefID].damageCeg = weaponDef.customParams.areadamage_damageCeg
    end
    if weaponDef.customParams.areadamage_time then
        TimedDamageWeapons[weaponDefID].time = weaponDef.customParams.areadamage_time
    end
    if weaponDef.customParams.areadamage_damage then
        TimedDamageWeapons[weaponDefID].damage = weaponDef.customParams.areadamage_damage
    end
    if weaponDef.customParams.areadamage_range then
        TimedDamageWeapons[weaponDefID].range = weaponDef.customParams.areadamage_range
    end
    if weaponDef.customParams.areadamage_reistance then
        TimedDamageWeapons[weaponDefID].resistance = weaponDef.customParams.areadamage_reistance
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------

local aliveExplosions = {}

function gadget:Initialize()
    for id, a in pairs(TimedDamageWeapons) do 
        Script.SetWatchExplosion(id, true)
    end
end

function gadget:Explosion(weaponDefID, px, py, pz, AttackerID, ProjectileID)
    if TimedDamageWeapons[weaponDefID] then
        local currentTime = Spring.GetGameSeconds()
        aliveExplosions[#aliveExplosions+1] = { 
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
        }
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
    if TimedDamageDyingUnits[unitDefID] then
        local currentTime = Spring.GetGameSeconds()
        local px, py, pz = Spring.GetUnitPosition(unitID)
        aliveExplosions[#aliveExplosions+1] = { 
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
        }
    end
end

function gadget:GameFrame(frame)
    if frame%30 == 10 then
        if #aliveExplosions > 0 then
            local safeForCleanup = true
            local currentTime = Spring.GetGameSeconds()
            for i = 1,#aliveExplosions do
                if aliveExplosions[i].endTime >= currentTime then
                    safeForCleanup = false
                    
                    local x = aliveExplosions[i].x
                    local z = aliveExplosions[i].z
                    local y = aliveExplosions[i].y or Spring.GetGroundHeight(x,z)
                    
                    if aliveExplosions[i].cegSpawned == false then
                        Spring.SpawnCEG(aliveExplosions[i].ceg, x, y + 8, z, 0, 0, 0)
                        aliveExplosions[i].cegSpawned = true
                    end
                    
                    local damage = aliveExplosions[i].damage*0.733
                    local range = aliveExplosions[i].range
                    local resistance = aliveExplosions[i].resistance

                    local unitsInRange = Spring.GetUnitsInSphere(x, y, z, range)
                    for j = 1,#unitsInRange do
                        local unitID = unitsInRange[j]
                        local unitDefID = Spring.GetUnitDefID(unitID)
                        if (not UnitDefs[unitDefID].canFly) and (not (UnitDefs[unitDefID].customParams and UnitDefs[unitDefID].customParams.areadamageresistance and string.find(UnitDefs[unitDefID].customParams.areadamageresistance, resistance))) then
                            local health = Spring.GetUnitHealth(unitID)
                            if health > damage then
                                Spring.SetUnitHealth(unitID, health - damage)
                            else
                                Spring.DestroyUnit(unitID, false, false)
                            end
                            local ux, uy, uz = Spring.GetUnitPosition(unitID)
                            Spring.SpawnCEG(aliveExplosions[i].damageCeg, ux, uy + 8, uz, 0, 0, 0)
                        end
                    end

                    local featuresInRange = Spring.GetFeaturesInSphere(x, y, z, range)
                    for j = 1,#featuresInRange do
                        local featureID = featuresInRange[j]
                        local health = Spring.GetFeatureHealth(featureID)
                        if health > damage then
                            Spring.SetFeatureHealth(featureID, health - damage)
                        else
                            Spring.DestroyFeature(featureID)
                        end
                        local ux, uy, uz = Spring.GetFeaturePosition(featureID)
                        Spring.SpawnCEG(aliveExplosions[i].damageCeg, ux, uy + 8, uz, 0, 0, 0)
                    end
                end
            end
           
            if aliveExplosions[1].endTime < currentTime then -- The oldest explosion is outdated, it's safe to remove it
                table.remove(aliveExplosions, 1)
            end

            if #aliveExplosions > 1000 then -- There's too many explosions! Most likely something went wrong, cleaning up the oldest explosion to save memory.
                Spring.Echo("TimedDamageExplosionTable Emergency Cleanup")
                table.remove(aliveExplosions, 1)
            end

            if safeForCleanup then -- No explosions are alive, we can safely clear the table without messing with table functions
                aliveExplosions = {}
            end
        end
    end
end