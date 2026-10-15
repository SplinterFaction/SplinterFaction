function widget:GetInfo()
	return {
		name    = "Initial Settings",
		desc    = "Restarts a single-player match once on first run if the loading screen could not apply the recommended settings in time.",
		author  = "Scary le Poo",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = -1000,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- The settings themselves, the version marker, and which settings need a
-- reload are in LuaUI/Configs/initial_settings.lua. The loading screen
-- (LuaIntro/Addons/initial_settings.lua) writes them on a first run while the
-- match loads, which works in multiplayer too. This widget is the safety net:
-- if the loading screen had to change a setting the engine may already have
-- read, it restarts a single-player match once. In multiplayer a restart is
-- not possible (it would disconnect everyone, or a joining player has no start
-- script to come back with), so there the settings stand as written.
--------------------------------------------------------------------------------

local SETTINGS = VFS.Include("LuaUI/Configs/initial_settings.lua")

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

local FONT_CANDIDATES = {
	"fonts/Saira_SemiCondensed-SemiBold.ttf",
	"fonts/SairaSemiCondensed-SemiBold.ttf",
	"fonts/Saira-SemiBold.ttf",
	"fonts/FreeSansBold.otf",
}

local spGetConfigInt    = Spring.GetConfigInt
local spSetConfigInt    = Spring.SetConfigInt
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

	local marker  = spGetConfigInt(SETTINGS.MARKER_KEY, 0) or 0
	local pending = (spGetConfigInt(SETTINGS.PENDING_KEY, 0) or 0) == 1
	if DEBUG then
		spEcho("[Initial Settings] marker=" .. marker .. " required=" .. SETTINGS.VERSION
			.. " pending=" .. tostring(pending) .. " forceApply=" .. tostring(FORCE_APPLY))
	end

	-- Normally the loading screen has already written the settings. If it did
	-- not (it failed, or this is an old loading screen), write them here.
	local reloadDirty = pending
	if marker < SETTINGS.VERSION or FORCE_APPLY then
		local applied, failed, dirty, processDirty = SETTINGS.Apply(Spring, DEBUG and function(text)
			spEcho("[Initial Settings] " .. text)
		end or nil)
		reloadDirty = reloadDirty or dirty or FORCE_APPLY
		spEcho("[Initial Settings] applied " .. applied .. " engine settings"
			.. (failed > 0 and (" (" .. failed .. " failed)") or "") .. ".")
		if processDirty then
			spEcho("[Initial Settings] MSAA / LoadingMT are read at process start; "
				.. "they will apply on the next launch.")
		end
		-- Only mark as done if nothing blew up, so a broken run retries next
		-- launch. Never reload unless the marker is safely persisted, or the
		-- next launch re-applies and reloads again, forever.
		if failed ~= 0 then
			removeMe = true
			return
		end
		spSetConfigInt(SETTINGS.MARKER_KEY, SETTINGS.VERSION, false)
	end

	-- the note is acted on once, here, whatever happens next
	if pending then
		spSetConfigInt(SETTINGS.PENDING_KEY, 0, false)
	end

	if DEBUG then
		spEcho("[Initial Settings] reloadDirty=" .. tostring(reloadDirty))
	end
	if not reloadDirty then
		if DEBUG then
			spEcho("[Initial Settings] nothing requires a reload, standing down.")
		end
		removeMe = true
		return
	end

	local ok, why = canReload()
	if not ok then
		spEcho("[Initial Settings] no reload (" .. tostring(why) .. "). The settings were "
			.. "written while the match loaded and normally already apply; if one did not "
			.. "make it in time, it applies on the next launch.")
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
