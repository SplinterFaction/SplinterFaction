function widget:GetInfo()
	return {
		name    = "Options (New)",
		desc    = "Modular options UI (Graphics + Sound)",
		author  = "",
		date    = "2025",
		license = "GPL",
		layer   = 20000,
		enabled = false
	}
end

local vsx, vsy = Spring.GetViewGeometry()
local show = true
local currentTab = "gfx"
local draggingSlider = nil

-------------------------------------------------------
-- Draw order
-------------------------------------------------------
local optionOrder = {"gfxpreset","fullscreen","resolution","shadows","water","particles"}
local soundOptionOrder = {
	"snd_volmaster",
	"snd_volbattle",
	"snd_volgeneral",
	"snd_volmusic",
	"snd_volui",
	"snd_volunitreply"
}

-------------------------------------------------------
-- Forward declare options
-------------------------------------------------------
local options = {}

-------------------------------------------------------
-- Utility: switch preset to Custom if manual change
-------------------------------------------------------
local function SetPresetToCustom()
	options.gfxpreset.value = #options.gfxpreset.options -- last = Custom
end

-------------------------------------------------------
-- Apply graphics presets
-------------------------------------------------------
local function ApplyGraphicsPreset(preset)
	Spring.Echo("Applying preset: " .. tostring(preset))

	if preset == "Lowest" then
		options.shadows.value = 0
		options.water.value = 1
		options.particles.value = 1000
	elseif preset == "Low" then
		options.shadows.value = 1
		options.water.value = 2
		options.particles.value = 3000
	elseif preset == "Medium" then
		options.shadows.value = 2
		options.water.value = 3
		options.particles.value = 6000
	elseif preset == "High" then
		options.shadows.value = 3
		options.water.value = 4
		options.particles.value = 9000
	elseif preset == "Ultra" then
		options.shadows.value = 5
		options.water.value = 4
		options.particles.value = 12000
	end

	-- Apply changes to graphics options only (skip preset itself)
	for _, id in ipairs(optionOrder) do
		if id ~= "gfxpreset" then
			local opt = options[id]
			if opt and opt.onChange then
				opt.onChange(opt.value, true) -- skip custom switch
			end
		end
	end
end

-------------------------------------------------------
-- Options definition
-------------------------------------------------------
options = {
	gfxpreset = {
		id="gfxpreset", group="gfx", name="Graphics Preset", type="select",
		options={"Lowest","Low","Medium","High","Ultra","Custom"}, value=3,
		onChange=function(index)
			local preset = options.gfxpreset.options[index]
			if preset and preset ~= "Custom" then
				ApplyGraphicsPreset(preset)
			end
		end
	},
	fullscreen = {
		id="fullscreen", group="gfx", name="Fullscreen", type="bool", value=true,
		onChange=function(v, skipCustom)
			Spring.SendCommands("Fullscreen "..(v and 1 or 0))
			if not skipCustom then SetPresetToCustom() end
		end
	},
	resolution = {
		id="resolution", group="gfx", name="Resolution", type="select",
		options={"1920x1080","2560x1440","3840x2160"}, value=1,
		onChange=function(index, skipCustom)
			local res = options.resolution.options[index]
			if res then Spring.SendCommands("Resolution "..res) end
			if not skipCustom then SetPresetToCustom() end
		end
	},
	shadows = {
		id="shadows", group="gfx", name="Shadows", type="slider", min=0, max=5, value=2,
		onChange=function(v, skipCustom)
			Spring.SendCommands("Shadows "..v)
			if not skipCustom then SetPresetToCustom() end
		end
	},
	water = {
		id="water", group="gfx", name="Water Quality", type="select",
		options={"Basic","Reflective","Dynamic","Bumpmapped","Ultra"}, value=3,
		onChange=function(index, skipCustom)
			Spring.SendCommands("Water "..(index-1))
			if not skipCustom then SetPresetToCustom() end
		end
	},
	particles = {
		id="particles", group="gfx", name="Max Particles", type="slider", min=500, max=12000, value=6000,
		onChange=function(v, skipCustom)
			Spring.SetConfigInt("MaxParticles", v)
			if not skipCustom then SetPresetToCustom() end
		end
	},

	-- Sound Options
	snd_volmaster = {
		id="snd_volmaster", group="sound", name="Master Volume", type="slider",
		min=0, max=200, value=Spring.GetConfigInt("snd_volmaster", 60) or 60,
		onChange=function(v) Spring.SetConfigInt("snd_volmaster", v) end
	},
	snd_volbattle = {
		id="snd_volbattle", group="sound", name="Battle Volume", type="slider",
		min=0, max=200, value=Spring.GetConfigInt("snd_volbattle", 100) or 100,
		onChange=function(v) Spring.SetConfigInt("snd_volbattle", v) end
	},
	snd_volgeneral = {
		id="snd_volgeneral", group="sound", name="General Volume", type="slider",
		min=0, max=200, value=Spring.GetConfigInt("snd_volgeneral", 100) or 100,
		onChange=function(v) Spring.SetConfigInt("snd_volgeneral", v) end
	},
	snd_volmusic = {
		id="snd_volmusic", group="sound", name="Music Volume", type="slider",
		min=0, max=200, value=Spring.GetConfigInt("snd_volmusic", 100) or 100,
		onChange=function(v) Spring.SetConfigInt("snd_volmusic", v) end
	},
	snd_volui = {
		id="snd_volui", group="sound", name="UI Volume", type="slider",
		min=0, max=200, value=Spring.GetConfigInt("snd_volui", 100) or 100,
		onChange=function(v) Spring.SetConfigInt("snd_volui", v) end
	},
	snd_volunitreply = {
		id="snd_volunitreply", group="sound", name="Unit Reply Volume", type="slider",
		min=0, max=200, value=Spring.GetConfigInt("snd_volunitreply", 100) or 100,
		onChange=function(v) Spring.SetConfigInt("snd_volunitreply", v) end
	}
}

