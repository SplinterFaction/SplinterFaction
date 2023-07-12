
if addon.InGetInfo then
	return {
		name    = "Main",
		desc    = "displays a simplae loadbar",
		author  = "jK",
		date    = "2012,2013",
		license = "GPL2",
		layer   = 0,
		depend  = {"LoadProgress"},
		enabled = true,
	}
end

local defaultFont = 'Saira_SemiCondensed-SemiBold.ttf'
local fontfile = 'luaui/fonts/'..Spring.GetConfigString("ui_font", defaultFont)
if not VFS.FileExists(fontfile) then
	Spring.SetConfigString('ui_font', defaultFont)
	fontfile = 'luaui/fonts/'..defaultFont
end
local defaultFont2 = 'Saira_SemiCondensed-SemiBold.ttf'
local fontfile2 = 'luaui/fonts/'..Spring.GetConfigString("ui_font2", defaultFont2)
if not VFS.FileExists(fontfile2) then
	Spring.SetConfigString('ui_font2', defaultFont2)
	fontfile2 = 'luaui/fonts/'..defaultFont2
end
------------------------------------------

local showTips = true
--[[
if (Spring.GetConfigInt("LoadscreenTips",1) or 1) == 0 then
	showTips = false
end
]]--

local lastLoadMessage = ""

function addon.LoadProgress(message, replaceLastLine)
	lastLoadMessage = message
end

------------------------------------------

-- Random tips we can show
local titleColor = "\255\215\255\215"
local contentColor = "\255\255\255\255"
local highlightColor = "\255\255\255\0"
local newLine = "\n"
local tips = {
	"loadingpics/xtadeus.dds "..titleColor.."Xtadeus\n"..contentColor.."Composer of all of the music in the game. Check out his channel on youtube!" .. newLine .. highlightColor .. "www.youtube.com/@xtadeus4777",
	[[Press Enter to Chat:
Press Ctrl+Enter to switch to All Chat
Press Alt+Enter to switch to Ally Chat
Press Shift+Enter to switch to Spectator Chat]],
}

-- Random unit descriptions we can show
local titleColor = "\255\215\255\215"
local contentColor = "\255\255\255\255"
local unit_descs = {

	"fedmenlo.dds "..titleColor.."Menlo" .. newLine .. contentColor .. "The penultimate in defense matricies.",
	"loadingpics/defensematrix.dds " .. titleColor .."Menlo" .. newLine .. contentColor .."The penultimate in defense matricies.",
}

local quotes = {
	{"Strategy without tactics is the slowest route to victory. Tactics without strategy is the noise before defeat.", "Sun Tzu"},
	{"He will win who knows when to fight and when not to fight.", "Sun Tzu"},
	{"When I have won a victory I do not repeat my tactics but respond to circumstances in an infinite variety of ways.", "Sun Tzu"},
	{"The art of war is the art of deception.", "Sun Tzu"},
	{"Brains will always conquer brawn, in the end. The soldiers can flex their muscles all they want, but the well-thought-out tactics of the generals are what win the war.", "Patrick Hall"},
	{"The best defense is a confusing offense.", "Kimberly Pauley"},
	{"When your opponent is making a mistake, do nothing to interfere.", "Napoleon Bonaparte"},
	{"Effective strategy considers and plans for its own failure.", "Eric Engle"},
	{"No campaign plan survives first contact with the enemy.", "Carl von Clausewitz"},
	{"Tactics is the art of using troops in battle; strategy is the art of using battles to win the war.", "Carl von Clausewitz"},
	{"The enemy of a good plan is the dream of a perfect plan.", "Carl von Clausewitz"},
	{"Where absolute superiority is not attainable, you must produce a relative one at the decisive point by making skillful use of what you have.", "Carl von Clausewitz"},
	{"The best form of defense is attack.", "Carl von Clausewitz"},
}


-- Since math.random is not random and always the same, we save a counter to a file and use that.
filename = "LuaUI/Config/randomseed.data"
k = os.time() % 1500
if VFS.FileExists(filename) then
	k = VFS.LoadFile(filename)
end
k = tonumber(k) + 1
local file = assert(io.open(filename,'w'), "Unable to save latest randomseed from "..filename)
    file:write(k)
    file:close()
file = nil

