-- $Id: luaui.lua 3171 2008-11-06 09:06:29Z det $
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    luaui.lua
--  brief:   entry point for LuaUI
--  author:  Dave Rodgers
--
--  Copyright (C) 2008.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

LUAUI_VERSION = "LuaUI v0.3"

LUAUI_DIRNAME = 'LuaUI/'

-- Only the game's own Lua runs here. Nothing is loaded from the loose LuaUI/
-- folder in a player's data directory: no replacement handler and no loose
-- copy of a file the game includes. The guard (common/vfs_guard.lua) makes
-- every load of code in this Lua state read from the archives, and the helpers
-- the engine ships as loose files (utils.lua, savetable.lua, ...) are in the
-- game archive for that reason.
--
-- The one exception is the host's "allowuserwidgets" modoption. With it on,
-- the loose widgets in LuaUI/Widgets are loaded (LuaUI/widgets_custom.lua),
-- and a file under LuaUI/Widgets that the game does not have can be included
-- by them. Loose copies of the game's own files are still never used, and the
-- gadgets are guarded whatever the option says (LuaRules/draw.lua).
local function IsTruthy(v)
  return v == true or v == 1 or v == "1" or v == "true" or v == "yes"
end
VFS_GUARD_USER_WIDGETS = IsTruthy((Spring.GetModOptions() or {}).allowuserwidgets)
VFS.Include("common/vfs_guard.lua", nil, VFS.ZIP)
VFS.DEF_MODE = VFS.ZIP
LUAUI_VFSMODE = VFS.ZIP

local STARTUP_FILENAME = LUAUI_DIRNAME .. 'main_custom.lua'
local STARTUP_VFSMODE  = VFS.ZIP

Spring.Echo('Using LUAUI_DIRNAME = ' .. LUAUI_DIRNAME)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
-- load the user's UI
--

do
  text = VFS.LoadFile(STARTUP_FILENAME, STARTUP_VFSMODE)
  if (text == nil) then
    Script.Kill('Failed to load ' .. STARTUP_FILENAME)
  end
  local chunk, err = loadstring(text)
  if (chunk == nil) then
    Script.Kill('Failed to load ' .. STARTUP_FILENAME .. ' (' .. err .. ')')
  else
    chunk()
    return
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
