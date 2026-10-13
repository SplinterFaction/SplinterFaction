--  LuaUI/rml_setup.lua
--  RmlUi setup for SplinterFaction. Included once from LuaUI/main_custom.lua;
--  it replaces the engine's base-content copy, which only loads a font and a
--  cursor.
--
--  Based on the Recoil setup example by lov + ChrisFloofyKitsune
--  (Copyright (C) 2024, GNU GPL v2 or later).

if (RmlGuard or not RmlUi) then
	return
end
-- don't allow this initialization code to be run multiple times
RmlGuard = true

Spring.Echo("[rml_setup] SplinterFaction RmlUi setup")

-- The HUD fonts are loaded by LuaUI/rml/hud.lua when the first HUD widget
-- starts, so the HUD does not depend on this file having run.

-- Mouse cursor aliases: lets RCSS use the standard CSS cursor names.
RmlUi.SetMouseCursorAlias("default", 'cursornormal')
RmlUi.SetMouseCursorAlias("move", 'uimove')
RmlUi.SetMouseCursorAlias("nesw-resize", 'uiresized2')
RmlUi.SetMouseCursorAlias("nwse-resize", 'uiresized1')
RmlUi.SetMouseCursorAlias("ns-resize", 'uiresizev')
RmlUi.SetMouseCursorAlias("ew-resize", 'uiresizeh')

-- One shared context for every HUD document. Its dp_ratio (the size of one
-- "dp" in pixels) is set and kept up to date by LuaUI/rml/hud.lua.
RmlUi.CreateContext("shared")
