function widget:GetInfo()
	return {
		name    = "Initial Settings",
		desc    = "Applies recommended engine settings on first run, then reloads during pregame so they take effect.",
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

local MARKER_KEY       = "SFInitialSettingsVersion"
local SETTINGS_VERSION = 1

--------------------------------------------------------------------------------
-- Reload tunables
--------------------------------------------------------------------------------

local ALLOW_RELOAD  = true          -- master switch
local RELOAD_DELAY  = 4.0           -- seconds to hold the notice before reloading
local RELOAD_IN_MP  = false         -- NEVER set true; Reload deletes clientNet/gameServer
local SCRIPT_FILE   = "_script.txt" -- written by CGameSetup::LoadReceivedScript when host
local SCRIPT_MODES  = "rp"          -- r = raw/datadirs, p = process working dir
local FORCE_APPLY   = false         -- ignore the marker and re-run every launch
local DEBUG         = true          -- verbose decision trace to infolog

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
	{ "MaxTextureAtlasSizeY",        8192 },
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
-- Rebuilt by an in-process reload. SpringApp::Reload destroys CGame and
-- everything it owns, so these are re-read from configHandler on the way back
-- up (CTextureAtlas reads MaxTextureAtlasSizeX/Y in its constructor).
--------------------------------------------------------------------------------

local RELOAD_FIXES = {
	AllowDeferredMapRendering   = true,
	AllowDeferredModelRendering = true,
	MaxSounds                   = true,
	MaxTextureAtlasSizeX        = true,
	MaxTextureAtlasSizeY        = true,
	ShadowMapSize               = true,
}

--------------------------------------------------------------------------------
-- Read once into CGlobalRendering's constructor at process start.
-- CGlobalRendering is NOT destroyed by a reload, so only a fresh process helps.
--------------------------------------------------------------------------------

local PROCESS_ONLY = {
	LoadingMT = true,
	MSAALevel = true,
}

--------------------------------------------------------------------------------

local FONT_CANDIDATES = {
	"fonts/Saira_SemiCondensed-SemiBold.ttf",
	"fonts/SairaSemiCondensed-SemiBold.ttf",
	"fonts/Saira-SemiBold.ttf",
	"fonts/FreeSansBold.otf",
}

local spGetConfigInt    = Spring.GetConfigInt
local spGetConfigString = Spring.GetConfigString
local spSetConfigInt    = Spring.SetConfigInt
local spSetConfigFloat  = Spring.SetConfigFloat
local spSetConfigString = Spring.SetConfigString
local spGetGameFrame    = Spring.GetGameFrame
local spEcho            = Spring.Echo

local removeMe      = false
local pendingReload = false
local reloadScript  = nil
local waited        = 0
local startTimer    = nil
local lastElapsed   = 0
local font          = nil
local vsx, vsy      = Spring.GetViewGeometry()
local uiScale       = 1

local NOTICE_LINE1 = "Applying recommended graphics settings"
local NOTICE_LINE2 = "Reloading, this will only happen once"

--------------------------------------------------------------------------------
-- Elapsed wall-clock seconds since the notice went up.
--
-- widget:Update receives game->updateDeltaSeconds, but LuaHandle only pushes it
-- when `game` is non-null, so never trust it blindly.
--
-- DiffTimers(t1, t2, wantMillis, timersAreMicros):
--   arg4 declares the UNITS OF THE PACKED TIMERS, not the output precision.
--   PushTimer stores Spring.GetTimer as MILLIseconds and Spring.GetTimerMicros
--   as microseconds. Passing arg4 = true alongside a GetTimer value makes the
--   engine read a millisecond delta via fromMicroSecs(), so every result comes
--   back 1000x too small and the timer effectively never advances.
--   arg3 selects the output unit: true = milliseconds, false = seconds.
-- Correct pairing here: GetTimer -> DiffTimers(t1, t2, false, false) -> seconds.
--------------------------------------------------------------------------------

-- Pure read of wall-clock seconds since the notice went up. No side effects,
-- safe to call from DrawScreen every frame.
local function elapsedNow()
	if startTimer and Spring.GetTimer and Spring.DiffTimers then
		local ok, secs = pcall(Spring.DiffTimers, Spring.GetTimer(), startTimer, false, false)
		if ok and type(secs) == "number" then
			return secs
		end
	end
	return waited
end

local function elapsed(dt)
	if startTimer and Spring.GetTimer and Spring.DiffTimers then
		local ok, secs = pcall(Spring.DiffTimers, Spring.GetTimer(), startTimer, false, false)
		if ok and type(secs) == "number" then
			return secs
		end
	end
	-- Fall back to accumulating the callin delta, then to a fixed guess.
	waited = waited + ((type(dt) == "number" and dt > 0) and dt or (1 / 60))
	return waited
end

--------------------------------------------------------------------------------
-- Value encoding / writing
--------------------------------------------------------------------------------

local function encode(value)
	local t = type(value)
	if t == "boolean" then
		return "int", (value and 1 or 0)
	elseif t == "number" then
		if value % 1 == 0 then
			return "int", value
		end
		return "float", value
	end
	return "string", tostring(value)
end

local function setValue(key, kind, value)
	if kind == "int" then
		spSetConfigInt(key, value, false)
	elseif kind == "float" then
		if spSetConfigFloat then
			spSetConfigFloat(key, value, false)
		else
			spSetConfigString(key, tostring(value), false)
		end
	else
		spSetConfigString(key, value, false)
	end
end

local function currentAsString(key)
	local ok, v = pcall(spGetConfigString, key, "")
	if ok and v ~= nil and v ~= "" then
		return tostring(v)
	end
	return nil
end

--------------------------------------------------------------------------------

local function applySettings()
	local applied, failed = 0, 0
	local reloadDirty, processDirty = false, false

	for i = 1, #settings do
		local key = settings[i][1]
		local kind, value = encode(settings[i][2])
		local before = currentAsString(key)

		local ok = pcall(setValue, key, kind, value)
		if ok then
			applied = applied + 1
			local changed = (before ~= tostring(value))
			if changed then
				if RELOAD_FIXES[key]  then reloadDirty  = true end
				if PROCESS_ONLY[key]  then processDirty = true end
				if DEBUG and (RELOAD_FIXES[key] or PROCESS_ONLY[key]) then
					spEcho("[Initial Settings] " .. key .. ": "
						.. tostring(before) .. " -> " .. tostring(value))
				end
			end
		else
			failed = failed + 1
			spEcho("[Initial Settings] failed to set: " .. tostring(key))
		end
	end

	return applied, failed, reloadDirty, processDirty
end

--------------------------------------------------------------------------------
-- Start script recovery
--
-- CGameSetup::LoadReceivedScript writes the resolved script to "_script.txt"
-- via a bare relative path, so it lands in the process working directory. It is
-- written only when isHost is true, which is exactly the case we allow anyway.
--------------------------------------------------------------------------------

local function readStartScript()
	if not (VFS and VFS.LoadFile) then return nil, "VFS unavailable" end

	local ok, data = pcall(VFS.LoadFile, SCRIPT_FILE, SCRIPT_MODES)
	if not ok or type(data) ~= "string" or data == "" then
		return nil, "could not read " .. SCRIPT_FILE
	end

	-- Sanity check: feeding a malformed script to Reload drops to the menu.
	if not data:lower():find("%[game%]") then
		return nil, SCRIPT_FILE .. " does not look like a start script"
	end

	return data
end

--------------------------------------------------------------------------------
-- Reload safety
--------------------------------------------------------------------------------

local function humanSlotCount()
	local ok, list = pcall(Spring.GetPlayerList)
	if not ok or type(list) ~= "table" then
		return 99 -- unknown: assume the worst
	end
	return #list
end

local function canReload()
	if not ALLOW_RELOAD then
		return false, "disabled by config"
	end
	if type(Spring.Reload) ~= "function" then
		return false, "Spring.Reload unavailable in this build"
	end
	if not RELOAD_IN_MP and humanSlotCount() > 1 then
		return false, "multiplayer game"
	end
	if spGetGameFrame() > 0 then
		return false, "game already running"
	end
	return true
end

--------------------------------------------------------------------------------
-- Notice overlay
--------------------------------------------------------------------------------

local function loadNoticeFont()
	if not gl.LoadFont then return end
	for i = 1, #FONT_CANDIDATES do
		local path = FONT_CANDIDATES[i]
		if VFS.FileExists(path) then
			local ok, f = pcall(gl.LoadFont, path, math.floor(28 * uiScale), 3, 1.7)
			if ok and f then
				font = f
				return
			end
		end
	end
end

--------------------------------------------------------------------------------

function widget:Initialize()
	vsx, vsy = Spring.GetViewGeometry()
	uiScale = vsy / 1080

	local marker = spGetConfigInt(MARKER_KEY, 0) or 0
	if DEBUG then
		spEcho("[Initial Settings] marker=" .. marker .. " required=" .. SETTINGS_VERSION
			.. " forceApply=" .. tostring(FORCE_APPLY))
	end

	if marker >= SETTINGS_VERSION and not FORCE_APPLY then
		if DEBUG then
			spEcho("[Initial Settings] already applied at this version, standing down. "
				.. "Set FORCE_APPLY = true or bump SETTINGS_VERSION to re-run.")
		end
		removeMe = true
		return
	end

	local applied, failed, reloadDirty, processDirty = applySettings()

	-- Only mark as done if nothing blew up, so a broken run retries next launch.
	local marked = false
	if failed == 0 then
		spSetConfigInt(MARKER_KEY, SETTINGS_VERSION, false)
		marked = true
	end

	spEcho("[Initial Settings] applied " .. applied .. " engine settings"
		.. (failed > 0 and (" (" .. failed .. " failed)") or "") .. ".")

	if processDirty then
		spEcho("[Initial Settings] MSAA / LoadingMT are read at process start; "
			.. "they will apply on the next launch.")
	end

	-- Never reload unless the marker is safely persisted, or the next launch
	-- re-applies and reloads again, forever.
	if FORCE_APPLY then
		reloadDirty = true
		if DEBUG then
			spEcho("[Initial Settings] FORCE_APPLY: treating settings as changed.")
		end
	end

	if DEBUG then
		spEcho("[Initial Settings] reloadDirty=" .. tostring(reloadDirty)
			.. " markerWritten=" .. tostring(marked))
	end

	if not (reloadDirty and marked) then
		if DEBUG then
			spEcho("[Initial Settings] nothing requires a reload, standing down.")
		end
		removeMe = true
		return
	end

	local ok, why = canReload()
	if not ok then
		spEcho("[Initial Settings] settings need a reload to take effect ("
			.. tostring(why) .. "). They will apply on the next launch.")
		removeMe = true
		return
	end

	local script, err = readStartScript()
	if not script then
		-- Reload("") calls LoadSpringMenu() and strands the player. Never do it.
		spEcho("[Initial Settings] skipping reload: " .. tostring(err)
			.. ". Settings will apply on the next launch.")
		removeMe = true
		return
	end

	reloadScript  = script
	pendingReload = true
	waited        = 0
	startTimer    = Spring.GetTimer and Spring.GetTimer() or nil
	lastElapsed   = 0
	loadNoticeFont()

	if DEBUG then
		local probe = "none (falling back to Update dt)"
		if startTimer and Spring.DiffTimers then
			local ok, secs = pcall(Spring.DiffTimers, Spring.GetTimer(), startTimer, false, false)
			probe = ok and ("Spring.DiffTimers ok, t=" .. tostring(secs)) or ("DiffTimers FAILED: " .. tostring(secs))
		end
		spEcho("[Initial Settings] armed, holding " .. RELOAD_DELAY .. "s. Timer: " .. probe)
	end
	spEcho("[Initial Settings] reloading to rebuild texture atlases ("
		.. #script .. " byte script recovered).")
end

function widget:ViewResize(x, y)
	vsx, vsy = x, y
	uiScale = vsy / 1080
end

function widget:DrawScreen()
	if not pendingReload then return end

	gl.Color(0, 0, 0, 0.75)
	gl.Rect(0, 0, vsx, vsy)
	gl.Color(1, 1, 1, 1)

	local cx, cy = vsx * 0.5, vsy * 0.5

	-- Computed here rather than read from Update, so the countdown is still
	-- correct even if Update is starved. If this reaches 0 and nothing happens,
	-- Update is not running and that is the bug to chase.
	local remain = math.max(0, RELOAD_DELAY - elapsedNow())
	local sub = NOTICE_LINE2
	if remain > 0.5 then
		sub = NOTICE_LINE2 .. "  (" .. string.format("%.0f", remain + 0.5) .. ")"
	end

	if font then
		font:Begin()
		font:SetTextColor(1, 1, 1, 1)
		font:Print(NOTICE_LINE1, cx, cy + 14 * uiScale, 28 * uiScale, "cn")
		font:SetTextColor(0.75, 0.8, 0.9, 1)
		font:Print(sub, cx, cy - 22 * uiScale, 20 * uiScale, "cn")
		font:End()
	else
		gl.Text(NOTICE_LINE1, cx, cy + 14 * uiScale, 28 * uiScale, "cn")
		gl.Text(sub, cx, cy - 22 * uiScale, 20 * uiScale, "cn")
	end
end

function widget:Update(dt)
	if pendingReload then
		lastElapsed = elapsed(dt)
		if lastElapsed >= RELOAD_DELAY then
			pendingReload = false
			removeMe = true
			local ok, err = pcall(Spring.Reload, reloadScript)
			if not ok then
				spEcho("[Initial Settings] reload failed: " .. tostring(err)
					.. " -- settings will apply on the next launch.")
			end
		end
		return
	end

	if removeMe then
		removeMe = false
		widgetHandler:RemoveWidget(self)
	end
end

function widget:Shutdown()
	if font and font.Delete then
		pcall(function() font:Delete() end)
	end
	font = nil
end

--------------------------------------------------------------------------------
-- ENGINE NOTES (verified against RecoilEngine @ 4d06613)
--
-- Spring.Restart and Spring.Reload are the same call. Both go to
-- ReloadOrRestart(..., newProcess = false), which sets gameSetup->reloadScript
-- and gu->globalReload; commandline args are ignored (dead #if 0 branch).
-- SpringApp::Reload then tears down game/pregame/clientNet/gameServer/sound,
-- reloads the VFS, and rebuilds from the script.
--   * an empty script argument calls LoadSpringMenu() -- guarded against above
--   * CGlobalRendering survives, so MSAALevel and LoadingMT do NOT change
--   * texture atlases DO rebuild, which is the point of this widget
--   * gameServer and clientNet are deleted, so MP would be a disconnect
--
-- Spring.Start(args, script) is the only call that spawns a new process, and it
-- does not terminate this one. A true restart is Start(...) then Quit().
--
-- Config keys: the atlas keys are MaxTextureAtlasSizeX and MaxTextureAtlasSizeY.
-- There is no ...SizeZ; setting it writes a line nothing ever reads.
--------------------------------------------------------------------------------
