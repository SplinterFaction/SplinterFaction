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

-- Players often share one Recoil install between several games, so the raw
-- LuaUI/ folder in their data directory can hold another game's handler,
-- includes and widgets. The game archive always wins; raw files are only a
-- fallback (the engine ships some LuaUI helpers, e.g. utils.lua, as raw files).
-- Loose user widgets are gated separately by the "allowuserwidgets" modoption
-- (see LuaUI/widgets_custom.lua).
VFS.DEF_MODE = VFS.ZIP_FIRST
LUAUI_VFSMODE = VFS.ZIP_FIRST

local function IsTruthy(v)
  return v == true or v == 1 or v == "1" or v == "true" or v == "yes"
end
local ALLOW_USER_WIDGETS = IsTruthy((Spring.GetModOptions() or {}).allowuserwidgets)

local STARTUP_FILENAME = LUAUI_DIRNAME .. 'main_custom.lua'
local STARTUP_VFSMODE  = VFS.ZIP

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if ALLOW_USER_WIDGETS then
  -- use a versionned directory name if it exists (a full raw replacement of
  -- the UI, so only honored when user widgets are allowed)
  local sansslash = string.sub(LUAUI_DIRNAME, 1, -2)
  local versiondir = sansslash .. '-' .. ((Game and Game.version) or (Engine and Engine.version) or "Engine version error") .. '/'
  if (VFS.FileExists(versiondir  .. 'main_custom.lua', VFS.RAW_ONLY)) then
    LUAUI_DIRNAME = versiondir
    STARTUP_FILENAME = LUAUI_DIRNAME .. 'main_custom.lua'
    STARTUP_VFSMODE  = VFS.RAW_ONLY
    LUAUI_VFSMODE    = VFS.RAW_FIRST
    VFS.DEF_MODE     = VFS.RAW_FIRST
  end
end

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
