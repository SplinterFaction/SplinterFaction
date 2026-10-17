function widget:GetInfo()
	return {
		name      = "SF Keybindings",
		desc      = "Owns the key bindings: discards the engine-loaded uikeys.txt, then applies Splinter Faction's binds, the engine defaults behind them, and the player's in-game rebinds (sf_uikeys.txt) on top.",
		author    = "Scary le Poo",
		date      = "2026",
		license   = "GNU GPL, v2 or later",
		layer     = -1000, -- first to Initialize, so widgets that bind keys in their own Initialize land on top
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- Why this replaces uikeys.txt instead of layering on it
--
-- Many players run one Recoil install for several games, and uikeys.txt in the
-- write dir is shared between them. Whatever another game left there (or an
-- "unbindall" at its top) used to win over SF, because per keyset the engine
-- runs the first-bound action that is available, and uikeys.txt is bound at
-- startup before LuaUI exists.
--
-- So the bind table is rebuilt from scratch, in priority order:
--
--   1. unbindall                     drops everything, including uikeys.txt
--   2. luaui/configs/sf_keys.txt     SF's binds, read from the game archive only
--   3. keydefaults                   the engine's built-in binds, as fallbacks
--   4. sf_uikeys.txt (write dir)     the player's own rebinds from the Keybinds
--                                    window; its unbind lines remove what it
--                                    replaces, so it wins conflicts
--
-- uikeys.txt is never read or written. A player who runs /keyreload gets it
-- back until the next /sfkeys (or the next game).
--
-- Widgets that bind keys at runtime (game info, share, options, health bars,
-- Reset Hotkeys) do so in their own Initialize, after this one. A later
-- re-apply would wipe those binds, so they register with
-- WG.SFKeybindings.AddReapplyHook and are re-run after every re-apply.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Tunables
--------------------------------------------------------------------------------

-- Shipped inside the game archive; always read with VFS.ZIP so a loose file at
-- the same path in the write dir can never stand in for it.
local GAME_KEYS_FILE = "luaui/configs/sf_keys.txt"

-- Raw file in the write dir, written by the Keybinds window. Set to nil to
-- disable it.
local USER_KEYS_FILE = "sf_uikeys.txt"

-- "/sfkeys" rebuilds the bindings (e.g. after a /keyreload)
local ACTION_NAME = "sfkeys"

local DEBUG = false

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------

local spSendCommands = Spring.SendCommands
local spEcho         = Spring.Echo

local reapplyHooks = {} -- ordered {name = , fn = }

local function Log(msg)
	if DEBUG then
		spEcho("[SF Keybindings] " .. msg)
	end
end

-- True if the path exists on the raw filesystem (not inside an archive).
local function RawFileExists(path)
	if VFS.RAW_ONLY and VFS.FileExists(path, VFS.RAW_ONLY) then
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

-- Command lines of a uikeys-format file: comments and blank lines dropped.
local function ReadKeyLines(text, out)
	for line in text:gmatch("[^\r\n]+") do
		line = line:gsub("//.*$", "")
		line = line:match("^%s*(.-)%s*$")
		if line ~= "" then
			out[#out + 1] = line
		end
	end
	return out
end

--------------------------------------------------------------------------------
-- Loading
--------------------------------------------------------------------------------

local function BuildCommands()
	local cmds = { "unbindall" }

	local text = VFS.LoadFile(GAME_KEYS_FILE, VFS.ZIP)
	if text then
		ReadKeyLines(text, cmds)
		Log("read " .. GAME_KEYS_FILE)
	else
		spEcho("[SF Keybindings] missing " .. GAME_KEYS_FILE .. " -- no SF default binds applied")
	end

	cmds[#cmds + 1] = "keydefaults"

	if USER_KEYS_FILE and RawFileExists(USER_KEYS_FILE) then
		-- raw on purpose: this file lives in the write dir
		cmds[#cmds + 1] = "keyload " .. USER_KEYS_FILE
		Log("queued user rebinds " .. USER_KEYS_FILE)
	end

	return cmds
end

local function ApplyKeys(verbose)
	spSendCommands(BuildCommands())

	for i = 1, #reapplyHooks do
		local hook = reapplyHooks[i]
		local ok, err = pcall(hook.fn)
		if not ok then
			spEcho("[SF Keybindings] reapply hook '" .. tostring(hook.name) .. "' failed: " .. tostring(err))
		end
	end

	if verbose then
		spEcho("[SF Keybindings] keybinds re-applied")
	end
end

-- fn is called after every re-apply, so a widget's own runtime binds survive.
-- Registering again under the same name replaces the earlier hook.
local function AddReapplyHook(name, fn)
	if type(name) ~= "string" or type(fn) ~= "function" then return end
	for i = 1, #reapplyHooks do
		if reapplyHooks[i].name == name then
			reapplyHooks[i].fn = fn
			return
		end
	end
	reapplyHooks[#reapplyHooks + 1] = { name = name, fn = fn }
end

local function RemoveReapplyHook(name)
	for i = #reapplyHooks, 1, -1 do
		if reapplyHooks[i].name == name then
			table.remove(reapplyHooks, i)
		end
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

	-- Shared with the Keybinds window and every widget that binds keys itself
	WG.SFKeybindings = {
		Apply             = function() ApplyKeys(false) end,
		AddReapplyHook    = AddReapplyHook,
		RemoveReapplyHook = RemoveReapplyHook,
		gameFile          = GAME_KEYS_FILE,
		userFile          = USER_KEYS_FILE,
	}

	-- Applied here rather than on the first Update: this widget is layer -1000,
	-- so it initializes before every widget that adds its own binds, and those
	-- binds are not wiped.
	ApplyKeys(false)
end

function widget:Shutdown()
	widgetHandler:RemoveAction(ACTION_NAME, "p")
	WG.SFKeybindings = nil
end
