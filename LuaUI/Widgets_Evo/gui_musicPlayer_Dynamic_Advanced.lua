--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--	file: gui_musicPlayer.lua
--	brief:	yay music
--	author:	cake
--
--	Copyright (C) 2007.
--	Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
math.randomseed( os.time() - os.clock() * 1000 )
math.random() math.random() math.random()

function widget:GetInfo()
	return {
		name	= "Music Player - Dynamic Advanced",
		desc	= "Plays music and offers volume controls with dynamic swells and fades based upon what is happening in the game.",
		author	= "Forboding Angel, Floris, Damgam",
		date	= "november 2016",
		license	= "GNU GPL, v2 or later",
		layer	= -4,
		enabled	= false	--	loaded by default?
	}
end

local pauseWhenPaused = false


local fontfile = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("ui_font", "JosefinSans-SemiBold.ttf")
local vsx,vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx*vsy / 5700000))
local fontfileSize = 36
local fontfileOutlineSize = 8.5
local fontfileOutlineStrength = 1.33
local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity",0.66) or 0.66)

local guishaderEnabled = (WG['guishader'])

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Unfucked volumes finally. Instead of setting the volume in Spring.PlaySoundStream. you need to call Spring.PlaySoundStream and then immediately call Spring.SetSoundStreamVolume
-- This widget desperately needs to be reorganized

local buttons = {}

local previousTrack = ''
local curTrack	= "no name"

local peaceTracks = VFS.DirList('luaui/Widgets_Evo/Music/peace', '*.ogg')
local warTracks = VFS.DirList('luaui/Widgets_Evo/Music/war', '*.ogg')
local warCutTracks = VFS.DirList('luaui/Widgets_Evo/Music/warcut', '*.ogg')
local silenceTracks = VFS.DirList('luaui/Widgets_Evo/Music/silence', '*.ogg')
local loadingTracks = VFS.DirList('luaui/Widgets_Evo/Music/loading', '*.ogg')


--We check to make sure that we can function properly without crashing due to missing music tracks
local next = next
if next(peaceTracks) == nil then
	Spring.Echo("[Music Player] No Peace tracks were found (you must have at least 2)! Add some and try again!")
	return false
end

if next(warTracks) == nil then
	Spring.Echo("[Music Player] No War tracks were found (you must have at least 2)! Add some and try again!")
	return false
end

if next(warCutTracks) == nil then
	warCutTracks = warTracks
end

--local tracks = peaceTracks
local tracks = loadingTracks
 
local firstTime = false
local wasPaused = false
local firstFade = true
local gameOver = false
local playing = true

local playedTime, totalTime = Spring.GetSoundStreamTime()
local playTex				= ":n:"..LUAUI_DIRNAME.."Images/music/play.png"
local pauseTex				= ":n:"..LUAUI_DIRNAME.."Images/music/pause.png"
local nextTex				= ":n:"..LUAUI_DIRNAME.."Images/music/next.png"
local musicTex				= ":n:"..LUAUI_DIRNAME.."Images/music/music.png"
local volumeTex				= ":n:"..LUAUI_DIRNAME.."Images/music/volume.png"
local buttonTex				= ":n:"..LUAUI_DIRNAME.."Images/button.dds"
local buttonHighlightTex				= ":n:"..LUAUI_DIRNAME.."Images/button-highlight.dds"
local bgcorner				= ":n:"..LUAUI_DIRNAME.."Images/bgcorner.png"

local widgetScale = 1
local glBlending     = gl.Blending
local glScale        = gl.Scale
local glRotate       = gl.Rotate
local glTranslate	   = gl.Translate
local glPushMatrix   = gl.PushMatrix
local glPopMatrix	   = gl.PopMatrix
local glColor        = gl.Color
local glRect         = gl.Rect
local glTexRect	     = gl.TexRect
local glTexture      = gl.Texture
local glCreateList   = gl.CreateList
local glDeleteList   = gl.DeleteList
local glCallList     = gl.CallList

local drawlist = {}
local advplayerlistPos = {}
local widgetHeight = 23
local top, left, bottom, right = 0,0,0,0
local borderPadding = 5

