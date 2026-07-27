function widget:GetInfo()
	return {
		name    = "Initial Settings",
		desc    = "Applies recommended engine settings once on first run, then disables itself.",
		author  = "Scary le Poo",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = -1000,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Marker: written to springsettings.cfg once the settings below have been applied.
-- Bump SETTINGS_VERSION to force a re-apply for everyone on their next launch.
--------------------------------------------------------------------------------

local MARKER_KEY      = "SFInitialSettingsVersion"
local SETTINGS_VERSION = 1

--------------------------------------------------------------------------------
-- Settings. Ordered list so application order is deterministic.
--   integer number -> SetConfigInt
--   fractional     -> SetConfigFloat
--   boolean        -> SetConfigInt (1/0)
--   string         -> SetConfigString
--------------------------------------------------------------------------------

local settings = {
	{ "AdvModelShading",             1 },
	{ "AllowDeferredMapRendering",   1 },
	{ "AllowDeferredModelRendering", 1 },
	{ "AllowSpectatorJoin",          true },
	{ "FeatureDrawDistance",         150000 },
	{ "GrassDetail",                 200 },
	{ "GroundDetail",                200 },
	{ "HangTimeout",                 -1 },
	{ "HardwareCursor",              1 },
	{ "InputTextGeo",                "0.26 0.73 0.02 0.028" },
	{ "LoadingMT",                   1 },
	{ "MSAALevel",                   8 },
	{ "MaxNanoParticles",            5000 },
	{ "MaxParticles",                25000 },
	{ "MaxSounds",                   256 },
	{ "MaxTextureAtlasSizeX",        8192 },
	{ "MaxTextureAtlasSizeZ",        8192 },
	{ "ReconnectTimeout",            300 },
	{ "ScreenshotCounter",           1 },
	{ "ShadowMapSize",               8192 },
	{ "Shadows",                     1 },
	{ "ShowFPS",                     0 },
	{ "ShowPlayerInfo",              0 },
	{ "ShowSpeed",                   0 },
	{ "Softparticles",               1 },
	{ "SplashScreenDir",             "./MenuLoadscreens" },
	{ "UnitIconDist",                300 },
	{ "UnitIconFadeAmount",          0 },
	{ "UnitIconFadeVanish",          3000 },
	{ "UnitIconScaleUI",             1.05 },
	{ "UnitIconsAsUI",               1 },
	{ "UnitIconsHideWithUI",         1 },
	{ "Water",                       4 },
	{ "evo_buildorderui",            1 },
	{ "evo_musicInitialValue",       1 },
	{ "evo_simplifiedresourcebar",   0 },
	{ "snd_volmaster",               200 },
	{ "snd_volmusic",                20 },
}

--------------------------------------------------------------------------------

local spGetConfigInt    = Spring.GetConfigInt
local spSetConfigInt    = Spring.SetConfigInt
local spSetConfigFloat  = Spring.SetConfigFloat
local spSetConfigString = Spring.SetConfigString

local removeMe = false

local function setValue(key, value)
	local t = type(value)
	if t == "boolean" then
		spSetConfigInt(key, value and 1 or 0, false)
	elseif t == "number" then
		if value % 1 == 0 then
			spSetConfigInt(key, value, false)
		elseif spSetConfigFloat then
			spSetConfigFloat(key, value, false)
		else
			spSetConfigString(key, tostring(value), false)
		end
	else
		spSetConfigString(key, tostring(value), false)
	end
end

local function applySettings()
	local applied, failed = 0, 0
	for i = 1, #settings do
		local entry = settings[i]
		local ok = pcall(setValue, entry[1], entry[2])
		if ok then
			applied = applied + 1
		else
			failed = failed + 1
			Spring.Echo("[Initial Settings] failed to set: " .. tostring(entry[1]))
		end
	end
	return applied, failed
end

function widget:Initialize()
	-- Already run at this version? Bail out without touching anything.
	if (spGetConfigInt(MARKER_KEY, 0) or 0) >= SETTINGS_VERSION then
		removeMe = true
		return
	end

	local applied, failed = applySettings()

	-- Only mark as done if nothing blew up, so a broken run retries next launch.
	if failed == 0 then
		spSetConfigInt(MARKER_KEY, SETTINGS_VERSION, false)
	end

	Spring.Echo("[Initial Settings] applied " .. applied .. " engine settings"
		.. (failed > 0 and (" (" .. failed .. " failed)") or "")
		.. ". Some require a restart to take effect.")

	removeMe = true
end

-- Deferred removal: pulling a widget during its own Initialize can upset the
-- handler's callin lists on some versions, so wait one frame.
function widget:Update()
	if removeMe then
		removeMe = false
		widgetHandler:RemoveWidget(self)
	end
end
