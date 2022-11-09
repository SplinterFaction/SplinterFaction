function gadget:GetInfo()
	return {
		name 	= "Shields OnOffable",
		desc	= "Allows shields to be turned on/off",
		author	= "Sprung",
		date	= "2022",
		license	= "Public domain",
		layer	= 0,
		enabled	= true	--	loaded by default?
	}
end

if gadgetHandler:IsSyncedCode() then

	local shieldDefs = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
	  if unitDef.hasShield then
		shieldDefs[unitDefID] = true
	  end
	end

	local shieldUnits = {}
	function gadget:UnitCreated(unitID, unitDefID)
	  if shieldDefs[unitDefID] then
		shieldUnits[unitID] = true
	  end
	end
	function gadget:UnitDestroyed(unitID)
	  shieldUnits[unitID] = nil
	end

	function gadget:GameFrame(n)
	  if n % Game.gameSpeed ~= 0 then
		return
	  end

	  for unitID in pairs(shieldUnits) do
		Spring.SetUnitShieldState(unitID, Spring.GetUnitIsActive(unitID))
	  end
	end
	
end