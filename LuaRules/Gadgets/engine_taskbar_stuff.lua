--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "Engine Taskbar Stuff",
		desc      = 'Icon, name',
		author    = "KingRaptor",
		date      = "13 July 2011",
		license   = "Public Domain",
		layer     = -math.huge,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if (gadgetHandler:IsSyncedCode()) then
	return false  --  silent removal
end

function gadget:Initialize()
	-- not putting the version allows detection
	-- by external programs, such as Discord
	Spring.SetWMCaption("SplinterFaction", "SplinterFaction")

	Spring.SetWMIcon("LuaUI/Images/sflogo.png")

	gadgetHandler:RemoveGadget()
end
