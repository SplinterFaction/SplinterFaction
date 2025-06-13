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
		-- Check if the attacker and the unit being damaged are on the same team (friendly fire)
		--Spring.Echo("Checking to see if this damage should be applied!")
		--Spring.Echo("unitTeam " .. unitTeam)
		--Spring.Echo("attackerTeam " .. attackerTeam)
		if attackerTeam and unitTeam == attackerTeam then
			--Spring.Echo("The units are on the same team!")
			-- Get the weapon's customparams to determine if friendly fire is allowed
			local weaponDef = WeaponDefs[weaponDefID]
			if weaponDef and weaponDef.customParams and weaponDef.customParams.friendlyfire == "true" then
				return damage
			end
			return 0 -- block friendly fire if not allowed
		end
		-- Return the original damage if friendly fire is allowed or it's not friendly fire
		return damage
	end
end
