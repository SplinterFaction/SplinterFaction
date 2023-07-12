function gadget:GetInfo()
    return {
        name = "Deflect AOE damage to shield",
        desc = "Any damage done to the shield unit will be redirected to the shield until the shield is depleted.",
        author = "",
        date = "2023",
        license = "GNU GPL, v2 or later",
        layer = 0,
        enabled = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID,
                               attackerDefID, attackerTeam)
    local isEnabled, curPower = Spring.GetUnitShieldState(unitID)
    if isEnabled then
        -- Spring.Echo([[Damage is: ]] .. damage)
        -- Spring.Echo([[Current Shield Power is: ]] .. curPower)
        -- so basically if the damage isn't greater than the shield, just subtract from the shield. Otherwise, deplete the shield and add the damage remainder
        local newPower
        if curPower >= damage then
            newPower = curPower - damage
            damage = 0
        else
            newPower = 0
            damage = damage - curPower
        end
            -- Spring.Echo([[New Shield Power is: ]] .. newPower)
            Spring.SetUnitShieldState(unitID, -1, true, newPower)
            return damage, 0
    end
end