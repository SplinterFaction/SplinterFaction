function gadget:GetInfo()
	return {
		name = "AI NeverStall",	-- Make it impossible for the ai to ever stall out.
		desc = "Keeps AI team resources topped up to at least 15% of storage.",
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

local function RefreshAiTeams()
	aiTeams = {}
	local teamList = Spring.GetTeamList()
	local gaiaTeamID = Spring.GetGaiaTeamID()
	for i = 1, #teamList do
		local teamID = teamList[i]
		if teamID ~= gaiaTeamID then
			local luaAI = Spring.GetTeamLuaAI(teamID)
			if luaAI and luaAI ~= "" then
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
