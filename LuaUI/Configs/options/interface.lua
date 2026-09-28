--------------------------------------------------------------------------------
-- Interface tab
--------------------------------------------------------------------------------

-- Fonts found in LuaUI/fonts, for the font pickers
local fontNames, fontFiles = {}, {}
do
	local seen = {}
	local files = VFS.DirList(LUAUI_DIRNAME .. "fonts", "*") or {}
	table.sort(files)
	for i = 1, #files do
		local file = files[i]:match("[^/\\]+$") or files[i]
		local ext = file:sub(-3):lower()
		if ext == "ttf" or ext == "otf" then
			local name = file:sub(1, -5)
			if not seen[name:lower()] then
				seen[name:lower()] = true
				fontNames[#fontNames + 1] = name
				fontFiles[#fontFiles + 1] = file
			end
		end
	end
end

local function FontIndex(configKey)
	local cur = Spring.GetConfigString(configKey, "Saira_SemiCondensed-SemiBold.ttf"):lower()
	for i = 1, #fontFiles do
		if fontFiles[i]:lower() == cur then return i end
	end
	return 1
end

return {
	id = "ui", name = "Interface", order = 20,
	options = {
		{ type = "separator", name = "General" },
		{ id = "guiopacity", name = "Panel opacity", type = "slider", min = 0.2, max = 1, step = 0.01, config = "ui_opacity",
		  desc = "Background opacity of the interface panels." },
		{ id = "guishader", name = "Blur behind panels", type = "bool", widget = "GUI Shader", requires = "GUI Shader",
		  children = {
			{ id = "guishaderintensity", name = "Blur strength", type = "slider", min = 0.001, max = 0.004, step = 0.0001, format = "%.4f",
			  api = {"guishader", "getBlurIntensity", "setBlurIntensity"}, configVar = {"GUI Shader", "blurIntensity"} },
		  } },
		{ id = "font", name = "Font", type = "select", options = fontNames, reloadUI = true, showIf = function() return #fontNames > 1 end,
		  get = function() return FontIndex("ui_font") end,
		  set = function(idx) Spring.SetConfigString("ui_font", fontFiles[idx]) end,
		  desc = "Body font. Reloads the interface." },
		{ id = "font2", name = "Heading font", type = "select", options = fontNames, reloadUI = true, showIf = function() return #fontNames > 1 end,
		  get = function() return FontIndex("ui_font2") end,
		  set = function(idx) Spring.SetConfigString("ui_font2", fontFiles[idx]) end,
		  desc = "Font for names, buttons and titles. Reloads the interface." },
		{ id = "tooltips", name = "Tooltips", type = "bool", widget = "Static Tooltip Panel", requires = "Static Tooltip Panel" },
		{ id = "resourceprompts", name = "Resource warnings", type = "bool", config = "evo_resourceprompts",
		  desc = "Chat messages and audio cues when metal or energy needs attention." },
		{ id = "pausescreen", name = "Pause overlay", type = "bool", widget = "Pause Screen", requires = "Pause Screen" },
		{ id = "simpleminimapcolors", name = "Simple minimap colors", type = "bool", config = "SimpleMiniMapColors", cmd = "minimap simplecolors %d",
		  desc = "Green is you, blue is allied, red is enemy." },

		{ type = "separator", name = "Build menu" },
		{ id = "showcost", name = "Show unit cost", type = "bool", config = "evo_showcost",
		  onSet = function() if WG.buildOrderUI then WG.buildOrderUI.updateConfigInt = true end end },
		{ id = "showtechreq", name = "Show tech requirement", type = "bool", config = "evo_showtechreq",
		  onSet = function() if WG.buildOrderUI then WG.buildOrderUI.updateConfigInt = true end end },
		{ id = "showhotkeys", name = "Show hotkeys", type = "bool", config = "evo_showhotkeys",
		  onSet = function() if WG.buildOrderUI then WG.buildOrderUI.updateConfigInt = true end end },
		{ id = "oldunitpics", name = "Old style unit pictures", type = "bool", requires = "Static Selected Units Buttons",
		  api = {"selunitbuttons", "getOldUnitIcons", "setOldUnitIcons"}, default = false },

		{ type = "separator", name = "Units" },
		{ id = "healthbars", name = "Health bars", type = "bool", widget = "Health Bars GL4", requires = "Health Bars GL4",
		  children = {
			{ id = "healthbarscale", name = "Scale", type = "slider", min = 0.7, max = 1.5, step = 0.05, api = {"healthbars", "getScale", "setScale"}, configVar = {"Health Bars GL4", "barScale"}, default = 1 },
			{ id = "healthbarvariable", name = "Size by unit", type = "bool", api = {"healthbars", "getVariableSizes", "setVariableSizes"}, configVar = {"Health Bars GL4", "variableBarSizes"},
			  desc = "Bigger units get bigger bars." },
			{ id = "healthbarhidden", name = "Show when GUI hidden", type = "bool", api = {"healthbars", "getDrawWhenGuiHidden", "setDrawWhenGuiHidden"}, configVar = {"Health Bars GL4", "drawWhenGuiHidden"} },
		  } },
		{ id = "heatbars", name = "Heat bars", type = "bool", widget = "Unit Heat Bars", requires = "Unit Heat Bars" },
		{ id = "disruptionbars", name = "Disruption bars", type = "bool", widget = "Unit Disruption Bars", requires = "Unit Disruption Bars" },
		{ id = "uniticons", name = "Unit status icons", type = "bool", widget = "Unit Icons", requires = "Unit Icons" },
		{ id = "armoricons", name = "Armor class icons", type = "bool", widget = "Armor Icons", requires = "Armor Icons" },
		{ id = "selfdicons", name = "Self-destruct icons", type = "bool", widget = "Self-Destruct icons", requires = "Self-Destruct icons" },
		{ id = "givenunits", name = "Given unit markers", type = "bool", widget = "Given Units", requires = "Given Units" },
		{ id = "resourcedrain", name = "Resource drain numbers", type = "bool", widget = "Unit Resource Drain Numbers", requires = "Unit Resource Drain Numbers" },
		{ id = "displaydps", name = "Floating damage numbers", type = "bool", widget = "Display DPS", requires = "Display DPS" },
		{ id = "damagecursortip", name = "Damage at cursor", type = "bool", widget = "Damage Cursor Tip v2", requires = "Damage Cursor Tip v2" },
		{ id = "combatpower", name = "Combat power display", type = "bool", widget = "Combat Power Display", requires = "Combat Power Display" },
		{ id = "worldlabels", name = "World labels", type = "bool", widget = "World Labels", requires = "World Labels" },
		{ id = "ghostradar", name = "Ghost radar blips", type = "bool", widget = "Ghost Radar", requires = "Ghost Radar" },

		{ type = "separator", name = "Selection" },
		{ id = "fancyselectedunits", name = "Selection platters", type = "bool", widget = "Fancy Selected Units", requires = "Fancy Selected Units",
		  desc = "Draws a platter under selected units. Heavy with large selections.",
		  children = {
			{ id = "fancyselopacity", name = "Line opacity", type = "slider", min = 0.3, max = 1, step = 0.01, api = {"fancyselectedunits", "getOpacity", "setOpacity"}, configVar = {"Fancy Selected Units", "spotterOpacity"} },
			{ id = "fancyselbase", name = "Base opacity", type = "slider", min = 0, max = 0.5, step = 0.01, api = {"fancyselectedunits", "getBaseOpacity", "setBaseOpacity"}, configVar = {"Fancy Selected Units", "baseOpacity"} },
			{ id = "fancyselteam", name = "Team color amount", type = "slider", min = 0, max = 1, step = 0.01, api = {"fancyselectedunits", "getTeamcolorOpacity", "setTeamcolorOpacity"}, configVar = {"Fancy Selected Units", "teamcolorOpacity"} },
		  } },
		{ id = "highlightselunits", name = "Highlight selected units", type = "bool", widget = "Highlight Selected Units", requires = "Highlight Selected Units",
		  children = {
			{ id = "highlightselopacity", name = "Opacity", type = "slider", min = 0.05, max = 0.4, step = 0.01, api = {"highlightselunits", "getOpacity", "setOpacity"}, configVar = {"Highlight Selected Units", "highlightAlpha"} },
			{ id = "highlightselshader", name = "Edge shader", type = "bool", api = {"highlightselunits", "getShader", "setShader"}, configVar = {"Highlight Selected Units", "useHighlightShader"} },
			{ id = "highlightselteam", name = "Use team color", type = "bool", api = {"highlightselunits", "getTeamcolor", "setTeamcolor"}, configVar = {"Highlight Selected Units", "useTeamcolor"} },
		  } },
		{ id = "highlightunit", name = "Highlight unit under cursor", type = "bool", widget = "Highlight Unit", requires = "Highlight Unit" },
		{ id = "commandsfx", name = "Command lines", type = "bool", widget = "Commands FX", requires = "Commands FX",
		  desc = "Shows order lines when you and your allies give commands.",
		  children = {
			{ id = "commandsfxopacity", name = "Opacity", type = "slider", min = 0.2, max = 1, step = 0.05, api = {"commandsfx", "getOpacity", "setOpacity"}, configVar = {"Commands FX", "opacity"} },
			{ id = "commandsfxfilterai", name = "Hide AI team orders", type = "bool", api = {"commandsfx", "getFilterAI", "setFilterAI"}, configVar = {"Commands FX", "filterAIteams"} },
		  } },
		{ id = "rangeoverview", name = "Range overview", type = "bool", widget = "Range Overview GL4", requires = "Range Overview GL4" },
		{ id = "attackaoe", name = "Attack area of effect", type = "bool", widget = "Attack AoE", requires = "Attack AoE" },
		{ id = "buildeta", name = "Build ETA", type = "bool", widget = "BuildETA", requires = "BuildETA" },
		{ id = "buildinggrid", name = "Building grid", type = "bool", widget = "Building Grid GL4", requires = "Building Grid GL4",
		  children = {
			{ id = "buildinggridopacity", name = "Opacity", type = "slider", min = 0.1, max = 1, step = 0.05, api = {"buildinggrid", "getOpacity", "setOpacity"}, configVar = {"Building Grid GL4", "opacity"} },
		  } },
		{ id = "reclaimhighlight", name = "Reclaim field highlight", type = "bool", widget = "Reclaim Field Highlight", requires = "Reclaim Field Highlight" },
		{ id = "showbuilderqueue", name = "Show builder queues", type = "bool", widget = "Show Builder Queue", requires = "Show Builder Queue" },
		{ id = "showallcommands", name = "Show all unit commands", type = "bool", widget = "Show All Commands", requires = "Show All Commands" },

		{ type = "separator", name = "Cursor and markers" },
		{ id = "allycursors", name = "Ally cursors", type = "bool", widget = "AllyCursors", requires = "AllyCursors",
		  children = {
			{ id = "allycursornames", name = "Show player names", type = "bool", configVar = {"AllyCursors", "showPlayerName"}, default = true, reloadUI = false },
			{ id = "allycursorspecnames", name = "Show spectator names", type = "bool", configVar = {"AllyCursors", "showSpectatorName"}, default = false },
		  } },
		{ id = "mousefx", name = "Mouse click effects", type = "bool", widget = "Mouse FX", requires = "Mouse FX" },
		{ id = "mapmarksfx", name = "Map mark effects", type = "bool", widget = "Mapmarks FX", requires = "Mapmarks FX" },
		{ id = "pointtracker", name = "Point tracker", type = "bool", widget = "Point Tracker", requires = "Point Tracker",
		  desc = "Arrows at the screen edge pointing to map marks." },

		{ type = "separator", name = "Spectating" },
		{ id = "playertv", name = "Player TV", type = "bool", widget = "Player-TV", requires = "Player-TV",
		  desc = "When spectating, cycles the camera between players.",
		  children = {
			{ id = "playertvdelay", name = "Switch every (seconds)", type = "slider", min = 10, max = 120, step = 5, api = {"playertv", "GetPlayerChangeDelay", "SetPlayerChangeDelay"}, configVar = {"Player-TV", "playerChangeDelay"}, default = 40 },
		  } },
		{ id = "allyselectedunits", name = "Show allies' selections", type = "bool", widget = "Ally Selected Units", requires = "Ally Selected Units",
		  children = {
			{ id = "allyselopacity", name = "Opacity", type = "slider", min = 0.1, max = 1, step = 0.05, api = {"allyselectedunits", "getOpacity", "setOpacity"}, configVar = {"Ally Selected Units", "maxAlpha"} },
			{ id = "allyselselect", name = "Select tracked player's units", type = "bool", api = {"allyselectedunits", "getSelectPlayerUnits", "setSelectPlayerUnits"}, configVar = {"Ally Selected Units", "selectPlayerUnits"},
			  desc = "When following a player's camera, mirror their selection." },
		  } },
		{ id = "lockhideenemies", name = "Tracked player viewpoint only", type = "bool", requires = "Static Players List",
		  api = {"advplayerlist_api", "GetLockHideEnemies", "SetLockHideEnemies"}, default = false,
		  desc = "When following a player's camera, only show what they can see.",
		  children = {
			{ id = "locklos", name = "Show their line of sight", type = "bool", api = {"advplayerlist_api", "GetLockLos", "SetLockLos"}, default = false },
		  } },
		{ id = "spectateselected", name = "Spectate selected", type = "bool", widget = "Spectate Selected", requires = "Spectate Selected" },
		{ id = "pip", name = "Picture-in-picture", type = "bool", widget = "Picture-in-Picture", requires = "Picture-in-Picture",
		  children = {
			{ id = "pip2", name = "Second window", type = "bool", widget = "Picture-in-Picture #2", requires = "Picture-in-Picture #2" },
			{ id = "pip3", name = "Third window", type = "bool", widget = "Picture-in-Picture #3", requires = "Picture-in-Picture #3" },
		  } },
	},
}
