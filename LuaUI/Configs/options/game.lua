--------------------------------------------------------------------------------
-- Game tab: gameplay automation and helpers
--------------------------------------------------------------------------------

local function ApplyNetworkSmoothing(v)
	Spring.SetConfigInt("sf_useNetworkSmoothing", v and 1 or 0)
	if v then
		Spring.SetConfigInt("UseNetMessageSmoothingBuffer", 1)
		Spring.SetConfigInt("NetworkLossFactor", 0)
	else
		Spring.SetConfigInt("UseNetMessageSmoothingBuffer", 0)
		Spring.SetConfigInt("NetworkLossFactor", 2)
	end
end

return {
	id = "game", name = "Game", order = 50,
	options = {
		{ type = "separator", name = "Network" },
		{ id = "networksmoothing", name = "Network smoothing", type = "bool", restart = true,
		  get = function() return Spring.GetConfigInt("sf_useNetworkSmoothing", 1) == 1 end,
		  set = ApplyNetworkSmoothing,
		  desc = "Adds a steady half-second delay to commands so an unstable connection feels consistent instead of choppy. Turn off on a good connection to remove the delay." },

		{ type = "separator", name = "Selection" },
		{ id = "smartselect", name = "Smart area selection", type = "bool", widget = "SmartSelect", requires = "SmartSelect",
		  desc = "Drag-selecting prefers mobile units over structures.",
		  children = {
			{ id = "smartselectbuildings", name = "Include structures", type = "bool", api = {"smartselect", "getIncludeBuildings", "setIncludeBuildings"}, configVar = {"SmartSelect", "selectBuildingsWithMobile"}, default = false },
			{ id = "smartselectbuilders", name = "Include builders", type = "bool", api = {"smartselect", "getIncludeBuilders", "setIncludeBuilders"}, configVar = {"SmartSelect", "includeBuilders"}, default = true,
			  desc = "Only matters while structures are excluded." },
		  } },
		{ id = "ctrldequeue", name = "Ctrl removes from factory queue", type = "bool", config = "evo_ctrl_dequeue" },
		{ id = "highlightbuilders", name = "Highlight builders on hover", type = "bool", config = "evo_active_highlight_builders", requires = "Constructor locater",
		  desc = "All builders flash when you hover one. Space does the same on demand.",
		  onSet = function()
			-- the locater reads the config var at load, so bounce it
			if OPT.widgetActive("Constructor locater") then
				widgetHandler:DisableWidget("Constructor locater")
				widgetHandler:EnableWidget("Constructor locater")
			end
		  end },
		{ id = "selectandcenter", name = "Select commander at start", type = "bool", widget = "Select n Center!", requires = "Select n Center!" },
		{ id = "keepmorphedselected", name = "Keep morphed units selected", type = "bool", widget = "Keep Morpheds Selected", requires = "Keep Morpheds Selected" },

		{ type = "separator", name = "Automation" },
		{ id = "autogroup", name = "Auto groups", type = "bool", widget = "Auto Group", requires = "Auto Group",
		  desc = "Alt+number assigns a unit type to a group; new units of that type join it automatically.",
		  children = {
			{ id = "autogroupimmediate", name = "Add units immediately", type = "bool", api = {"autogroup", "getImmediate", "setImmediate"}, default = false,
			  desc = "Otherwise units join their group when they first go idle." },
		  } },
		{ id = "autogroupcom", name = "Commander in group", type = "bool", widget = "Auto Group Com", requires = "Auto Group Com" },
		{ id = "airalwaysfly", name = "Aircraft always fly", type = "bool", widget = "Aircraft on Always Fly Mode", requires = "Aircraft on Always Fly Mode" },
		{ id = "holdfire", name = "Auto hold fire", type = "bool", widget = "Set Unit to Hold Fire", requires = "Set Unit to Hold Fire",
		  desc = "Certain units are set to hold fire when built." },
		{ id = "loadownmoving", name = "Load own moving units", type = "bool", widget = "Load Own Moving", requires = "Load Own Moving" },
		{ id = "immobilebuilder", name = "Immobile builders patrol", type = "bool", widget = "ImmobileBuilder", requires = "ImmobileBuilder",
		  desc = "Nanos and other static builders are set to roam with a patrol order." },
		{ id = "improvedmetalmakers", name = "Metal maker control", type = "bool", widget = "Improved MetalMakers", requires = "Improved MetalMakers",
		  desc = "Turns metal makers on and off with your energy income." },
		{ id = "stallassist", name = "Stall assist", type = "bool", widget = "Stall Assist", requires = "Stall Assist",
		  desc = "Shares spare energy to allies who are stalling." },
		{ id = "dontmoveeverything", name = "Skip structures in select-all", type = "bool", widget = "Don't Move Everything", requires = "Don't Move Everything" },
		{ id = "mexsnapping", name = "Snap extractors to spots", type = "bool", widget = "Metal Maker Placement Snapping", requires = "Metal Maker Placement Snapping" },
		{ id = "togglelos", name = "LOS view at start", type = "bool", widget = "Toggle LOS", requires = "Toggle LOS" },
		{ id = "techupgradebutton", name = "Tech upgrade button", type = "bool", widget = "Tech Upgrade Button", requires = "Tech Upgrade Button" },

		{ type = "separator", name = "Map" },
		{ id = "metalspots", name = "Metal spot markers", type = "bool", widget = "Metal Spot Drawer", requires = "Metal Spot Drawer" },
		{ id = "metalspotsminimap", name = "Metal spots on minimap", type = "bool", widget = "Metal Maker Spot Drawer (Minimap)", requires = "Metal Maker Spot Drawer (Minimap)" },
		{ id = "geospots", name = "Geovent markers", type = "bool", widget = "Geovent Spot Drawer", requires = "Geovent Spot Drawer" },
		{ id = "geospotsminimap", name = "Geovents on minimap", type = "bool", widget = "Geovent Spot Drawer (Minimap)", requires = "Geovent Spot Drawer (Minimap)" },
		{ id = "startradius", name = "Commander start radius", type = "bool", widget = "StartRadius", requires = "StartRadius" },
	},
}
