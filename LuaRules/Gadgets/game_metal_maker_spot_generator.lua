--[[
Files that are related and helpers for this Gadget

Gadgets:
game_metal_maker_spot_generator
luarules/configs/metalmakerspots/helpers.lua
luarules/configs/metalmakerspots/algorithms/ <- This is where the various placement algorithms live.

Widgets:
game_metal_spot_loader
game_metal_spot_drawer
game_metal_spot_minimap_drawer
game_metal_maker_placement_snapping

Tangentially related Gadgets:
game_geovent_spot_generator
game_map_defined_metal_spot_finder.lua

Key behavior:
- Total spots is based on map size (common units, sqrt for rectangles)
- Per-spot income value scales with player count to preserve per-player "income budget"
- Algorithms remain modular and can be swapped freely
]]--

function gadget:GetInfo()
	return {
		name    = "Metal Maker Spot Generator (Building Mask 4)",
		desc    = "Places metal maker spots using building masks (map-size targets + scaled income value)",
		author  = "",
		date    = "2026-02-09",
		license = "GPLv2",
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local SetSquareBuildingMask = Spring.SetSquareBuildingMask
local GetGroundHeight       = Spring.GetGroundHeight
local Echo                  = Spring.Echo

local Helpers = VFS.Include("luarules/configs/metalmakerspots/helpers.lua")

-- -------------------------
-- Algorithm selection
-- -------------------------
local algorithm = "stratified_random" -- e.g. "mirrored_group_declumped", etc.
local ALGO_PATH = "luarules/configs/metalmakerspots/algorithms/" .. algorithm .. ".lua"

local algo = VFS.Include(ALGO_PATH)
if type(algo) ~= "table" or type(algo.Generate) ~= "function" then
	error("[MetalSpotGen] Bad algo module: " .. tostring(ALGO_PATH))
end

local function mergeDefaults(defaults, overrides)
	local cfg = {}
	if defaults then
		for k, v in pairs(defaults) do cfg[k] = v end
	end
	if overrides then
		for k, v in pairs(overrides) do cfg[k] = v end
	end
	return cfg
end

-- -------------------------
-- Modoptions
-- -------------------------
local allowWaterSpots = true
do
	local opt = Spring.GetModOptions() and Spring.GetModOptions().allowmexesinwater
	if opt == "disabled" then allowWaterSpots = false end
	if opt == "enabled"  then allowWaterSpots = true  end
end

-- -------------------------
-- Map size -> total spots
-- -------------------------

-- 512x512 = 1x1 "common size"
local function GetCommonMapSize()
	local commonX = Game.mapSizeX / 512
	local commonZ = Game.mapSizeZ / 512
	return math.sqrt(commonX * commonZ) -- sqrt(area) for rectangles
end

local function GetSpotsForCommonSize(s)
	-- Your bins:
	-- <= 8x8 => 20
	-- > 8 and <= 12 => 30
	-- > 12 and <= 16 => 40
	-- > 16 and <= 18 => 60
	-- > 18 and <= 20 => 80
	if s <= 8  then return 20 end
	if s <= 12 then return 30 end
	if s <= 16 then return 40 end
	if s <= 18 then return 60 end
	if s <= 20 then return 80 end

	-- Beyond 20 up to 32: keep scaling.
	-- Default scale: +20 spots per +2 common-size beyond 20
	-- 22->100, 24->120, 26->140, 28->160, 30->180, 32->200
	if s > 32 then s = 32 end
	local extra = s - 20
	local spots = 80 + math.floor((extra / 2) * 20 + 0.5)
	return spots
end

-- Round to multiple of 4 (helps quadrant-balance + mirrored algos)
local function RoundDownToMultipleOf4(n)
	return math.floor(n / 4) * 4
end

-- -------------------------
-- Main
-- -------------------------

local cfgOverride = nil -- optional per-map overrides

function gadget:Initialize()
	Echo("[MetalSpotGen] Init modular: " .. (algo.name or "unnamed") .. " (" .. ALGO_PATH .. ")")

	-- -------------------------
	-- Restore
	-- -------------------------
	local restoredCount = Spring.GetGameRulesParam("metalSpot_count")
	if restoredCount then
		Echo("[MetalSpotGen] Restoring from GameRulesParams")
		GG.metalMakerSpots = {}
		for i = 1, restoredCount do
			local x = Spring.GetGameRulesParam("metalSpot_" .. i .. "_x")
			local z = Spring.GetGameRulesParam("metalSpot_" .. i .. "_z")
			local y = GetGroundHeight(x, z)
			GG.metalMakerSpots[#GG.metalMakerSpots + 1] = { x = x, y = y, z = z }
		end
		return
	end

	-- -------------------------
	-- Player count
	-- -------------------------
	local playerCount = #Spring.GetTeamList() - 1
	Spring.SetGameRulesParam("peopleCount", playerCount)

	-- -------------------------
	-- Map size & targets
	-- -------------------------
	local commonSize = GetCommonMapSize()
	Spring.SetGameRulesParam("mapCommonSize", commonSize)

	local rawSpotsTarget = GetSpotsForCommonSize(commonSize)
	local spotsTarget = RoundDownToMultipleOf4(rawSpotsTarget)
	if spotsTarget < 4 then spotsTarget = 4 end

	-- mirrored algos often treat a group as 4 spots
	local groupsTarget = math.floor(spotsTarget / 4)

	Spring.SetGameRulesParam("metalSpot_target_raw", rawSpotsTarget)
	Spring.SetGameRulesParam("metalSpot_target", spotsTarget)

	-- -------------------------
	-- Income scaling per spot
	-- -------------------------
	-- Old baseline: 10 spots per player @ 3 income each => 30 per-player
	local INCOME_PER_PLAYER = 30

	-- per-spot value scales with players and fixed spot count
	local spotValue = (INCOME_PER_PLAYER * playerCount) / spotsTarget

	--Specify a minimum spot value and get rid of fractions
	spotValue = math.floor(spotValue + 0.5)
	if spotValue < 2 then
		spotValue = 2
	end

	Spring.SetGameRulesParam("metalSpot_incomePerPlayer", INCOME_PER_PLAYER)
	Spring.SetGameRulesParam("metalSpot_value", spotValue)

	Echo(string.format(
			"[MetalSpotGen] mapCommonSize=%.2f rawTarget=%d target=%d players=%d spotValue=%.3f",
			commonSize, rawSpotsTarget, spotsTarget, playerCount, spotValue
	))

	-- -------------------------
	-- Prepare ctx + helpers
	-- -------------------------
	local cfg = mergeDefaults(algo.defaults, cfgOverride)

	local ctx = {
		Spring = Spring,
		Game   = Game,
		SetSquareBuildingMask = SetSquareBuildingMask,
		GetGroundHeight       = GetGroundHeight,
		Echo                  = Echo,

		cfg = cfg,
		allowWaterSpots = allowWaterSpots,

		-- shared placed list (helpers use this)
		spots = {},

		-- targets (algo can use either)
		spotsTarget  = spotsTarget,
		groupsTarget = groupsTarget,

		-- extra info for algos if they want it
		spotValue = spotValue,
		playerCount = playerCount,
		mapCommonSize = commonSize,
	}

	local helpers = Helpers.New(ctx)

	-- -------------------------
	-- Run algorithm
	-- -------------------------
	local stats = algo.Generate(ctx, helpers) or {}

	local metalSpots = ctx.spots
	Echo(string.format(
			"[MetalSpotGen] Done. total spots=%d (spotsTarget=%d groupsTarget=%d)",
			#metalSpots, spotsTarget, groupsTarget
	))

	-- -------------------------
	-- Export
	-- -------------------------
	GG.metalMakerSpots = metalSpots
	for i, spot in ipairs(metalSpots) do
		Spring.SetGameRulesParam("metalSpot_" .. i .. "_x", spot.x)
		Spring.SetGameRulesParam("metalSpot_" .. i .. "_z", spot.z)
	end
	Spring.SetGameRulesParam("metalSpot_count", #metalSpots)

	-- Optional: expose algo name used
	Spring.SetGameRulesParam("metalSpot_algo", tostring(algo.name or algorithm))

	Echo(string.format(
			"[MetalSpotGen] Debug map: mapSizeX=%d mapSizeZ=%d mapX=%d mapY=%d commonX=%.2f commonZ=%.2f commonSize=%.2f",
			Game.mapSizeX, Game.mapSizeZ, Game.mapX, Game.mapY,
			Game.mapSizeX/512, Game.mapSizeZ/512, commonSize
	))
end