function gadget:GetInfo()
	return {
		name      = "Weather Seed",
		desc      = "Publishes a per-match weather seed so every client sees the same day/night, rain and fog",
		author    = "Doo",
		date      = "2026-08-02",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- Synced only. This gadget does nothing but hash the engine's per-match gameID
-- into a small integer and broadcast it as a game rules param. The Weather
-- widget derives its day/night and rain phase from that seed plus the current
-- game frame, so all clients (and spectators, rejoins, and replays) stay in
-- phase with zero further traffic.
--
-- War tint and lightning deliberately stay per-client: they are driven by
-- LOS-limited widget callins and are not published here.
--------------------------------------------------------------------------------

if not gadgetHandler:IsSyncedCode() then
	return
end

local SEED_PARAM = "weather_seed"
local SEED_MOD   = 16777216 -- 2^24: stays exactly representable as a float rules param

local spSetGameRulesParam = Spring.SetGameRulesParam
local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetPlayerList     = Spring.GetPlayerList
local spGetPlayerInfo     = Spring.GetPlayerInfo
local spGetGameFrame      = Spring.GetGameFrame

--------------------------------------------------------------------------------
-- djb2, kept in plain arithmetic: Lua 5.1 has no bitwise operators, and every
-- intermediate here stays well inside double precision.
--------------------------------------------------------------------------------

local function HashString(s)
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + s:byte(i)) % SEED_MOD
	end
	return h
end

-- Used only if the GameID callin never arrives (e.g. /luarules reload
-- mid-match, which does not re-deliver it). Every term is identical on every
-- client, so the fallback seed is still shared - it just repeats if the same
-- lobby replays the same map.
local function FallbackSeed()
	local parts = { Game.mapName or "", Game.modShortName or "" }
	local players = spGetPlayerList() or {}
	for i = 1, #players do
		local name = spGetPlayerInfo(players[i], false)
		parts[#parts + 1] = tostring(name)
	end
	return HashString(table.concat(parts, "|"))
end

local function PublishSeed(seed)
	spSetGameRulesParam(SEED_PARAM, seed)
	Spring.Echo("[Weather Seed] published " .. tostring(seed))
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

-- Delivered once, early, as a 32-character hex string.
function gadget:GameID(gameID)
	if spGetGameRulesParam(SEED_PARAM) then
		return
	end
	PublishSeed(HashString(tostring(gameID)))
end

function gadget:Initialize()
	-- Covers a mid-match gadget reload, where GameID will not fire again.
	if spGetGameFrame() > 0 and not spGetGameRulesParam(SEED_PARAM) then
		PublishSeed(FallbackSeed())
	end
end

function gadget:GameStart()
	if not spGetGameRulesParam(SEED_PARAM) then
		PublishSeed(FallbackSeed())
	end
end
