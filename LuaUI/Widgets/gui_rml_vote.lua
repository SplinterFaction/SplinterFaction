--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Vote window of the RmlUi HUD. When someone calls a vote on the server
--  (the autohost announces it in the console), a small window shows what the
--  vote is about, with Yes and No. Esc, or the ESC button, abstains. The
--  player who called the vote gets "End vote" instead.
--
--  Only players see it: not spectators, and not in replays.
--
--  Replaces gui_vote_interface.lua by Floris (kept in Widgets/disabled/). The
--  reading of the console lines is carried over.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Vote interface",
		desc    = "Shows a called vote with Yes and No buttons (RmlUi)",
		author  = "Floris; SplinterFaction Team",
		date    = "2026-10-13",
		license = "GNU GPL, v2 or later",
		layer   = -2000, -- ahead of the game menu, so Esc answers the vote first
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local DOCUMENT_PATH = "LuaUI/rml/vote.rml"

-- must match #vote in vote.rml
local PANEL_WIDTH  = 380
local PANEL_HEIGHT = 112
local PANEL_TOP    = 92 -- below the resource bar

local LAYOUT_NAME = "vote"

local hud
local document
local view

local myPlayerID = Spring.GetMyPlayerID()
local myName, _, mySpec, myTeamID, myAllyTeamID = Spring.GetPlayerInfo(myPlayerID, false)
local startedAsPlayer = not mySpec
local gameStarted = false

local voteName  = nil   -- what the vote is about; nil when there is none
local voteOwner = false -- the local player called it

--------------------------------------------------------------------------------
-- showing
--------------------------------------------------------------------------------

local function Refresh()
	view.SetClass("vote", "hidden", voteName == nil)
	if voteName then
		view.SetText("vote-title", hud.Escape(voteName))
		view.SetClass("vote-yes", "hidden", voteOwner)
		view.SetText("vote-no", voteOwner and "End vote" or "No")
	end
end

local function EndVote()
	if voteName then
		voteName = nil
		voteOwner = false
		Refresh()
	end
end

local function StartVote(name, owner)
	voteName = name
	voteOwner = owner and true or false
	pcall(function() document:PullToFront() end)
	Refresh()
end

--------------------------------------------------------------------------------
-- reading the console (carried over)
--------------------------------------------------------------------------------

local function isTeamPlayer(playerName)
	local players = Spring.GetPlayerList()
	for _,pID in ipairs(players) do
		local name,_,spec,teamID,allyTeamID = Spring.GetPlayerInfo(pID,false)
		if name == playerName then
			if allyTeamID == myAllyTeamID then
				return true
			end
		end
	end
	return false
end

function widget:AddConsoleLine(lines, priority)
	if not document or not startedAsPlayer then
		return
	end
	lines = lines:match('^%[f=[0-9]+%] (.*)$') or lines
	for line in lines:gmatch("[^\n]+") do
		if (string.sub(line,1,1) == ">" and string.sub(line,3,3) ~= "<") then	-- system message
			if string.find(line," called a vote ") then	-- vote called
				local from, to = string.find(line,' "'), string.find(line,'" ')
				if from and to then
					local title = string.sub(line, from+2, to-1)..'?'
					title = title:sub(1,1):upper()..title:sub(2)
					-- a vote to resign another team is none of this player's business
					local resignFrom, resignTo = string.find(line,'"resign '), string.find(line,' TEAM')
					if not resignFrom or (resignTo and isTeamPlayer(string.sub(line, resignFrom+8, resignTo-1))) then
						StartVote(title, string.find(line, string.gsub(myName or "", "%p", "%%%1").." called a vote "))
					end
				end
			elseif voteName and (string.find(line," passed.") or string.find(line," failed") or string.find(line,"Vote cancelled") or string.find(line," cancelling \"")) then
				EndVote()
			end
		end
	end
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

local function DefaultOrigin(vsx, vsy, w, h, scale)
	return (vsx - w) * 0.5, vsy - PANEL_TOP * scale - h
end

local function Place()
	hud.PlacePanel(view.Element("vote"), LAYOUT_NAME, PANEL_WIDTH, PANEL_HEIGHT, DefaultOrigin)
end

local function Say(command)
	Spring.PlaySoundFile("leftclick", 1.0, "ui")
	Spring.SendCommands("say " .. command)
	EndVote()
end

function widget:Initialize()
	if Spring.IsReplay() then
		widgetHandler:RemoveWidget(self)
		return
	end
	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		Spring.Echo("[Vote interface] " .. tostring(reason))
		widgetHandler:RemoveWidget(self)
		return
	end
	hud = helpers
	hud.showInPregame = true -- a vote can be called at any time
	document = result
	view = hud.NewView(document)
	view.Assume("vote", "hidden", true) -- set in the markup

	hud.OnClick(view, "vote-yes", function()
		if voteName and not voteOwner then Say("!vote y") end
	end)
	hud.OnClick(view, "vote-no", function()
		if voteName then Say(voteOwner and "!endvote" or "!vote n") end
	end)
	hud.OnClick(view, "vote-dismiss", function()
		if voteName then Say("!vote b") end
	end)

	hud.RegisterPanel(LAYOUT_NAME, "Vote", Place, function() return voteName ~= nil end)
	Place()
	hud.ShowPassive(document)
end

function widget:Shutdown()
	if hud then
		hud.UnregisterPanel(LAYOUT_NAME)
	end
	if document then
		document:Close()
		document = nil
	end
end

function widget:ViewResize()
	if hud and document then
		hud.UpdateScale()
		Place()
	end
end

function widget:PlayerChanged(playerID)
	mySpec = Spring.GetSpectatingState()
end

function widget:GameFrame(n)
	if n > 0 and not gameStarted then
		gameStarted = true
		myPlayerID = Spring.GetMyPlayerID()
		myName, _, mySpec, myTeamID, myAllyTeamID = Spring.GetPlayerInfo(myPlayerID, false)
		startedAsPlayer = not mySpec
	end
end

-- Esc abstains (the caller's own vote is just put away), and goes no further
function widget:KeyPress(key)
	if key == 27 and voteName then
		if not voteOwner then
			Spring.SendCommands("say !vote b")
		end
		EndVote()
		return true
	end
	return false
end

function widget:Update()
	if document then
		hud.FollowGuiHidden(document)
	end
end
