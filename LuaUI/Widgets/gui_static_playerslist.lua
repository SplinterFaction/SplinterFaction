function widget:GetInfo()
	return {
		name      = "Static Players List",
		desc      = "Static-style players list: per-player network/cpu, fps, resource bars; team grouping; collapsible spectators; dynamic alliance button; spectator click-to-follow (Player TV) with system-specs hover popup. Replaces AdvPlayersList + displayinfo.",
		author    = "",
		date      = "2026-03-22",
		license   = "GNU GPL, v2 or later",
		layer     = -4,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local bgcorner  = "LuaUI/Images/bgcorner.png"
local accentImg = ":n:LuaUI/Images/staticgui_accent.png"
local allyPic   = ":n:LuaUI/Images/ally.dds"

-- Network-cell glyphs: plain letters read best at this small size.
local GLYPH_CPU  = "C"
local GLYPH_PING = "P"

local BASE_RESOLUTION     = 1080
local PANEL_WIDTH         = 300
local MARGIN_X            = 14
local MARGIN_Y            = 14
local OUTER_CORNER        = 10
local INNER_CORNER        = 8.5
local INNER_INSET         = 2.25
local PANEL_ACCENT_HEIGHT = 5

local INNER_PAD     = 9
local TOPBAR_H      = 24
local ROW_H         = 19
local SPEC_ROW_H    = 16
local SPEC_HDR_H    = 20
local GROUP_GAP     = 7

-- Row columns (base px, scaled by uiScale)
local ALLY_W        = 18
local RES_W         = 58
local NET_W         = 26     -- two cells (cpu + ping)
local FPS_W         = 22
local COL_GAP       = 6

-- Colors
local BORDER_COLOR        = {0.15, 0.15, 0.15, 0.90}
local PANEL_BG_COLOR      = {0.05, 0.05, 0.06, 0.92}
local PANEL_BG_COLOR_GUI  = {0.00, 0.00, 0.00, 0.28}
local TOPBAR_BG           = {0.12, 0.12, 0.13, 0.85}
local GROUP_BG            = {0.10, 0.10, 0.12, 0.45}
local ROW_BG_ENEMY        = {0.16, 0.07, 0.07, 0.30}
local SPEC_HDR_BG         = {0.18, 0.18, 0.20, 0.55}
local HOVER_OVERLAY       = {0.90, 0.90, 0.90, 0.08}
local LOCKED_OVERLAY      = {0.18, 0.52, 0.98, 0.20}
local RES_METAL_C         = {0.55, 0.78, 0.90, 1}
local RES_ENERGY_C        = {0.95, 0.85, 0.25, 1}
local RES_TRACK_C         = {0.04, 0.04, 0.05, 0.85}
local ALLY_ON_C           = {0.22, 0.78, 0.35, 1}
local ALLY_OFF_C          = {0.45, 0.45, 0.48, 1}

local ACCENT_PANEL  = {0.18, 0.52, 0.98, 1}

local TEXT_COLOR    = "\255\244\244\244"
local TEXT_DIM      = "\255\160\162\168"
local TEXT_TITLE    = "\255\185\185\185"
local TEXT_VALUE    = "\255\230\230\230"

-- ping/cpu colors + thresholds (matched to AdvPlayersList)
local pingCpuColors = {
	[1] = {0.11, 0.82, 0.11},
	[2] = {0.40, 0.75, 0.20},
	[3] = {0.72, 0.72, 0.20},
	[4] = {0.82, 0.27, 0.18},
	[5] = {1.00, 0.15, 0.30},
}

-- camera-lock behavior
local lockcameraHideEnemies = true
local lockcameraLos         = true
local transitionTime        = 0.6
local listTime              = 14   -- seconds to keep a broadcaster "recent"

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local glColor    = gl.Color
local glRect     = gl.Rect
local glTexture  = gl.Texture
local glTexRect  = gl.TexRect

local spGetViewGeometry    = Spring.GetViewGeometry
local spGetMouseState      = Spring.GetMouseState
local spPlaySoundFile      = Spring.PlaySoundFile
local spGetPlayerInfo      = Spring.GetPlayerInfo
local spGetPlayerList      = Spring.GetPlayerList
local spGetTeamInfo        = Spring.GetTeamInfo
local spGetTeamColor       = Spring.GetTeamColor
local spGetTeamList        = Spring.GetTeamList
local spGetAllyTeamList    = Spring.GetAllyTeamList
local spGetTeamResources   = Spring.GetTeamResources
local spGetMyTeamID        = Spring.GetMyTeamID
local spGetMyAllyTeamID    = Spring.GetMyAllyTeamID
local spGetMyPlayerID      = Spring.GetMyPlayerID
local spGetSpectatingState = Spring.GetSpectatingState
local spAreTeamsAllied     = Spring.AreTeamsAllied
local spGetGaiaTeamID      = Spring.GetGaiaTeamID
local spGetGameFrame       = Spring.GetGameFrame
local spGetGameSpeed       = Spring.GetGameSpeed
local spGetFPS             = Spring.GetFPS
local spGetCameraState     = Spring.GetCameraState
local spSetCameraState     = Spring.SetCameraState
local spGetMapDrawMode     = Spring.GetMapDrawMode
local spSendCommands       = Spring.SendCommands
local spIsGUIHidden        = Spring.IsGUIHidden
local spGetAIInfo          = Spring.GetAIInfo

local math_floor = math.floor
local math_max   = math.max
local math_min   = math.min
local osclock    = os.clock

local function Clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

--------------------------------------------------------------------------------
-- Font
--------------------------------------------------------------------------------

local vsx, vsy      = spGetViewGeometry()
local uiScale       = 1.0
local fontfile      = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("ui_font", "Saira_SemiCondensed-SemiBold.ttf")
local fontfileScale = (0.5 + (vsx * vsy / 5700000))
local font

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local myTeamID, myAllyTeam, myPlayerID
local mySpecStatus, fullView
local fixedallies   = tonumber(Spring.GetModOptions().fixedallies)
local drawAllyButton = false

local groups        = {}    -- ordered: { allyTeam, isEnemy, teams={ {teamID,...,rows={...}} } }
local groupBgs      = {}    -- {x1,y1,x2,y2,isEnemy} drawn behind rows
local specs         = {}    -- { {id, name} }
local rows          = {}    -- flat draw/hit list built in BuildGeometry
local specsExpanded = false

local panelRect = {x1=0, y1=0, x2=0, y2=0}

-- broadcast-fed per-player data
local lastFpsData    = {}
local lastGpuMemData = {}
local lastSystemData = {}

-- camera lock state
local lockPlayerID
local lastBroadcasts      = {}
local recentBroadcasters  = {}
local myLastCameraState
local newBroadcaster      = false
local totalTime           = 0
local sceduledSpecFullView
local desiredLosmode
local desiredLosmodeChanged = 0

-- caching
local contentList  = nil
local contentDirty = true
local lastGuiShader = nil
local refreshTimer = 0

local hoveredKey = nil

--------------------------------------------------------------------------------
-- Sound
--------------------------------------------------------------------------------

local function PlayHoverSound() spPlaySoundFile("hover",     1.0, "ui") end
local function PlayClickSound() spPlaySoundFile("leftclick", 1.0, "ui") end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function GetCpuLvl(c)
	if c < 0.15 then return 1 elseif c < 0.30 then return 2
	elseif c < 0.45 then return 3 elseif c < 0.65 then return 4 else return 5 end
end

local function GetPingLvl(p)
	if p < 0.15 then return 1 elseif p < 0.30 then return 2
	elseif p < 0.70 then return 3 elseif p < 1.50 then return 4 else return 5 end
end

local function ColorEscape(r, g, b)
	return "\255" .. string.char(
		math_max(1, math_min(255, math_floor((r or 1)*255))),
		math_max(1, math_min(255, math_floor((g or 1)*255))),
		math_max(1, math_min(255, math_floor((b or 1)*255)))
	)
end

local function numFormatRes(v)
	v = math_floor(v or 0)
	if v >= 1000000 then return string.sub(v/1000000 .. '', 0, 4) .. 'M'
	elseif v >= 10000 then return string.sub(v/1000 .. '', 0, 4) .. 'k'
	else return tostring(v) end
end

-- The system string is scraped from infolog's <User System> block, whose lines
-- carry a "[t=HH:MM:SS.ffffff]" frame-time prefix. The upstream builder strips
-- "[t=" but leaves the "HH:MM:SS.ffffff]" tail, which then leaks mid-line when
-- core lines get joined. Scrub both the full prefix and the leftover fragments.
local function SanitizeSystemString(s)
	s = tostring(s or "")
	s = s:gsub("%[t=[%d:%.]+%]", "")          -- full "[t=00:00:00.008274]"
	s = s:gsub("%d%d:%d%d:%d%d%.%d+%]", "")   -- leftover "00:00:00.008274]"
	return s
end

local function GetBorderColor() return BORDER_COLOR end
local function GetPanelBGColor()
	if WG.guishader then return PANEL_BG_COLOR_GUI end
	return PANEL_BG_COLOR
end

local function RectRound(px, py, sx, sy, cs)
	px, py, sx, sy, cs = math_floor(px), math_floor(py), math_floor(sx), math_floor(sy), math_floor(cs)
	glRect(px+cs, py, sx-cs, sy)
	glRect(sx-cs, py+cs, sx, sy-cs)
	glRect(px, py+cs, px+cs, sy-cs)
	glTexture(bgcorner)
	glTexRect(px, py+cs, px+cs, py)
	glTexRect(sx, py+cs, sx-cs, py)
	glTexRect(px, sy-cs, px+cs, sy)
	glTexRect(sx, sy-cs, sx-cs, sy)
	glTexture(false)
end

local function DrawBox(x1, y1, x2, y2, col, cs)
	glColor(col[1], col[2], col[3], col[4])
	RectRound(x1, y1, x2, y2, (cs or 4)*uiScale)
end

local function DrawPanelChrome(x1, y1, x2, y2, accent)
	local bc  = GetBorderColor()
	local pc  = GetPanelBGColor()
	local oc  = OUTER_CORNER * uiScale
	local ic  = INNER_CORNER * uiScale
	local ins = INNER_INSET  * uiScale
	local ah  = PANEL_ACCENT_HEIGHT * uiScale
	glColor(bc[1], bc[2], bc[3], bc[4])
	RectRound(x1, y1, x2, y2, oc)
	glColor(pc[1], pc[2], pc[3], pc[4])
	RectRound(x1+ins, y1+ins, x2-ins, y2-ins, ic)
	if accent then
		glColor(accent[1], accent[2], accent[3], 1)
		glTexture(accentImg)
		glTexRect(x1+ins, y2-ins-ah, x2-ins, y2-ins)
		glTexture(false)
	end
end

local function InRect(x, y, r)
	return r and x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2
end

local function IsOnPanel(x, y)
	return x >= panelRect.x1 and x <= panelRect.x2 and y >= panelRect.y1 and y <= panelRect.y2
end

--------------------------------------------------------------------------------
-- Broadcast receivers (registered as globals; fed by the broadcaster gadgets)
--------------------------------------------------------------------------------

function FpsEvent(playerID, fps)
	lastFpsData[playerID] = fps
	WG.playerFPS = WG.playerFPS or {}
	WG.playerFPS[playerID] = fps
end

function GpuMemEvent(playerID, percentage)
	lastGpuMemData[playerID] = percentage
end

function SystemEvent(playerID, system)
	lastSystemData[playerID] = system
	WG.playerSystemData = WG.playerSystemData or {}
	WG.playerSystemData[playerID] = system
end

--------------------------------------------------------------------------------
-- Camera lock (faithful port from AdvPlayersList)
--------------------------------------------------------------------------------

local function UpdateRecentBroadcasters()
	recentBroadcasters = {}
	for playerID, info in pairs(lastBroadcasts) do
		local lastT = info[1]
		if (totalTime - lastT <= listTime) or playerID == lockPlayerID then
			if (totalTime - lastT <= listTime) then
				recentBroadcasters[playerID] = totalTime - lastT
			end
		end
	end
end

local function LockCamera(playerID)
	if playerID and playerID ~= myPlayerID and playerID ~= lockPlayerID then
		if lockcameraHideEnemies and not select(3, spGetPlayerInfo(playerID, false)) then
			spSendCommands("specteam " .. select(4, spGetPlayerInfo(playerID, false)))
			if not fullView then
				sceduledSpecFullView = 1
				spSendCommands("specfullview")
			else
				sceduledSpecFullView = 2
				spSendCommands("specfullview")
			end
			if lockcameraLos and mySpecStatus and spGetMapDrawMode() ~= "los" then
				desiredLosmode = 'los'
				desiredLosmodeChanged = osclock()
			end
		elseif lockcameraHideEnemies and select(3, spGetPlayerInfo(playerID, false)) then
			if not fullView then
				spSendCommands("specfullview")
			end
			desiredLosmode = 'normal'
			desiredLosmodeChanged = osclock()
		end
		lockPlayerID = playerID
		myLastCameraState = myLastCameraState or spGetCameraState()
		local info = lastBroadcasts[lockPlayerID]
		if info then
			spSetCameraState(info[2], transitionTime)
		end
	else
		if myLastCameraState then
			spSetCameraState(myLastCameraState, transitionTime)
			myLastCameraState = nil
		end
		if lockcameraHideEnemies and lockPlayerID and not select(3, spGetPlayerInfo(lockPlayerID, false)) then
			if not fullView then
				spSendCommands("specfullview")
			end
			if lockcameraLos and mySpecStatus and spGetMapDrawMode() == "los" then
				desiredLosmode = 'normal'
				desiredLosmodeChanged = osclock()
			end
		end
		lockPlayerID = nil
	end
	UpdateRecentBroadcasters()
	contentDirty = true
end

function CameraBroadcastEvent(playerID, cameraState)
	if not cameraState then
		if lastBroadcasts[playerID] then
			lastBroadcasts[playerID] = nil
			newBroadcaster = true
		end
		if lockPlayerID == playerID then
			LockCamera()
		end
		return
	end
	if not lastBroadcasts[playerID] and not newBroadcaster then
		newBroadcaster = true
	end
	lastBroadcasts[playerID] = {totalTime, cameraState}
	if playerID == lockPlayerID then
		spSetCameraState(cameraState, transitionTime)
	end
end

--------------------------------------------------------------------------------
-- Data refresh
--------------------------------------------------------------------------------

local function GetTeamDisplayName(teamID, leader, isAI)
	if isAI then
		local _, botID, _, shortName = spGetAIInfo(teamID)
		if botID then return tostring(botID) .. " (" .. tostring(shortName) .. ")" end
		return "AI " .. teamID
	end
	local name = spGetPlayerInfo(leader, false)
	return name or ("Team " .. teamID)
end

local function RefreshPlayers()
	myTeamID    = spGetMyTeamID()
	myAllyTeam  = spGetMyAllyTeamID()
	myPlayerID  = spGetMyPlayerID()
	mySpecStatus, fullView = spGetSpectatingState()
	fixedallies = tonumber(Spring.GetModOptions().fixedallies)
	drawAllyButton = (not fixedallies or fixedallies == 0) and not mySpecStatus
	local gaia = spGetGaiaTeamID and spGetGaiaTeamID() or -1

	-- human players grouped by team
	local teamPlayers = {}
	specs = {}
	for _, pid in ipairs(spGetPlayerList() or {}) do
		local name, _, spec, teamID, _, ping, cpu = spGetPlayerInfo(pid, false)
		if spec then
			specs[#specs+1] = {id = pid, name = name or ("Player " .. pid)}
		else
			teamPlayers[teamID] = teamPlayers[teamID] or {}
			teamPlayers[teamID][#teamPlayers[teamID]+1] = {id = pid, name = name or ("Player "..pid), ping = ping or 0, cpu = cpu or 0}
		end
	end

	-- ordered allyteams: own first (if a player), then ascending, skipping gaia-only
	local allyList = spGetAllyTeamList() or {}
	local order = {}
	local seen = {}
	local function addAlly(at)
		if at ~= nil and not seen[at] then seen[at] = true ; order[#order+1] = at end
	end
	if not mySpecStatus then addAlly(myAllyTeam) end
	for _, at in ipairs(allyList) do addAlly(at) end

	groups = {}
	for _, allyTeam in ipairs(order) do
		local teamsInAlly = spGetTeamList(allyTeam) or {}
		local groupTeams = {}
		for _, teamID in ipairs(teamsInAlly) do
			if teamID ~= gaia then
				local _, leader, isDead, isAI = spGetTeamInfo(teamID, false)
				local r, g, b = spGetTeamColor(teamID)
				local color = {r or 1, g or 1, b or 1}

				-- resources (gated: spec sees all; player sees own + allied)
				local readable = mySpecStatus or (allyTeam == myAllyTeam)
				local mCur, mMax, eCur, eMax
				if readable then
					local m, ms = spGetTeamResources(teamID, "metal")
					local e, es = spGetTeamResources(teamID, "energy")
					if m then mCur, mMax = m, math_max(ms or 1, 1) end
					if e then eCur, eMax = e, math_max(es or 1, 1) end
				end

				local teamRows = {}
				local plist = teamPlayers[teamID]
				if plist and #plist > 0 then
					for _, p in ipairs(plist) do
						teamRows[#teamRows+1] = {
							kind = "player", playerID = p.id, name = p.name,
							ping = p.ping, cpu = p.cpu, isAI = false,
						}
					end
				elseif isAI then
					teamRows[#teamRows+1] = {
						kind = "ai", playerID = nil, name = GetTeamDisplayName(teamID, leader, true), isAI = true,
					}
				end

				if #teamRows > 0 then
					groupTeams[#groupTeams+1] = {
						teamID = teamID, allyTeam = allyTeam, color = color, dead = isDead,
						readable = readable, mCur = mCur, mMax = mMax, eCur = eCur, eMax = eMax,
						rows = teamRows,
					}
				end
			end
		end
		if #groupTeams > 0 then
			groups[#groups+1] = {
				allyTeam = allyTeam,
				isEnemy  = (not mySpecStatus) and (allyTeam ~= myAllyTeam),
				teams    = groupTeams,
			}
		end
	end
end

--------------------------------------------------------------------------------
-- Geometry
--------------------------------------------------------------------------------

local function BuildGeometry()
	uiScale = vsy / BASE_RESOLUTION

	local pw  = PANEL_WIDTH * uiScale
	local pad = INNER_PAD   * uiScale
	local acc = PANEL_ACCENT_HEIGHT * uiScale
	local rowH = ROW_H * uiScale
	local topH = TOPBAR_H * uiScale
	local specHdrH = SPEC_HDR_H * uiScale
	local specRowH = SPEC_ROW_H * uiScale
	local gGap = GROUP_GAP * uiScale

	-- measure total height
	local totalH = pad + acc + topH
	for _, grp in ipairs(groups) do
		for _, tm in ipairs(grp.teams) do
			totalH = totalH + #tm.rows * rowH
		end
		totalH = totalH + gGap
	end
	totalH = totalH + specHdrH
	if specsExpanded then totalH = totalH + #specs * specRowH end
	totalH = totalH + pad

	local x2 = math_floor(vsx - MARGIN_X * uiScale)
	local x1 = math_floor(x2 - pw)
	local y1 = math_floor(MARGIN_Y * uiScale)
	local y2 = math_floor(y1 + totalH)
	panelRect = {x1=x1, y1=y1, x2=x2, y2=y2}

	local cx1 = x1 + pad
	local cx2 = x2 - pad
	local innerW = cx2 - cx1

	-- column x-positions (right-anchored)
	local fpsW = FPS_W * uiScale
	local netW = NET_W * uiScale
	local resW = RES_W * uiScale
	local allyW = drawAllyButton and (ALLY_W * uiScale) or 0
	local colGap = COL_GAP * uiScale

	local fpsX2 = cx2
	local fpsX1 = fpsX2 - fpsW
	local netX2 = fpsX1 - colGap
	local netX1 = netX2 - netW
	local resX2 = netX1 - colGap
	local resX1 = resX2 - resW
	local nameX1 = cx1 + allyW + (allyW > 0 and colGap or 0)
	local nameX2 = resX1 - colGap

	rows = {}
	groupBgs = {}
	local cursor = y2 - pad - acc

	-- top bar
	rows[#rows+1] = {kind="topbar", x1=cx1, y1=cursor-topH, x2=cx2, y2=cursor}
	cursor = cursor - topH

	for _, grp in ipairs(groups) do
		local groupTop = cursor
		for _, tm in ipairs(grp.teams) do
			for _, r in ipairs(tm.rows) do
				local ry2 = cursor
				local ry1 = cursor - rowH
				rows[#rows+1] = {
					kind = r.kind, playerID = r.playerID, name = r.name,
					ping = r.ping, cpu = r.cpu, isAI = r.isAI,
					teamID = tm.teamID, allyTeam = tm.allyTeam, color = tm.color, dead = tm.dead,
					readable = tm.readable, mCur = tm.mCur, mMax = tm.mMax, eCur = tm.eCur, eMax = tm.eMax,
					isEnemy = grp.isEnemy,
					x1 = cx1, y1 = ry1, x2 = cx2, y2 = ry2,
					nameX1 = nameX1, nameX2 = nameX2,
					resX1 = resX1, resX2 = resX2,
					netX1 = netX1, netX2 = netX2,
					fpsX1 = fpsX1, fpsX2 = fpsX2,
					allyRect = (drawAllyButton and grp.isEnemy) and {x1=cx1, y1=ry1+2*uiScale, x2=cx1+allyW, y2=ry2-2*uiScale} or nil,
				}
				cursor = ry1
			end
		end
		groupBgs[#groupBgs+1] = {x1=cx1, y1=cursor, x2=cx2, y2=groupTop, isEnemy=grp.isEnemy}
		cursor = cursor - gGap
	end

	-- spectator header
	rows[#rows+1] = {kind="spechdr", x1=cx1, y1=cursor-specHdrH, x2=cx2, y2=cursor}
	cursor = cursor - specHdrH
	if specsExpanded then
		for _, s in ipairs(specs) do
			rows[#rows+1] = {kind="spec", playerID=s.id, name=s.name, x1=cx1, y1=cursor-specRowH, x2=cx2, y2=cursor}
			cursor = cursor - specRowH
		end
	end
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

local function DrawResBar(x1, y1, x2, y2, cur, maxv, col)
	DrawBox(x1, y1, x2, y2, RES_TRACK_C, 2)
	if cur and maxv and maxv > 0 then
		local f = Clamp(cur / maxv, 0, 1)
		glColor(col[1], col[2], col[3], 0.85)
		glRect(x1+1, y1+1, x1 + (x2-x1-2)*f + 1, y2-1)
	end
end

local function DrawNetCell(x1, y1, x2, y2, lvl)
	if not lvl then
		glColor(0.45, 0.45, 0.45, 0.7)
	else
		local c = pingCpuColors[lvl]
		glColor(c[1], c[2], c[3], 1)
	end
	glRect(x1, y1, x2, y2)
end

local function BakeTopBar(r)
	DrawBox(r.x1, r.y1, r.x2, r.y2, TOPBAR_BG, 4)
	local _, gs = spGetGameSpeed()
	gs = string.format("%.2f", gs or 1)
	local fps = spGetFPS()
	local gf = spGetGameFrame()
	local mins = math_floor(gf / 30 / 60)
	local secs = math_floor((gf - (mins*60*30)) / 30)
	local secStr = (secs < 10) and ("0"..secs) or tostring(secs)
	local txt = TEXT_TITLE.."time "..TEXT_VALUE..mins..":"..secStr
		.. TEXT_TITLE.."   speed "..TEXT_VALUE..gs
		.. TEXT_TITLE.."   fps "..TEXT_VALUE..fps
	font:Begin()
	font:Print(txt, r.x1 + 6*uiScale, r.y1 + (r.y2-r.y1)*0.5 - 5*uiScale, 11*uiScale, "lo")
	font:End()
end

local function BakeRow(r)
	-- locked highlight
	if r.playerID and r.playerID == lockPlayerID then
		glColor(LOCKED_OVERLAY[1], LOCKED_OVERLAY[2], LOCKED_OVERLAY[3], LOCKED_OVERLAY[4])
		glRect(r.x1, r.y1, r.x2, r.y2)
	end

	local midY = r.y1 + (r.y2-r.y1)*0.5

	-- alliance button
	if r.allyRect then
		local allied = spAreTeamsAllied(r.teamID, myTeamID)
		local ac = allied and ALLY_ON_C or ALLY_OFF_C
		glColor(ac[1], ac[2], ac[3], 1)
		glTexture(allyPic)
		glTexRect(r.allyRect.x1, r.allyRect.y1, r.allyRect.x2, r.allyRect.y2)
		glTexture(false)
	end

	-- name (team color; dead = dim)
	local nameCol = r.dead and TEXT_DIM or ColorEscape(r.color[1], r.color[2], r.color[3])
	font:Begin()
	font:Print(nameCol .. r.name, r.nameX1, midY - 5*uiScale, 11*uiScale, "lo")
	font:End()

	-- resource bars (metal top, energy bottom) — only if readable
	if r.readable and (r.mCur or r.eCur) then
		local h = (r.y2 - r.y1)
		local barH = math_floor((h - 6*uiScale) * 0.5)
		local mY2 = r.y2 - 2*uiScale
		local mY1 = mY2 - barH
		local eY2 = mY1 - 2*uiScale
		local eY1 = eY2 - barH
		DrawResBar(r.resX1, mY1, r.resX2, mY2, r.mCur, r.mMax, RES_METAL_C)
		DrawResBar(r.resX1, eY1, r.resX2, eY2, r.eCur, r.eMax, RES_ENERGY_C)
	end

	-- network cells (cpu left, ping right) + fps — players only
	if r.kind == "player" then
		local cw = (r.netX2 - r.netX1 - 2*uiScale) * 0.5
		local cellY1 = midY - 7*uiScale
		local cellY2 = midY + 7*uiScale
		DrawNetCell(r.netX1, cellY1, r.netX1+cw, cellY2, GetCpuLvl(r.cpu))
		DrawNetCell(r.netX2-cw, cellY1, r.netX2, cellY2, GetPingLvl(r.ping))

		local cpuCX  = r.netX1 + cw*0.5
		local pingCX = r.netX2 - cw*0.5
		local fps = lastFpsData[r.playerID]

		font:Begin()
		-- 'v' = engine vertical-center on midY; white + outline reads on any cell color
		font:Print("\255\255\255\255" .. GLYPH_CPU,  cpuCX,  midY, 11*uiScale, "cvo")
		font:Print("\255\255\255\255" .. GLYPH_PING, pingCX, midY, 11*uiScale, "cvo")
		if fps ~= nil then
			if fps > 999 then fps = 999 end
			local bright = Clamp(0.55 + (tonumber(fps) or 0)/180, 0.55, 1.0)
			font:Print(ColorEscape(bright, bright, bright) .. tostring(fps), r.fpsX2, midY, 10*uiScale, "rvo")
		end
		font:End()
	end

	-- bottom separator
	glColor(1, 1, 1, 0.04)
	glRect(r.x1, r.y1, r.x2, r.y1+1)
end

local function BakeSpecHeader(r)
	DrawBox(r.x1, r.y1, r.x2, r.y2, SPEC_HDR_BG, 4)
	local arrow = specsExpanded and "-" or "+"
	font:Begin()
	font:Print(TEXT_DIM .. arrow .. "  Spectators (" .. #specs .. ")", r.x1 + 6*uiScale, r.y1 + (r.y2-r.y1)*0.5 - 5*uiScale, 10*uiScale, "lo")
	font:End()
end

local function BakeSpecRow(r)
	font:Begin()
	font:Print(TEXT_DIM .. r.name, r.x1 + 14*uiScale, r.y1 + (r.y2-r.y1)*0.5 - 4*uiScale, 9*uiScale, "lo")
	font:End()
end

local function BuildContentList()
	if contentList then gl.DeleteList(contentList) ; contentList = nil end
	contentList = gl.CreateList(function()
		DrawPanelChrome(panelRect.x1, panelRect.y1, panelRect.x2, panelRect.y2, ACCENT_PANEL)
		-- group backgrounds first (behind rows)
		for i = 1, #groupBgs do
			local g = groupBgs[i]
			local c = g.isEnemy and ROW_BG_ENEMY or GROUP_BG
			glColor(c[1], c[2], c[3], c[4])
			RectRound(g.x1, g.y1, g.x2, g.y2, 3*uiScale)
		end
		for i = 1, #rows do
			local r = rows[i]
			if r.kind == "topbar" then BakeTopBar(r)
			elseif r.kind == "player" or r.kind == "ai" then BakeRow(r)
			elseif r.kind == "spechdr" then BakeSpecHeader(r)
			elseif r.kind == "spec" then BakeSpecRow(r) end
		end
	end)
	lastGuiShader = (WG.guishader ~= nil)
	contentDirty = false
end

--------------------------------------------------------------------------------
-- Hover (tint, sound) + system-specs popup
--------------------------------------------------------------------------------

local function DrawSystemPopup(r, mx, my)
	local pid = r.playerID
	if not pid then return end
	local system = lastSystemData[pid]
	local fps    = lastFpsData[pid]
	local gpumem = lastGpuMemData[pid]
	local pingMs = math_floor((r.ping or 0) * 1000)
	local cpuPct = math_floor((r.cpu or 0) * 100)

	local header = r.name
	local line2  = "FPS: " .. (fps or "?") .. "    CPU: " .. cpuPct .. "%"
	if gpumem ~= nil then line2 = line2 .. "    GPU mem: " .. gpumem .. "%" end
	line2 = line2 .. "    Ping: " .. pingMs .. " ms"

	local lines = {header, line2}
	if system then
		for ln in SanitizeSystemString(system):gmatch("([^\r\n]+)") do
			ln = ln:gsub("%s%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
			if ln ~= "" then lines[#lines+1] = ln end
		end
	end

	local fsize = 11 * uiScale
	local lineH = fsize + 4*uiScale
	local maxW = 0
	for i = 1, #lines do
		local w = font:GetTextWidth(lines[i]) * fsize
		if w > maxW then maxW = w end
	end
	local boxW = maxW + 14*uiScale
	local boxH = #lines * lineH + 8*uiScale

	local bx2 = mx - 8*uiScale
	local bx1 = bx2 - boxW
	if bx1 < 4*uiScale then bx1 = 4*uiScale ; bx2 = bx1 + boxW end
	local by2 = Clamp(my + boxH*0.5, boxH + 4*uiScale, vsy - 4*uiScale)
	local by1 = by2 - boxH

	glColor(0, 0, 0, 0.88)
	RectRound(bx1, by1, bx2, by2, 4*uiScale)
	glColor(ACCENT_PANEL[1], ACCENT_PANEL[2], ACCENT_PANEL[3], 1)
	glTexture(accentImg)
	glTexRect(bx1, by2-3*uiScale, bx2, by2)
	glTexture(false)

	font:Begin()
	for i = 1, #lines do
		local col = (i == 1) and TEXT_COLOR or ((i == 2) and "\255\233\180\180" or TEXT_DIM)
		font:Print(col .. lines[i], bx1 + 7*uiScale, by2 - 6*uiScale - i*lineH + lineH*0.25, fsize, "lo")
	end
	font:End()
end

local function DrawHover(mx, my)
	local newHover = nil
	local popupRow = nil

	for i = 1, #rows do
		local r = rows[i]
		if r.kind == "player" or r.kind == "ai" then
			-- alliance button hover
			if r.allyRect and InRect(mx, my, r.allyRect) then
				glColor(HOVER_OVERLAY[1], HOVER_OVERLAY[2], HOVER_OVERLAY[3], 0.18)
				RectRound(r.allyRect.x1, r.allyRect.y1, r.allyRect.x2, r.allyRect.y2, 3*uiScale)
				newHover = "ally"..i
			end
			-- whole-row hover (for click-to-follow when spectating)
			if mySpecStatus and r.playerID and mx >= r.x1 and mx <= r.x2 and my >= r.y1 and my <= r.y2 then
				glColor(HOVER_OVERLAY[1], HOVER_OVERLAY[2], HOVER_OVERLAY[3], HOVER_OVERLAY[4])
				glRect(r.x1, r.y1, r.x2, r.y2)
				newHover = newHover or ("row"..i)
			end
			-- net-cell hover → system popup
			if r.kind == "player" and mx >= r.netX1 and mx <= r.fpsX2 and my >= r.y1 and my <= r.y2 then
				popupRow = r
			end
		elseif r.kind == "spechdr" then
			if InRect(mx, my, r) then
				glColor(HOVER_OVERLAY[1], HOVER_OVERLAY[2], HOVER_OVERLAY[3], HOVER_OVERLAY[4])
				RectRound(r.x1, r.y1, r.x2, r.y2, 4*uiScale)
				newHover = "spechdr"
			end
		end
	end

	if popupRow then DrawSystemPopup(popupRow, mx, my) end

	if newHover ~= hoveredKey then
		if newHover then PlayHoverSound() end
		hoveredKey = newHover
	end
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

function widget:IsAbove(x, y)
	return IsOnPanel(x, y)
end

function widget:MousePress(x, y, button)
	if not IsOnPanel(x, y) then return false end
	return true   -- consume so clicks don't leak to the world
end

function widget:MouseRelease(x, y, button)
	if not IsOnPanel(x, y) then return false end
	if button ~= 1 then return true end

	for i = 1, #rows do
		local r = rows[i]
		if r.kind == "spechdr" and InRect(x, y, r) then
			specsExpanded = not specsExpanded
			PlayClickSound()
			BuildGeometry()
			contentDirty = true
			return true
		end

		if (r.kind == "player" or r.kind == "ai") then
			-- alliance toggle
			if r.allyRect and InRect(x, y, r.allyRect) then
				if drawAllyButton then
					if spAreTeamsAllied(r.teamID, myTeamID) then
						spSendCommands("ally " .. r.allyTeam .. " 0")
					else
						spSendCommands("ally " .. r.allyTeam .. " 1")
					end
					PlayClickSound()
				end
				return true
			end
			-- click-to-follow (spectator only)
			if mySpecStatus and r.playerID and x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2 then
				PlayClickSound()
				if r.playerID == lockPlayerID then
					LockCamera()      -- release
				else
					LockCamera(r.playerID)
				end
				return true
			end
		end
	end
	return true
end

--------------------------------------------------------------------------------
-- advplayerlist_api shim (so camera_player_tv.lua keeps working untouched)
--------------------------------------------------------------------------------

local function PublishApi()
	WG['advplayerlist_api'] = {}
	WG['advplayerlist_api'].GetPosition = function()
		-- Consumers (camera_player_tv) read [1] as the bottom anchor and grow
		-- upward from it. Returning the panel TOP as [1] makes Player TV's small
		-- panel sit directly above this bottom-right list instead of overlapping.
		-- {anchorBottom, left, bottom, right, widgetScale}
		return {panelRect.y2, panelRect.x1, panelRect.y1, panelRect.x2, uiScale}
	end
	WG['advplayerlist_api'].GetLockPlayerID = function()
		return lockPlayerID
	end
	WG['advplayerlist_api'].SetLockPlayerID = function(playerID)
		LockCamera(playerID)
	end
	-- harmless stubs in case other widgets probe these
	WG['advplayerlist_api'].GetLockHideEnemies = function() return lockcameraHideEnemies end
	WG['advplayerlist_api'].SetLockHideEnemies = function(v) lockcameraHideEnemies = v end
	WG['advplayerlist_api'].GetLockLos = function() return lockcameraLos end
	WG['advplayerlist_api'].SetLockLos = function(v) lockcameraLos = v end
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function widget:Initialize()
	-- suppress engine fps/clock/speed (we show them in the top bar)
	spSendCommands("fps 0")
	spSendCommands("clock 0")
	spSendCommands("speed 0")

	vsx, vsy = spGetViewGeometry()
	fontfileScale = (0.5 + (vsx * vsy / 5700000))
	font = gl.LoadFont(fontfile, 23*fontfileScale, 5*fontfileScale, 1.8)

	widgetHandler:RegisterGlobal('FpsEvent', FpsEvent)
	widgetHandler:RegisterGlobal('GpuMemEvent', GpuMemEvent)
	widgetHandler:RegisterGlobal('SystemEvent', SystemEvent)
	widgetHandler:RegisterGlobal('CameraBroadcastEvent', CameraBroadcastEvent)

	RefreshPlayers()
	BuildGeometry()
	PublishApi()
	contentDirty = true
end

function widget:Shutdown()
	if contentList then gl.DeleteList(contentList) ; contentList = nil end
	if font then gl.DeleteFont(font) end

	widgetHandler:DeregisterGlobal('FpsEvent')
	widgetHandler:DeregisterGlobal('GpuMemEvent')
	widgetHandler:DeregisterGlobal('SystemEvent')
	widgetHandler:DeregisterGlobal('CameraBroadcastEvent')

	WG['advplayerlist_api'] = nil

	spSendCommands("fps 1")
	spSendCommands("clock 1")
	spSendCommands("speed 1")
end

function widget:ViewResize(nx, ny)
	vsx, vsy = nx, ny
	local newScale = (0.5 + (vsx * vsy / 5700000))
	if newScale ~= fontfileScale then
		fontfileScale = newScale
		if font then gl.DeleteFont(font) end
		font = gl.LoadFont(fontfile, 23*fontfileScale, 5*fontfileScale, 1.8)
	end
	RefreshPlayers()
	BuildGeometry()
	contentDirty = true
end

function widget:Update(dt)
	totalTime = totalTime + dt
	mySpecStatus, fullView = spGetSpectatingState()

	-- deferred specfullview re-apply (minimap/world refresh)
	if sceduledSpecFullView ~= nil then
		spSendCommands("specfullview")
		sceduledSpecFullView = sceduledSpecFullView - 1
		if sceduledSpecFullView == 0 then sceduledSpecFullView = nil end
	end

	-- deferred LOS toggle (within 1s of a lock change)
	if lockcameraLos then
		if desiredLosmodeChanged + 1 > osclock() then
			if lockPlayerID ~= nil then
				if desiredLosmode ~= spGetMapDrawMode() then
					spSendCommands("togglelos")
				end
			elseif mySpecStatus and spGetMapDrawMode() == 'los' then
				spSendCommands("togglelos")
			end
		end
	end

	-- keep camera following while locked
	if lockPlayerID ~= nil then
		spSetCameraState(spGetCameraState(), transitionTime)
	end

	refreshTimer = refreshTimer + dt
	if refreshTimer >= 1.0 then
		refreshTimer = 0
		RefreshPlayers()
		BuildGeometry()
		contentDirty = true
	end
end

function widget:DrawScreen()
	if spIsGUIHidden() then return end
	if not font then return end

	local guiShaderActive = (WG.guishader ~= nil)
	if contentDirty or not contentList or guiShaderActive ~= lastGuiShader then
		BuildContentList()
	end

	gl.CallList(contentList)

	local mx, my = spGetMouseState()
	DrawHover(mx, my)
end
