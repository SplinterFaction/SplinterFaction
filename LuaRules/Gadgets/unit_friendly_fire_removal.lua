function gadget:GetInfo()
	return {
		name      = "Friendly Fire Removal",
		desc      = "Removes friendly fire unless the weapon has a custom param that allows it.",
		author    = "",
		date      = "",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

if gadgetHandler:IsSyncedCode() then
	-- This block runs only in the synced code, i.e., on the server side

	function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
		local weaponDef = WeaponDefs[weaponDefID]
		-- Check if the attacker and the unit being damaged are on the same team (friendly fire)
		--Spring.Echo("Checking to see if this damage should be applied!")
		--Spring.Echo("unitTeam " .. unitTeam)
		--Spring.Echo("attackerTeam " .. attackerTeam)
		if unitTeam == attackerTeam then
			--Spring.Echo("The units are on the same team!")
			-- Get the weapon's customparams to determine if friendly fire is allowed
			if weaponDef.customParams and weaponDef.customParams.friendlyfire then
				if weaponDef.customParams.friendlyfire == "true" then
					--Spring.Echo("Friendly fire is allowed in this case, applying damage!")
					return damage
				end
			else
				--Spring.Echo("Friendly fire is not allowed in this case, removing damage!")
				return 0
			end
		end

		-- Return the original damage if friendly fire is allowed or it's not friendly fire

	end
end
