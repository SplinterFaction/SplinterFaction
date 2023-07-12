function gadget:GetInfo()
	return {
		name      = "Linear EdgeEffectiveness",
		desc      = "Makes AOE damage fall off linearly between 0 and 1",
		author    = "Sprung",
		date      = "Does it matter?",
		license   = "GNU GPL, v2 or later",
		layer     = -999,
		enabled   = true  --  loaded by default?
	}
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if weaponDefID <= 0 then
		return damage -- environmental damage, no weapondef entry
	end

	-- Spring.Echo([[[Linear EdgeEffectiveness] Damage is ]] .. damage)

	local weaponDef = WeaponDefs[weaponDefID]
	local ee = weaponDef.edgeEffectiveness
	-- Spring.Echo([[[Linear EdgeEffectiveness] edgeEffectiveness is ]] .. ee)
	if ee == 1 then
		return damage -- already desired behaviour and would else crash due to div0
	end

	local baseDamage = weaponDef.damages[UnitDefs[unitDefID].armorType]
	if baseDamage == 0 then
		return 0
	end

	local isArmored, armorMult = Spring.GetUnitArmored(unitID)
	if isArmored then
		if armorMult == 0 then
			return 0
		end
		baseDamage = baseDamage * armorMult
	end

	-- local aoe = weaponDef.damageAreaOfEffect
	local fraction = damage / baseDamage
	-- Spring.Echo([[[Linear EdgeEffectiveness] fraction is ]] .. fraction)
	local distance = (1 - fraction) / (1 - fraction*ee)
	-- Spring.Echo([[[Linear EdgeEffectiveness] distance is ]] .. distance)

	local enddamage = baseDamage * (1 - distance*(1 - ee))
	-- Spring.Echo([[[Linear EdgeEffectiveness] baseDamage is ]] .. enddamage)
	return baseDamage * (1 - distance*(1 - ee))
end
