if addon.InGetInfo then
	return {
		name    = "Initial Settings",
		desc    = "Writes the recommended engine settings on a player's first run, while the match loads, so they take effect at once",
		author  = "Scary le Poo; SplinterFaction Team",
		date    = "2026-10-15",
		license = "GNU GPL, v2 or later",
		layer   = -1000, -- before the other addons
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- The list is in LuaUI/Configs/initial_settings.lua, shared with the
-- "Initial Settings" widget.
--
-- This runs while the match loads, before the engine reads most of these
-- settings, so they take effect in the very first match, in multiplayer too,
-- where restarting is not possible. If it had to change one the engine might
-- already have read (with multithreaded loading the engine starts loading a
-- moment before the loading screen), it leaves a note, and in single player
-- the widget restarts the match once to make certain.
--------------------------------------------------------------------------------

local ok, settings = pcall(VFS.Include, "LuaUI/Configs/initial_settings.lua")
if not ok or type(settings) ~= "table" then
	Spring.Echo("[Initial Settings] could not read the settings list: " .. tostring(settings))
	return
end

local marker = Spring.GetConfigInt(settings.MARKER_KEY, 0) or 0
if marker >= settings.VERSION then
	return
end

local function Log(text)
	Spring.Echo("[Initial Settings] " .. text)
end

local applied, failed, reloadDirty = settings.Apply(Spring, Log)
Log("applied " .. applied .. " engine settings while loading" .. ((failed > 0) and (" (" .. failed .. " failed)") or ""))

-- Only mark as done if nothing failed, so a broken run retries next launch.
if failed == 0 then
	Spring.SetConfigInt(settings.MARKER_KEY, settings.VERSION, false)
end
if reloadDirty then
	Spring.SetConfigInt(settings.PENDING_KEY, 1, false)
end
