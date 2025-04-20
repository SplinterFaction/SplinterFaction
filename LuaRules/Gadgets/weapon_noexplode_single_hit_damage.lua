function gadget:GetInfo()
	return {
		name      = "Weapon Single Hit Damage",
		desc      = "Ensures weapons with noexplode and single_hit deal full damage only once per projectile.",
		author    = "",
		date      = "2025",
		license   = "MIT",
		layer     = -100,
		enabled   = true
	}
end

--[[

To use this, just make sure that the weapon has noExplode set to true and in the WEAPON CUSTOMPARAMS set single_hit = "true",

Example:
		customparams              = {
			expl_light_color	= green, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
			expl_light_opacity  = 0.25, -- Use this sparingly
			single_hit          = "true",
		},

***NOTE*** the "" around true are very important. Customparams are strings, so if you try to make it work like a bool by just having single_hit = true, it will not work.

--]]

local weaponHits = {}

function gadget:Initialize()
	-- Initialize a table to track weapons and their 'single_hit' custom param
	weaponHits = {}

	for weaponDefID, weaponDef in pairs(WeaponDefs) do
		if weaponDef.noExplode == true then
			if weaponDef.customParams and weaponDef.customParams.single_hit == "true" then
				weaponHits[weaponDefID] = {}
			end
		end
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)

	-- Check if the weapon has 'noexplode' and 'single_hit' set to true
	--Spring.Echo("The weapon id that will deal damage is " .. weaponDefID)
	if weaponHits[weaponDefID] then
		if not weaponHits[weaponDefID][projectileID] then
			weaponHits[weaponDefID][projectileID] = {}
		end

		-- Ensure the unit has not been hit by this projectile yet
		if not weaponHits[weaponDefID][projectileID][unitID] then
			-- Track that this unit has been hit by this projectile
			weaponHits[weaponDefID][projectileID][unitID] = true
			-- Return the damage normally
			--Spring.Echo("Projectile " .. projectileID .. " hitting unit " .. unitID .. " for full damage: " .. damage)
			return damage
		else
			-- If it's already been hit by this projectile, return 0 damage
			--Spring.Echo("No damage to unit " .. unitID .. " from projectile " .. projectileID .. " (already hit)")
			return 0
		end
	end

	-- If not a relevant weapon, return the damage as normal
	return damage
end

function gadget:GameFrame(frame)
	-- Not needed in this case, leaving empty for now
end
