function gadget:GetInfo()
	return {
		name = "AI NeverStall",	-- Make it impossible for the ai to ever stall out.
		desc = "Backstop resource floor for AI teams NOT handled by the SimpleAI core (e.g. SurvivalAI). SimpleAI/AdaptiveAI teams get their floor from ai_simpleai.lua directly.",
		author = "",
		date = "",
		license = "GPL",
		layer = 1,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local ai_neverstall = Spring.GetModOptions().ai_neverstall or "disabled"
if ai_neverstall == "disabled" then return end

local FLOOR_FRACTION = 0.15
local CHECK_INTERVAL = 30 -- frames (1 second)

local spGetTeamResources = Spring.GetTeamResources
local spSetTeamResource = Spring.SetTeamResource

local aiTeams = {}

-- Teams whose luaAI matches these prefixes get their resource floor from the
-- SimpleAI core gadget now (ai_simpleai.lua: modoption-gated for plain
-- SimpleAI, ALWAYS on for AdaptiveAI). Skip them here so nothing double-tops.
-- This gadget remains only as the backstop for every OTHER AI type -- in
-- particular SurvivalAI games, where the SimpleAI gadget never loads.
local function IsCoreManaged(luaAI)
	return string.sub(luaAI, 1, 8)  == 'SimpleAI'
			or string.sub(luaAI, 1, 10) == 'AdaptiveAI'
			or string.sub(luaAI, 1, 16) == 'SimpleDefenderAI'
			or string.sub(luaAI, 1, 19) == 'SimpleConstructorAI'
end

local function RefreshAiTeams()
	aiTeams = {}
	local teamList = Spring.GetTeamList()
	local gaiaTeamID = Spring.GetGaiaTeamID()
	for i = 1, #teamList do
		local teamID = teamList[i]
		if teamID ~= gaiaTeamID then
			local luaAI = Spring.GetTeamLuaAI(teamID)
			if luaAI and luaAI ~= "" and not IsCoreManaged(luaAI) then
				aiTeams[#aiTeams + 1] = teamID
			end
		end
	end
end

function gadget:Initialize()
	RefreshAiTeams()
end

function gadget:GameFrame(frame)
	if frame % CHECK_INTERVAL ~= 27 then
		return
	end
	for i = 1, #aiTeams do
		local teamID = aiTeams[i]
		local ec, es = spGetTeamResources(teamID, "energy")
		local mc, ms = spGetTeamResources(teamID, "metal")
		local eFloor = es * FLOOR_FRACTION
		local mFloor = ms * FLOOR_FRACTION
		if ec < eFloor then
			spSetTeamResource(teamID, "e", eFloor)
		end
		if mc < mFloor then
			spSetTeamResource(teamID, "m", mFloor)
		end
	end
end
