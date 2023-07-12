function gadget:GetInfo()
	return {
		name      = 'Set Seismic Signature on Cloak/Decloak',
		desc      = '',
		author    = '',
		version   = 'v1.0',
		date      = '',
		license   = 'GNU GPL, v2 or later',
		layer     = 0,
		enabled   = true
	}
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return
end
----------------------------------------------------------------
----------------------------------------------------------------

function gadget:UnitCloaked(unitID, unitDefID, unitTeam)
	Spring.SetUnitSeismicSignature(unitID, 0)
end

function gadget:UnitDecloaked(unitID, unitDefID, unitTeam)
	Spring.SetUnitSeismicSignature(unitID, 1)
end