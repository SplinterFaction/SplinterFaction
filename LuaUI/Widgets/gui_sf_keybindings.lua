function widget:GetInfo()
	return {
		name      = "SF Keybindings",
		desc      = "Loads Splinter Faction's default keybinds from the game archive, then an optional user override file. Never writes to uikeys.txt; the user's own bindings always take priority.",
		author    = "Scary le Poo",
		date      = "2026",
		license   = "GNU GPL, v2 or later",
		layer     = -1000,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- Tunables
--------------------------------------------------------------------------------

-- Shipped inside the game archive. Resolved through the VFS.
-- IMPORTANT: this file must NOT start with "unbindall" -- doing so would wipe the
-- bindings the engine already loaded from the user's uikeys.txt at startup.
local GAME_KEYS_FILE = "luaui/configs/sf_keys.txt"

-- Optional raw file in the user's write dir, loaded AFTER the game defaults so
-- that "unbind" lines in it can remove SF binds the user doesn't want.
-- Set to nil to disable the override hook entirely.
local USER_KEYS_FILE = "sf_uikeys.txt"

-- Console action name: "/sfkeys" re-applies both files (useful after /keyreload).
local ACTION_NAME = "sfkeys"

local DEBUG = false

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------

local spSendCommands = Spring.SendCommands
local spEcho         = Spring.Echo

local applied = false

local function Log(msg)
	if DEBUG then
		spEcho("[SF Keybindings] " .. msg)
	end
end

-- True if the path exists on the raw filesystem (not inside an archive).
local function RawFileExists(path)
	if VFS.RAW and VFS.FileExists(path, VFS.RAW) then
		return true
	end
	-- Fallback: io.open resolves relative to the engine's write dir.
	local f = io.open(path, "r")
	if f then
		f:close()
		return true
	end
	return false
end

--------------------------------------------------------------------------------
-- Loading
--------------------------------------------------------------------------------

-- Binds append to the per-keyset action list and the engine takes the first
-- valid entry, so anything loaded here sits BEHIND the user's uikeys.txt binds
-- (which the engine loaded at startup, before LuaUI existed). Identical bind
-- lines are deduplicated by the engine, so re-applying is harmless.
local function ApplyKeys(verbose)
	if VFS.FileExists(GAME_KEYS_FILE) then
		spSendCommands("keyload " .. GAME_KEYS_FILE)
		Log("loaded " .. GAME_KEYS_FILE)
	else
		spEcho("[SF Keybindings] missing " .. GAME_KEYS_FILE .. " -- no SF default binds applied")
	end

	if USER_KEYS_FILE and RawFileExists(USER_KEYS_FILE) then
		spSendCommands("keyload " .. USER_KEYS_FILE)
		Log("loaded user override " .. USER_KEYS_FILE)
	else
		Log("no user override file")
	end

	applied = true

	if verbose then
		spEcho("[SF Keybindings] keybinds re-applied")
	end
end

local function ReloadAction(_, _, _, _, _, release)
	if release then
		return true
	end
	ApplyKeys(true)
	return true
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

function widget:Initialize()
	widgetHandler:AddAction(ACTION_NAME, ReloadAction, nil, "p")

	-- Shared with the Static Keybinds editor widget
	WG.SFKeybindings = {
		Apply    = function() ApplyKeys(false) end,
		gameFile = GAME_KEYS_FILE,
		userFile = USER_KEYS_FILE,
	}
end

function widget:Update()
	-- Deferred by one frame so the keybind load happens outside the widget
	-- handler's Initialize pass.
	if not applied then
		ApplyKeys(false)
	end
end

function widget:Shutdown()
	widgetHandler:RemoveAction(ACTION_NAME, "p")
	WG.SFKeybindings = nil
end
