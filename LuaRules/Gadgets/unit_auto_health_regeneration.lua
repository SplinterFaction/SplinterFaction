function gadget:GetInfo()
	return {
		name      = "Auto Health Regeneration",
		desc      = "Regenerates health when the unit hasn't taken damage for a specified time.",
		author    = "",
		date      = "2025",
		license   = "",
		layer     = -100,
		enabled   = true,
	}
end

--[[
customparams = {
	health_regen_rate = 0.5,  -- Health regenerated per second
	health_regen_delay = 10,  -- Time in seconds the unit needs to be undamaged before regeneration starts
}
--]]

if gadgetHandler:IsSyncedCode() then

	local lastDamageTime = {}
	local regenEnabled = {}

	function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
		local customParams = UnitDefs[unitDefID].customParams
		-- Get the health regen rate and the damage-free duration from the unit's custom parameters
		local regenRate = tonumber(customParams.health_regen_rate) or 0  -- default to 0 if not set
		local regenDelay = tonumber(customParams.health_regen_delay) or 5  -- default to 5 seconds if not set

		-- Initialize the tracking tables
		lastDamageTime[unitID] = Spring.GetGameFrame()
		regenEnabled[unitID] = (regenRate > 0 and regenDelay > 0)
	end

	function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
		if regenEnabled[unitID] then
			-- Reset the last damage time to stop regeneration
			lastDamageTime[unitID] = Spring.GetGameFrame()
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, teamID)
		-- Remove the unit from tracking tables when it's destroyed
		lastDamageTime[unitID] = nil
		regenEnabled[unitID] = nil
	end

	function gadget:GameFrame(frame)
		if frame%30 == 17 then --1 second, on frame 17 of a 30 frame cycle (30 frames per second)
			for unitID, lastDamageFrame in pairs(lastDamageTime) do
				local customParams = UnitDefs[Spring.GetUnitDefID(unitID)].customParams
				local regenRate = tonumber(customParams.health_regen_rate) or 0
				local regenDelay = tonumber(customParams.health_regen_delay) or 5

				-- Check if the unit has not taken damage for 'y' seconds
				if regenEnabled[unitID] and (frame - lastDamageFrame) >= (regenDelay * 30) then
					-- Regenerate health
					local currentHealth, maxHealth = Spring.GetUnitHealth(unitID)
					local newHealth = math.min(currentHealth + regenRate, maxHealth)  -- Cap health to max
					--Spring.Echo("Unit's ID: " .. unitID)
					--Spring.Echo("Unit's current health: " .. currentHealth)
					--Spring.Echo("Health Regeneration Rate: " .. regenRate)
					--Spring.Echo("Maximum health amount: " .. maxHealth)
					--Spring.Echo("New health amount: " .. newHealth)
					Spring.SetUnitHealth(unitID, newHealth)
				end
			end
		end
	end

end