local shown = false
local mouseover = false
local volume

local warMeter = 0
local buildMeter = false
local buildTimer = 0
local fadelvl = Spring.GetConfigInt("snd_volmusic", 20) * 0.01 or 0.2
local fadeOut = false
local fadeIn = false
local endFade = false
local maxWarMeter = 1500

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:Initialize()
	
	MyTeamID = Spring.GetMyTeamID()
	
	volume = Spring.GetConfigInt("snd_volmaster", 100)
	music_volume_set = Spring.GetConfigInt("snd_volmusic", 20) * 0.01
	music_volume_target = music_volume_set
	
	musicInitialValue = Spring.GetConfigInt("evo_musicInitialValue", 0)
	if musicInitialValue ~= 1 then
		Spring.SetConfigInt("snd_volmusic", 20)
		Spring.SetConfigInt("evo_musicInitialValue", 1)
	end
	
	music_volume = Spring.GetConfigInt("snd_volmusic", 20)
	
	if #tracks == 0 then 
		Spring.Echo("[Music Player] No music was found, Shutting Down")
		widgetHandler:RemoveWidget()
	end
	
	updatePosition()
	
	WG['music'] = {}
	WG['music'].GetPosition = function()
		return {top,left,bottom,right,widgetScale}
	end
end


local function DrawRectRound(px,py,sx,sy,cs)
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
	if py <= 0 or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, py, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(px+cs, py, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(px+cs, py+cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(px, py+cs, 0)
	-- top right
	if py <= 0 or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(sx-cs, py, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(sx, py+cs, 0)
	-- bottom left
	if sy >= vsy or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, sy, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(px+cs, sy, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(px, sy-cs, 0)
	-- bottom right
	if sy >= vsy or sx >= vsx then o = 0.5 else o = offset end
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
	local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.ceil(sx),math.ceil(sy),math.floor(cs)
	
	gl.Texture(bgcorner)
	gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs)
	gl.Texture(false)
end

local function createList()
	
	local padding = 3*widgetScale -- button background margin
	local padding2 = 2.5*widgetScale -- inner icon padding
	local volumeWidth = 50*widgetScale
	
	buttons['playpause'] = {left+padding, bottom+padding, left+(widgetHeight*widgetScale)-padding, top-padding}
	
	buttons['next'] = {buttons['playpause'][3]+padding, bottom+padding, buttons['playpause'][3]+((widgetHeight*widgetScale)-padding), top-padding}
	
	buttons['musicvolumeicon'] = {buttons['next'][3]+padding+padding, bottom+padding, buttons['next'][3]+((widgetHeight*widgetScale)), top-padding}
	buttons['musicvolume'] = {buttons['musicvolumeicon'][3]+padding, bottom+padding, buttons['musicvolumeicon'][3]+padding+volumeWidth, top-padding}
	buttons['musicvolume'][5] = buttons['musicvolume'][1] + (buttons['musicvolume'][3] - buttons['musicvolume'][1]) * (music_volume/100)
	
	buttons['volumeicon'] = {buttons['musicvolume'][3]+padding+padding+padding, bottom+padding, buttons['musicvolume'][3]+((widgetHeight*widgetScale)), top-padding}
	buttons['volume'] = {buttons['volumeicon'][3]+padding, bottom+padding, buttons['volumeicon'][3]+padding+volumeWidth, top-padding}
	buttons['volume'][5] = buttons['volume'][1] + (buttons['volume'][3] - buttons['volume'][1]) * (volume/100)
	
	local textsize = 11*widgetScale
	local textYPadding = 8*widgetScale
	local textXPadding = 7*widgetScale
	local maxTextWidth = right-buttons['next'][3]-textXPadding-textXPadding
		
	if drawlist[1] ~= nil then
		glDeleteList(drawlist[1])
		glDeleteList(drawlist[2])
		glDeleteList(drawlist[3])
	end
	if (WG['guishader'] ~= nil) then
		WG['guishader'].InsertRect(left, bottom, right, top,'music')
	end
	drawlist[1] = glCreateList( function()
		glColor(0, 0, 0, ui_opacity)
		RectRound(left, bottom, right, top, 5.5*widgetScale)

		borderPadding = 3*widgetScale
		borderPaddingRight = borderPadding
		if right >= vsx-0.2 then
			borderPaddingRight = 0
		end
		borderPaddingLeft = borderPadding
		if left <= 0.2 then
			borderPaddingLeft = 0
		end
		glColor(1,1,1,ui_opacity*0.055)
		RectRound(left+borderPaddingLeft, bottom+borderPadding, right-borderPaddingRight, top-borderPadding, borderPadding*1.66)
	end)
	drawlist[2] = glCreateList( function()
	
		local button = 'playpause'
		glColor(1,1,1,0.7)
		glTexture(buttonTex)
		glTexRect(buttons[button][1], buttons[button][2], buttons[button][3], buttons[button][4])
		glColor(1,1,1,0.4)
		if playing then
			glTexture(pauseTex)
		else
			glTexture(playTex)
		end
		glTexRect(buttons[button][1]+padding2, buttons[button][2]+padding2, buttons[button][3]-padding2, buttons[button][4]-padding2)
		
		button = 'next'
		glColor(1,1,1,0.7)
		glTexture(buttonTex)
		glTexRect(buttons[button][1], buttons[button][2], buttons[button][3], buttons[button][4])
		glColor(1,1,1,0.4)
		glTexture(nextTex)
		glTexRect(buttons[button][1]+padding2, buttons[button][2]+padding2, buttons[button][3]-padding2, buttons[button][4]-padding2)
		
	end)
	drawlist[3] = glCreateList( function()
		
		-- track name
		glColor(0.45,0.45,0.45,1)
		
		local trackname = string.gsub(curTrack, ".ogg", "")
		local text = ''
		--local charactersToCut = GetPathLenght()
		charactersInPath = 23
		if tracks and tracks == peaceTracks then
			charactersInPath = charactersInPath + 8
		elseif tracks and tracks == warTracks then
			charactersInPath = charactersInPath + 6
		elseif tracks and tracks == warCutTracks then
			charactersInPath = charactersInPath + 9
		elseif tracks and tracks == silenceTracks then
			charactersInPath = 999
		elseif tracks and tracks == loadingTracks then
			charactersInPath = charactersInPath + 10
		end
		for i=charactersInPath, #trackname do
	    local c = string.sub(trackname, i,i)
			local width = font:GetTextWidth(text..c)*textsize
	    if width > maxTextWidth then
	    	break
	    else
	    	text = text..c
	    end
		end
		font:Begin()
		font:Print('\255\255\255\135'..text, buttons['next'][3]+textXPadding, bottom+textYPadding, textsize, 'no')
		font:End()
		
	end)
	drawlist[4] = glCreateList( function()
		
		---glColor(0,0,0,0.5)
		--RectRound(left, bottom, right, top, 5.5*widgetScale)

		local sliderWidth = 3.3*widgetScale
		local sliderHeight = 3.3*widgetScale
		local lineHeight = 0.8*widgetScale
		local lineOutlineSize = 0.85*widgetScale
		
		button = 'musicvolumeicon'
		local sliderY = buttons[button][2] + (buttons[button][4] - buttons[button][2])/2
		glColor(0.66,0.66,0.66,1)
		glTexture(musicTex)
		glTexRect(buttons[button][1]+padding2, buttons[button][2]+padding2, buttons[button][3]-padding2, buttons[button][4]-padding2)
		
		button = 'musicvolume'
		glColor(0,0,0,0.12)
		RectRound(buttons[button][1]-lineOutlineSize, sliderY-lineHeight-lineOutlineSize, buttons[button][3]+lineOutlineSize, sliderY+lineHeight+lineOutlineSize, (lineHeight/2.2)*widgetScale)
		glColor(0.45,0.45,0.45,1)
		RectRound(buttons[button][1], sliderY-lineHeight, buttons[button][3], sliderY+lineHeight, (lineHeight/2.2)*widgetScale)
		glColor(0,0,0,0.12)
		RectRound(buttons[button][5]-sliderWidth-lineOutlineSize, sliderY-sliderHeight-lineOutlineSize, buttons[button][5]+sliderWidth+lineOutlineSize, sliderY+sliderHeight+lineOutlineSize, (sliderWidth/4)*widgetScale)
		glColor(0.66,0.66,0.66,1)
		RectRound(buttons[button][5]-sliderWidth, sliderY-sliderHeight, buttons[button][5]+sliderWidth, sliderY+sliderHeight, (sliderWidth/4)*widgetScale)


		button = 'volumeicon'
		glColor(0.66,0.66,0.66,1)
		glTexture(volumeTex)
		glTexRect(buttons[button][1]+padding2, buttons[button][2]+padding2, buttons[button][3]-padding2, buttons[button][4]-padding2)
		
		button = 'volume'
		glColor(0,0,0,0.12)
		RectRound(buttons[button][1]-lineOutlineSize, sliderY-lineHeight-lineOutlineSize, buttons[button][3]+lineOutlineSize, sliderY+lineHeight+lineOutlineSize, (lineHeight/2.2)*widgetScale)
		glColor(0.45,0.45,0.45,1)
		RectRound(buttons[button][1], sliderY-lineHeight, buttons[button][3], sliderY+lineHeight, (lineHeight/2.2)*widgetScale)
		glColor(0,0,0,0.12)
		RectRound(buttons[button][5]-sliderWidth-lineOutlineSize, sliderY-sliderHeight-lineOutlineSize, buttons[button][5]+sliderWidth+lineOutlineSize, sliderY+sliderHeight+lineOutlineSize, (sliderWidth/4)*widgetScale)
		glColor(0.66,0.66,0.66,1)
		RectRound(buttons[button][5]-sliderWidth, sliderY-sliderHeight, buttons[button][5]+sliderWidth, sliderY+sliderHeight, (sliderWidth/4)*widgetScale)
		
	end)
end

function getSliderValue(draggingSlider, x)
	local sliderWidth = buttons[draggingSlider][3] - buttons[draggingSlider][1]
	local value = (x - buttons[draggingSlider][1]) / (sliderWidth)
	if value < 0 then value = 0 end
	if value > 1 then value = 1 end
	return value
end

function isInBox(mx, my, box)
  return mx > box[1] and my > box[2] and mx < box[3] and my < box[4]
end


function widget:MouseMove(x, y)
	if draggingSlider ~= nil then
		if draggingSlider == 'musicvolume' then
			changeMusicVolume(getSliderValue('musicvolume', x) * 100)
			fadelvl = getSliderValue('musicvolume', x)
			--Spring.Echo("Music volume set to: " .. (getSliderValue('musicvolume', x) * 100))
		end
		if draggingSlider == 'volume' then
			changeVolume(getSliderValue('volume', x) * 100)
			--Spring.Echo("Global volume set to: " .. changeVolume(getSliderValue('volume', x) * 100))
		end
	end
end

function widget:MousePress(x, y, button)
	return mouseEvent(x, y, button, false)
end

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end

function changeMusicVolume(value)
	music_volume = value
	Spring.SetConfigInt("snd_volmusic", music_volume)
  createList()
end

function changeVolume(value)
	volume = value
	Spring.SetConfigInt("snd_volmaster", volume)
  createList()
end

function mouseEvent(x, y, button, release)
	if Spring.IsGUIHidden() then return false end

	if not release then
		local sliderWidth = (3.3*widgetScale) -- should be same as in createlist()
		local button = 'musicvolume'
		if isInBox(x, y, {buttons[button][1]-sliderWidth, buttons[button][2], buttons[button][3]+sliderWidth, buttons[button][4]}) then
			draggingSlider = button
			changeMusicVolume(getSliderValue(button, x) * 100)
		end
		button = 'volume'
		if isInBox(x, y, {buttons[button][1]-sliderWidth, buttons[button][2], buttons[button][3]+sliderWidth, buttons[button][4]}) then
			draggingSlider = button
			changeVolume(getSliderValue(button, x) * 100)
		end
	end
	if release and draggingSlider ~= nil then
		draggingSlider = nil
	end
	if button == 1 and not release and isInBox(x, y, {left, bottom, right, top}) then
		if button == 1 and buttons['playpause'] ~= nil and isInBox(x, y, {buttons['playpause'][1], buttons['playpause'][2], buttons['playpause'][3], buttons['playpause'][4]}) then
			playing = not playing
			Spring.PauseSoundStream()
			createList()
			return true
		end
		if button == 1 and buttons['next'] ~= nil and isInBox(x, y, {buttons['next'][1], buttons['next'][2], buttons['next'][3], buttons['next'][4]}) then
			fadeIn = false
			fadeOut = false
			PlayNewTrack()
			return true
		end
		return true
	end
	
end

function widget:IsAbove(mx, my)
	if isInBox(mx, my, {left, bottom, right, top}) then
  	local curVolume = Spring.GetConfigInt("snd_volmaster", 100)
  	if volume ~= curVolume then
  		volume = curVolume
  		createList()
  	end
		mouseover = true
	end
	return mouseover
end

function widget:GetTooltip(mx, my)
	if widget:IsAbove(mx,my) then
		return string.format("Music info and controls")
	end
end

function widget:Shutdown()
	Spring.StopSoundStream()
	
	if (WG['guishader'] ~= nil) then
		WG['guishader'].RemoveRect('music')
	end
	
	for i=1,#drawlist do
		glDeleteList(drawlist[i])
	end
	WG['music'] = nil
	gl.DeleteFont(font)
end

function widget:UnitDamaged()
	warMeter = maxWarMeter
	if warMeter > maxWarMeter then
		warMeter = maxWarMeter
	end
end


function widget:GameFrame(n)
	--Spring.Echo([[Warmeter: ]] ..warMeter)
		--This is a little messy, but we need to be able to update these values on the fly so I see no better way
		if n%120 == 0 and tracks ~= loadingTracks then
			music_volume_set = Spring.GetConfigInt("snd_volmusic", 20) * 0.01
			music_volume_target = music_volume_set
		end
	if music_volume_set > 0.02 then
			
			prevfadelvl = fadelvl
		--VolumeTargets
		if tracks == warTracks or tracks == warCutTracks then
			local playedTime, totalTime = Spring.GetSoundStreamTime()
			if fadelvl and fadelvl < music_volume_set*0.4 and playedTime > 10 then
				music_volume_target = 0
			elseif warMeter > 0 then
				music_volume_target = music_volume_set
			else
				music_volume_target = 0
			end
		elseif tracks == peaceTracks then
			if warMeter > 0 or buildTimer <= 0 then
				music_volume_target = 0
			else
				music_volume_target = music_volume_set
			end
		elseif gameOver then
			music_volume_target = music_volume_set
		elseif tracks == loadingTracks then
			music_volume_target = 0
		end
		
		--BuildMeter
		local mc, ms, mp, mi, me = Spring.GetTeamResources(MyTeamID, "metal")
		
		if me and me > 1 then
			buildMeter = true
		else
			buildMeter = false
		end
		
		if buildMeter == false then
			if buildTimer > 0 then
				buildTimer = buildTimer - 1
			end
		elseif buildMeter == true then
			buildTimer = 450
		end
		--Spring.Echo("BuildMeter: " .. buildMeter)
		
		--WarMeter
		if warMeter <= 0 then
			warMeter = 0
		elseif warMeter >= 0 then
			warMeter = warMeter - 1
		end
		
		--80's fadeout when a track is almost finished
		local playedTime, totalTime = Spring.GetSoundStreamTime()
		playedTime = math.floor(playedTime)
		totalTime = math.floor(totalTime)
			
		if totalTime ~= nil then
			--Spring.Echo("Total time is :" .. playedTime .."/".. totalTime)
			if playedTime >= totalTime - 2 then
				--Spring.Echo("Fading out now!")
				if Spring.GetGameFrame() >= 1 then
					endFade = true
					
				end
				if Spring.GetGameFrame() == 0 then
					PlayNewTrack()
				end
			end
		end

		--This has become the preferred handler of playing new tracks instead of calling the PlayNewTrack() function, set fadeOut = true
		
		--endfade
		if endFade == true then
			warMeter = 0
			fadelvl = fadelvl - 0.01
			Spring.SetSoundStreamVolume(fadelvl)
		end
		
		--volumecontrol
		if endFade == false then
			if fadelvl < 0 then
				fadelvl = 0
			end
			if fadelvl < music_volume_target then
				if tracks == peaceTracks then
					fadelvl = fadelvl + 0.001
				elseif playedTime < 5 then
					fadelvl = fadelvl + 0.03
				else
					fadelvl = fadelvl + 0.003
				end
				Spring.SetSoundStreamVolume(fadelvl)
			end
			if fadelvl > music_volume_target then
				if tracks == peaceTracks and warMeter > 0 then
					fadelvl = fadelvl - 0.01
				else
					fadelvl = fadelvl - 0.001
				end
				Spring.SetSoundStreamVolume(fadelvl)
			end
		end
		
		--playnewtrack
		if fadelvl <= 0 then
			PlayNewTrack()
		end
		
		if tracks == silenceTracks then
			if warMeter > 0 or buildTimer > 0 then
				PlayNewTrack()
			end
		end
		
		if gameOver and tracks ~= loadingTracks then
			PlayNewTrack()
		end
	end
end

function PlayNewTrack()
	local oldPlayedTime, oldTotalTime = Spring.GetSoundStreamTime()
	Spring.StopSoundStream()
	endFade = false
	fadelvl = 0.02
	if warMeter < 100 then
		warMeter = 0
	else
		warMeter = 200
	end
	
		--Spring.Echo("Unit Death Count is (Gameframe): " .. warMeter)
		if gameOver then
			tracks = loadingTracks
			fadelvl = music_volume_set
			warMeter = 0
			buildTimer = 450
		elseif Spring.GetGameFrame() == 0 then
			tracks = peaceTracks
			fadelvl = music_volume_set
		elseif warMeter <= 0 then
			if buildTimer > 10 then
				tracks = peaceTracks
				--Spring.Echo("Current tracklist is : Peace Tracks")
			else
				tracks = silenceTracks
				--Spring.Echo("Current tracklist is : Silence Tracks")
			end
		else
			if tracks == peaceTracks or tracks == silenceTracks then
				local r = math.random(0,4)
				if r ~= 0 and oldPlayedTime > 10 then
					tracks = warCutTracks
					--Spring.Echo("Current tracklist is : WarCut Tracks")
				else
					tracks = warTracks
					--Spring.Echo("Current tracklist is : War Tracks")
				end
				
			else
				tracks = warTracks
				--Spring.Echo("Current tracklist is : War Tracks")
			end
	end
	local newTrack = previousTrack
	repeat
		newTrack = tracks[math.random(1, #tracks)]
	until newTrack ~= previousTrack
	firstFade = false
	previousTrack = newTrack
	curTrack = newTrack
	Spring.PlaySoundStream(newTrack)
	Spring.SetSoundStreamVolume(fadelvl or 0.5)
	if playing == false then
		Spring.PauseSoundStream()
	end	
	createList()
end

local uiOpacitySec = 0
function widget:Update(dt)
	if gameOver then
		return
	end
	uiOpacitySec = uiOpacitySec + dt
	if uiOpacitySec>0.5 then
		uiOpacitySec = 0
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity",0.66) or guishaderEnabled ~= (WG['guishader']) then
			ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)
			guishaderEnabled = (WG['guishader'])
			createList()
		end
	end
	local playedTime, totalTime = Spring.GetSoundStreamTime()
		playedTime = math.floor(playedTime)
		totalTime = math.floor(totalTime)
	if music_volume_set > 0.02 then
		if (not firstTime) then
			if Spring.GetGameFrame() >= 1 then
				fadelvl = 0.02
			end
			--if Spring.GetGameFrame() == 0 then
				--PlayNewTrack()
			--end
			firstTime = true -- pop this cherry
		end

		if playedTime >= totalTime then	-- both zero means track stopped in 8
			if Spring.GetGameFrame() >= 1 then
				fadelvl = 0
			end
			if Spring.GetGameFrame() == 0 then
				PlayNewTrack()
			end
			if gameOver then
				PlayNewTrack()
			end
		end
		
		if (pauseWhenPaused and Spring.GetGameSeconds()>=0) then
		local _, _, paused = Spring.GetGameSpeed()
			if (paused ~= wasPaused) then
				Spring.PauseSoundStream()
				wasPaused = paused
			end
		end
	elseif playedTime > 0 and totalTime > 0 then
		Spring.StopSoundStream()
	end
end

function updatePosition(force)
	if (WG['advplayerlist_api'] ~= nil) then
		local prevPos = advplayerlistPos
		advplayerlistPos = WG['advplayerlist_api'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
		
		left = advplayerlistPos[2]
		bottom = advplayerlistPos[1]
		right = advplayerlistPos[4]
		top = advplayerlistPos[1]+(widgetHeight*advplayerlistPos[5])
		widgetScale = advplayerlistPos[5]
		
		if (prevPos[1] == nil or prevPos[1] ~= advplayerlistPos[1] or prevPos[2] ~= advplayerlistPos[2] or prevPos[5] ~= advplayerlistPos[5]) or force then
			createList()
		end
	end
end

function widget:ViewResize(newX,newY)
	vsx, vsy = newX, newY
	local newFontfileScale = (0.5 + (vsx*vsy / 5700000))
	if (fontfileScale ~= newFontfileScale) then
		fontfileScale = newFontfileScale
		gl.DeleteFont(font)
		font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreen()
	if chobbyInterface then return end
	updatePosition()
	if drawlist[1] ~= nil then
		glPushMatrix()
			glCallList(drawlist[1])
			glCallList(drawlist[2])
		  local mx, my, mlb = Spring.GetMouseState()
			if not mouseover and not draggingSlider or isInBox(mx, my, {buttons['playpause'][1], buttons['next'][2], buttons['next'][3], buttons['next'][4]}) then
				glCallList(drawlist[3])
			else
				glCallList(drawlist[4])
			end
			if mouseover then

			  -- display play progress
			  local progressPx = ((right-left)*(playedTime/totalTime))
			  if progressPx > 1 then
			    if progressPx < borderPadding*5 then
			    	progressPx = borderPadding*5
			    end
			    glColor(1,1,1,ui_opacity*0.09)
			    RectRound(left+borderPaddingLeft, bottom+borderPadding, left-borderPaddingRight+progressPx , top-borderPadding, borderPadding*1.66)
			  end

			  local color = {1,1,1,0.25}
			  local colorHighlight = {1,1,1,0.33}
			  local button = 'playpause'
				if buttons[button] ~= nil and isInBox(mx, my, {buttons[button][1], buttons[button][2], buttons[button][3], buttons[button][4]}) then
					if mlb then
						glColor(colorHighlight)
					else
						glColor(color)
					end
					glTexture(buttonHighlightTex)
					glTexRect(buttons[button][1], buttons[button][2], buttons[button][3], buttons[button][4])
				end
				button = 'next'
				if buttons[button] ~= nil and isInBox(mx, my, {buttons[button][1], buttons[button][2], buttons[button][3], buttons[button][4]}) then
					if mlb then
						glColor(colorHighlight)
					else
						glColor(color)
					end
					glTexture(buttonHighlightTex)
					glTexRect(buttons[button][1], buttons[button][2], buttons[button][3], buttons[button][4])
				end
			end
		glPopMatrix()
		mouseover = false
	end
end

function widget:GetConfigData(data)
	--local playedTime, totalTime = Spring.GetSoundStreamTime()
  local savedTable = {}
  --savedTable.curTrack	= curTrack
  --savedTable.playedTime = playedTime
  savedTable.playing = playing
  return savedTable
end

-- would be great if there is be a way to continue track where we left off after a /luaui reload
function widget:SetConfigData(data)
	if data.playing ~= nil then
		playing = data.playing
	end
end

function widget.GameOver()
	gameOver = true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------