local random_tip_or_desc = unit_descs[((k/2) % #unit_descs) + 1]
if k%2 == 1 then
	random_tip_or_desc = tips[((math.ceil(k/2)) % #tips) + 1]
elseif k%3 == 2 then
	random_tip_or_desc = quotes[((math.ceil(k/3)) % #quotes) + 1]
end

local loadedFontSize = 70
local font = gl.LoadFont(fontfile, 70, 22, 1.15)

local engineVersion = 100 -- just filled this in here incorrectly but old engines arent used anyway
if Engine and Engine.version then
	local function Split(s, separator)
		local results = {}
		for part in s:gmatch("[^"..separator.."]+") do
			results[#results + 1] = part
		end
		return results
	end
	engineVersion = Split(Engine.version, '-')
	if engineVersion[2] ~= nil and engineVersion[3] ~= nil then
		engineVersion = tonumber(string.gsub(engineVersion[1], '%.', '')..engineVersion[2])
	else
		engineVersion = tonumber(Engine.version)
	end
elseif Game and Game.version then
	engineVersion = tonumber(Game.version)
end

function DrawRectRound(px,py,sx,sy,cs)

	--local csx = cs
	--local csy = cs
	--if sx-px < (cs*2) then
	--	csx = (sx-px)/2
	--	if csx < 0 then csx = 0 end
	--end
	--if sy-py < (cs*2) then
	--	csy = (sy-py)/2
	--	if csy < 0 then csy = 0 end
	--end
	--cs = math.min(cs, csy)

	gl.TexCoord(0.8,0.8)
	gl.Vertex(px+cs, py, 0)
	gl.Vertex(sx-cs, py, 0)
	gl.Vertex(sx-cs, sy, 0)
	gl.Vertex(px+cs, sy, 0)

	gl.Vertex(px, py+cs, 0)
	gl.Vertex(px+cs, py+cs, 0)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.Vertex(px, sy-cs, 0)
	
	gl.Vertex(sx, py+cs, 0)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.Vertex(sx, sy-cs, 0)
	
	local offset = 0.05		-- texture offset, because else gaps could show
	local o = offset
	
	-- top left
	--if py <= 0 or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, py, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(px+cs, py, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(px+cs, py+cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(px, py+cs, 0)
	-- top right
	--if py <= 0 or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(sx-cs, py, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(sx, py+cs, 0)
	-- bottom left
	--if sy >= vsy or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, sy, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(px+cs, sy, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(px, sy-cs, 0)
	-- bottom right
	--if sy >= vsy or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(sx-cs, sy, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(sx, sy-cs, 0)
end

function RectRound(px,py,sx,sy,cs)
	--local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.ceil(sx),math.ceil(sy),math.floor(cs)
	
	gl.Texture(":n:luaui/Images/bgcorner.png")
	--gl.Texture(":n:luaui/Images/bgcorner.png")
	gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs)
	gl.Texture(false)
end

function gradienth(px,py,sx,sy, c1,c2)
	gl.Color(c1)
	gl.Vertex(sx, sy, 0)
	gl.Vertex(sx, py, 0)
	gl.Color(c2)
	gl.Vertex(px, py, 0)
	gl.Vertex(px, sy, 0)
end


local lastLoadMessage = ""
local lastProgress = {0, 0}

local progressByLastLine = {
	["Parsing Map Information"] = {0, 20},
	["Loading Weapon Definitions"] = {10, 50},
	["Loading LuaRules"] = {40, 80},
	["Loading LuaUI"] = {70, 95},
	["Finalizing"] = {100, 100}
}
for name,val in pairs(progressByLastLine) do
	progressByLastLine[name] = {val[1]*0.01, val[2]*0.01}
end

function addon.LoadProgress(message, replaceLastLine)
	lastLoadMessage = message
	if message:find("Path") then -- pathing has no rigid messages so cant use the table
		lastProgress = {0.8, 1.0}
	end
	lastProgress = progressByLastLine[message] or lastProgress
end

function addon.DrawLoadScreen()
	local loadProgress = SG.GetLoadProgress()
	if loadProgress == 0 then
		loadProgress = lastProgress[1]
	else
		loadProgress = math.min(math.max(loadProgress, lastProgress[1]), lastProgress[2])
	end

	local vsx, vsy = gl.GetViewSizes()

	-- draw progressbar
	local hbw = 3.5/vsx
	local vbw = 3.5/vsy
	local hsw = 0.2
	local vsw = 0.2
	local yPos =  0.125 --0.054
	local yPosTips = yPos + 0.1245
	local loadvalue = 0.2 + (math.max(0, loadProgress) * 0.6)

	if not showTips then
		yPos = 0.165
		yPosTips = yPos
	end

	--bar bg
	local paddingH = 0.004
	local paddingW = paddingH * (vsy/vsx)
	gl.Color(0.085,0.085,0.085,0.925)
	RectRound(0.2-paddingW,yPos-0.05-paddingH,0.8+paddingW,yPosTips+paddingH,0.007)

	gl.Color(0,0,0,0.75)
	RectRound(0.2-paddingW,yPos-0.05-paddingH,0.8+paddingW,yPos+paddingH,0.007)

    if loadvalue > 0.215 then
	    -- loadvalue
        gl.Color(0.4-(loadProgress/7),loadProgress*0.4,0,0.4)
        RectRound(0.2,yPos-0.05,loadvalue,yPos,0.0055)

        -- loadvalue gradient
        gl.Texture(false)
        gl.BeginEnd(GL.QUADS, gradienth, 0.2,yPos-0.05,loadvalue,yPos, {1-(loadProgress/3)+0.2,loadProgress+0.2,0+0.08,0.14}, {0,0,0,0.14})

        -- loadvalue inner glow
        gl.Color(1-(loadProgress/3.5)+0.15,loadProgress+0.15,0+0.05,0.04)
        gl.Texture(":n:luaui/Images/barglow-center.png")
        gl.TexRect(0.2,yPos-0.05,loadvalue,yPos)

        -- loadvalue glow
        local glowSize = 0.06
        gl.Color(1-(loadProgress/3)+0.15,loadProgress+0.15,0+0.05,0.1)
        gl.Texture(":n:luaui/Images/barglow-center.png")
        gl.TexRect(0.2,	yPos-0.05-glowSize,	loadvalue,	yPos+glowSize)

        gl.Texture(":n:luaui/Images/barglow-edge.png")
        gl.TexRect(0.2-(glowSize*1.3), yPos-0.05-glowSize, 0.2, yPos+glowSize)
        gl.TexRect(loadvalue+(glowSize*1.3), yPos-0.05-glowSize, loadvalue, yPos+glowSize)
    end

	-- progressbar text
	gl.PushMatrix()
		gl.Scale(1/vsx,1/vsy,1)
		local barTextSize = vsy * 0.026

		--font:Print(lastLoadMessage, vsx * 0.5, vsy * 0.3, 50, "sc")
		--font:Print(Game.gameName, vsx * 0.5, vsy * 0.95, vsy * 0.07, "sca")
		font:Print(lastLoadMessage, vsx * 0.21, vsy * (yPos-0.017), barTextSize * 0.67, "oa")
		if loadProgress>0 then
			font:Print(("%.0f%%"):format(loadProgress * 100), vsx * 0.5, vsy * (yPos-0.0325), barTextSize, "oc")
		else
			font:Print("Loading...", vsx * 0.5, vsy * (yPos-0.031), barTextSize, "oc")
		end
	gl.PopMatrix()


	if showTips then
		-- In this format, there can be an optional image before the tip/description.
		-- Any image ends in .dds, so if such a text piece is found, we extract that and show it as an image.
		local text_to_show = random_tip_or_desc
		yPos = yPosTips
		if random_tip_or_desc[2] then
			text_to_show = random_tip_or_desc[1]
		else
			i, j = string.find(random_tip_or_desc, ".dds")
		end
		local numLines = 1
		local image_text = nil
		local fontSize = barTextSize * 0.77
		local image_size = 0.0485
		local height = 0.123

		if i ~= nil then
			text_to_show = string.sub(text_to_show, j+2)
			local maxWidth = ((0.58-image_size-0.012) * vsx) * (loadedFontSize/fontSize)
			text_to_show, numLines = font:WrapText(text_to_show, maxWidth)
		else
			local maxWidth = (0.585 * vsx) * (loadedFontSize/fontSize)
			text_to_show, numLines = font:WrapText(text_to_show, maxWidth)
		end

		-- Tip/unit description
		-- Background
		--gl.Color(1,1,1,0.033)
		--RectRound(0.2,yPos-height,0.8,yPos,0.005)

		-- Text
		gl.PushMatrix()
		gl.Scale(1/vsx,1/vsy,1)

		if i ~= nil then
			image_text = string.sub(random_tip_or_desc, 0, j)
			gl.Texture(":n:unitpics/" .. image_text)
			gl.Color(1.0,1.0,1.0,0.8)
			gl.TexRect(vsx * 0.21, (vsy*(yPos-0.015))-(vsx*image_size), vsx*(0.21+image_size), vsy*(yPos-0.015),false,false)
			font:Print(text_to_show, vsx * (0.21+image_size+0.012) , vsy * (yPos-0.0175), fontSize, "oa")
		else
			font:Print(text_to_show, vsx * 0.21, vsy * (yPos-0.0175), fontSize, "oa")
		end

		if random_tip_or_desc[2] then
			font:Print('\255\255\222\155'..random_tip_or_desc[2], vsx * 0.79, (vsy * ((yPos-0.0175)-height)) +(fontSize*2.66) , fontSize, "oar")
		end
		gl.PopMatrix()
	end
end


function addon.MousePress(...)
	--Spring.Echo(...)
end


function addon.Shutdown()
	gl.DeleteFont(font)
end