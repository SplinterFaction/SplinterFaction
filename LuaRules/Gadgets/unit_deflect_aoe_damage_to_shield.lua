function gadget:GetInfo()
    return {
        name = "Deflect AOE damage to shield",
        desc = "",
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

-- This doesn't work because clearly I don't know how to properly use SetUnitShieldState and negate damage.
-- While this is a shitty workaround, it actually would enable some interesting behavior, namely, any damage done to the unit would be peeled off of the shield first and only after the shield is depleted would it start dealing damage to the unit. Where this gets even more interesting is that you could use this to have a protected zone inside a dome shield where literally nothing under it would get damaged until the shield went down.

-- This approach also has some obvious issues as well. If you have 2 units under the shield and the both take aoe damage, that damage would essentially get added up and applied to the shield. So yes, this approach isn't without it's not-insignificant issues, but the idea has some promise.


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
    --local name = UnitDefs[unitDefID].name
    --Spring.Echo(name .. [[ ]] .. weaponID)
end