local tabs = {
	{id="gfx", name="Graphics"},
	{id="sound", name="Sound"}
}

-------------------------------------------------------
-- Helpers
-------------------------------------------------------
local function IsOnRect(x, y, x1, y1, x2, y2)
	return x >= x1 and x <= x2 and y >= y1 and y <= y2
end

-------------------------------------------------------
-- Handle slider selection
-------------------------------------------------------
local function FindSlider(mx, my)
	local winX, winY, winW, winH = vsx/2-250, vsy/2-200, 500, 400
	local ox, oy = winX+20, winY+winH-70
	local drawOrder = (currentTab == "gfx") and optionOrder or soundOptionOrder
	for _, id in ipairs(drawOrder) do
		local opt = options[id]
		if opt.group == currentTab and opt.type == "slider" then
			local sx, sy, sw = ox+150, oy, 100
			if IsOnRect(mx,my, sx, sy-4, sx+sw, sy+10) then
				return opt, sx, sw
			end
		end
		if opt.group == currentTab then
			oy = oy - 30
		end
	end
	return nil
end

-------------------------------------------------------
-- Drawing controls
-------------------------------------------------------
local function DrawBool(opt, x, y)
	local size = 20
	gl.Color(0.2,0.2,0.2,0.8)
	gl.Rect(x, y, x+size, y+size)
	if opt.value then
		gl.Color(0,1,0,0.8)
		gl.Rect(x+3, y+3, x+size-3, y+size-3)
	end
end

local function DrawSlider(opt, x, y, w)
	local value = (opt.value - opt.min)/(opt.max - opt.min)
	local handleX = x + (w * value)
	gl.Color(0.3,0.3,0.3,0.8)
	gl.Rect(x, y, x+w, y+4)
	gl.Color(1,0.8,0,0.8)
	gl.Rect(handleX-3, y-3, handleX+3, y+7)
end

local function DrawSelect(opt, x, y, w)
	gl.Color(0.3,0.3,0.3,0.8)
	gl.Rect(x, y, x+w, y+20)
	gl.Color(1,1,1,1)
	local valueText = opt.options[opt.value] or "?"
	gl.Text(valueText, x+5, y+5, 12, "o")
end

