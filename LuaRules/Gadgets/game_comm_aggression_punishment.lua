function gadget:GetInfo()
	return {
		name      = "Commander Aggression Punishment",
		desc      = "Triggers paralyze on the attacking commander. Damage is halved and passed through.",
		author    = "",
		date      = "2025",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local isCommander = {}
for udid, def in pairs(UnitDefs) do
	if def.customParams and def.customParams.unitrole == "Commander" then
		isCommander[udid] = true
	end
end

function gadget:GameFrame(n)

end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if not (attackerID and unitID) then return end
	if attackerID == unitID then return end

	-- Check if both units are commanders
	if (isCommander[unitDefID] and isCommander[attackerDefID]) then

		-- Ignore paralyzer damage (prevents recursion)
		if paralyzer then return end

		-- New aggression instance: punish attacker
		ApplyParalyzeDamage(attackerID, 1000000, unitID)

		--Allow the damage through, but only allow a percentage of remaining health through
		local health = Spring.GetUnitHealth(unitID)
		local adjustedDamage
		if health then
			adjustedDamage = 0.2 * health
		end
		return adjustedDamage
	end
end



function ApplyParalyzeDamage(targetID, damage, attackerID)
	if not targetID then return end
	Spring.AddUnitDamage(targetID, damage, 10, attackerID, -1)
	local x, y, z = Spring.GetUnitPosition(targetID)
	if x then
		Spring.SpawnCEG("genericshellexplosion-electric-large", x, y + 10, z)
		--Spring.PlaySoundFile("feedbackloop", 1)
		--SendToUnsynced("AddNotification", "energyWarning")

	end
end