-------------------------------------------------------
-- Mouse handling
-------------------------------------------------------
local function MousePress(mx,my)
	local winX, winY, winW, winH = vsx/2-250, vsy/2-200, 500, 400

	-- Tabs
	local tabX = winX + 10
	for _,tab in ipairs(tabs) do
		if IsOnRect(mx,my, tabX, winY+winH-40, tabX+80, winY+winH-20) then
			currentTab = tab.id
			return true
		end
		tabX = tabX + 85
	end

	-- Options
	local ox, oy = winX+20, winY+winH-70
	local drawOrder = (currentTab == "gfx") and optionOrder or soundOptionOrder
	for _, id in ipairs(drawOrder) do
		local opt = options[id]
		if opt.group == currentTab then
			if opt.type == "bool" and IsOnRect(mx,my, ox+150, oy-4, ox+170, oy+16) then
				opt.value = not opt.value
				if opt.onChange then opt.onChange(opt.value) end
				return true
			elseif opt.type == "select" and IsOnRect(mx,my, ox+150, oy-4, ox+250, oy+16) then
				opt.value = opt.value + 1
				if opt.value > #opt.options then opt.value = 1 end
				if opt.onChange then opt.onChange(opt.value) end
				return true
			elseif opt.type == "slider" and IsOnRect(mx,my, ox+150, oy-4, ox+250, oy+16) then
				draggingSlider = {opt=opt, x=ox+150, w=100}
				return true
			end
			oy = oy - 30
		end
	end
	return false
end

local function MouseMove(mx,my)
	if draggingSlider then
		local opt = draggingSlider.opt
		local rel = (mx - draggingSlider.x) / draggingSlider.w
		rel = math.max(0, math.min(1, rel))
		opt.value = math.floor(opt.min + rel * (opt.max - opt.min))
		if opt.onChange then opt.onChange(opt.value) end
	end
end

local function MouseRelease()
	draggingSlider = nil
end

-------------------------------------------------------
-- Draw window
-------------------------------------------------------
local function DrawWindow()
	local winX, winY, winW, winH = vsx/2-250, vsy/2-200, 500, 400
	gl.Color(1,0,0,0.5)
	gl.Rect(winX, winY, winX+winW, winY+winH)

	gl.Color(1,1,1,1)
	gl.Text("OPTIONS", winX+20, winY+winH-20, 20, "o")

	-- Tabs
	local tabX = winX + 10
	for _,tab in ipairs(tabs) do
		local selected = (tab.id == currentTab)
		gl.Color(selected and 0.3 or 0.2, selected and 0.6 or 0.2, selected and 1 or 0.2, 0.6)
		gl.Rect(tabX, winY+winH-40, tabX+80, winY+winH-20)
		gl.Color(1,1,1,1)
		gl.Text(tab.name, tabX+5, winY+winH-35, 12, "o")
		tabX = tabX + 85
	end

	-- Options
	local ox, oy = winX+20, winY+winH-70
	local drawOrder = (currentTab == "gfx") and optionOrder or soundOptionOrder
	for _, id in ipairs(drawOrder) do
		local opt = options[id]
		if opt.group == currentTab then
			gl.Color(1,1,1,1)
			gl.Text(opt.name, ox, oy, 12, "o")
			if opt.type == "bool" then
				DrawBool(opt, ox+150, oy-4)
			elseif opt.type == "slider" then
				DrawSlider(opt, ox+150, oy, 100)
			elseif opt.type == "select" then
				DrawSelect(opt, ox+150, oy-4, 100)
			end
			oy = oy - 30
		end
	end
end

-------------------------------------------------------
-- Widget handlers
-------------------------------------------------------
function widget:DrawScreen()
	if show then DrawWindow() end
end

function widget:MousePress(x,y,button)
	if not show then return false end
	return MousePress(x,y)
end

function widget:MouseMove(x,y,dx,dy,button)
	if show then MouseMove(x,y) end
end

function widget:MouseRelease(x,y,button)
	if show then MouseRelease() end
end

function widget:KeyPress(key)
	if key == 111 then -- F3
		show = not show
		return true
	end
end
