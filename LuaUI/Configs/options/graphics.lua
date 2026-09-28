--------------------------------------------------------------------------------
-- Graphics tab
--
-- One table per option. See the header of gui_static_options.lua for every
-- field. To add an option, add a table; nothing else needs to change.
--------------------------------------------------------------------------------

-- Presets apply a set of option ids in one go. Ids that do not exist (for
-- example a widget that has been removed) are skipped silently.
local PRESETS = {
	{ name = "Lowest", values = {
		msaa = 0, shadows = false, water = 1, decals = 0, grounddetail = 64,
		particles = 5000, nanoparticles = 200, softparticles = false,
		bloom = false, tonemap = false, cas = false, ssao = false,
		lighteffects = false, distortion = false, outline = false, lups = false,
		aircrafttrails = false, snow = false, weather = false, guishader = false,
	}},
	{ name = "Low", values = {
		msaa = 2, shadows = true, shadowmapsize = 1024, water = 2, decals = 1, grounddetail = 64,
		particles = 10000, nanoparticles = 400, softparticles = true,
		bloom = false, tonemap = true, cas = false, ssao = false,
		lighteffects = true, distortion = false, outline = false, lups = true,
		aircrafttrails = true, snow = false, weather = false, guishader = false,
	}},
	{ name = "Medium", values = {
		msaa = 4, shadows = true, shadowmapsize = 2048, water = 4, decals = 2, grounddetail = 128,
		particles = 15000, nanoparticles = 800, softparticles = true,
		bloom = true, tonemap = true, cas = true, ssao = false,
		lighteffects = true, distortion = true, outline = false, lups = true,
		aircrafttrails = true, snow = true, weather = true, guishader = false,
	}},
	{ name = "High", values = {
		msaa = 8, shadows = true, shadowmapsize = 4096, water = 4, decals = 3, grounddetail = 200,
		particles = 20000, nanoparticles = 1500, softparticles = true,
		bloom = true, tonemap = true, cas = true, ssao = true, ssaoquality = 2,
		lighteffects = true, distortion = true, outline = true, lups = true,
		aircrafttrails = true, snow = true, weather = true, guishader = true,
	}},
	{ name = "Ultra", values = {
		msaa = 16, shadows = true, shadowmapsize = 8192, water = 4, decals = 5, grounddetail = 200,
		particles = 30000, nanoparticles = 3000, softparticles = true,
		bloom = true, tonemap = true, cas = true, ssao = true, ssaoquality = 3,
		lighteffects = true, lighteffectsshadows = 3, distortion = true, outline = true, lups = true,
		aircrafttrails = true, snow = true, weather = true, guishader = true,
	}},
}

local presetNames = {}
for i = 1, #PRESETS do presetNames[i] = PRESETS[i].name end

-- Resolution list: common sizes plus whatever the engine reported in infolog
local function BuildResolutionList()
	local list = { "1280 x 720", "1600 x 900", "1920 x 1080", "2560 x 1080", "2560 x 1440", "3440 x 1440", "3840 x 2160" }
	local seen = {}
	for i = 1, #list do seen[list[i]] = true end
	local infolog = VFS.LoadFile("infolog.txt")
	if infolog then
		local collecting = false
		for line in infolog:gmatch("[^\r\n]+") do
			if collecting then
				local w, h = line:match("(%d+)x(%d+)")
				if w and h and tonumber(w) >= 640 and tonumber(h) >= 480 then
					local res = w .. " x " .. h
					if not seen[res] then list[#list + 1] = res; seen[res] = true end
				else
					break
				end
			elseif line:find("\tdisplay=", 1, true) then
				collecting = true
			end
		end
	end
	local vsx, vsy = Spring.GetViewGeometry()
	local cur = vsx .. " x " .. vsy
	if not seen[cur] then list[#list + 1] = cur end
	return list
end
local resolutions = BuildResolutionList()

local function CurrentResolutionIndex()
	local vsx, vsy = Spring.GetViewGeometry()
	local cur = vsx .. " x " .. vsy
	for i = 1, #resolutions do if resolutions[i] == cur then return i end end
	return 1
end

local function ApplyResolution(idx)
	local w, h = resolutions[idx]:match("(%d+) x (%d+)")
	w, h = tonumber(w), tonumber(h)
	if not (w and h) then return end
	if Spring.GetConfigInt("Fullscreen", 1) == 1 then
		Spring.SendCommands("fullscreen 0")
		Spring.SetConfigInt("XResolution", w)
		Spring.SetConfigInt("YResolution", h)
		Spring.SendCommands("fullscreen 1")
	else
		Spring.SendCommands("fullscreen 1")
		Spring.SetConfigInt("XResolutionWindowed", w)
		Spring.SetConfigInt("YResolutionWindowed", h)
		Spring.SendCommands("fullscreen 0")
	end
end

return {
	id = "gfx", name = "Graphics", order = 10,
	options = {
		{ id = "preset", name = "Graphics preset", type = "select", options = presetNames, transient = true, placeholder = "Apply a preset...",
		  desc = "Sets a bundle of options below at once. You can adjust anything afterwards.",
		  set = function(idx)
			local p = PRESETS[idx]
			if not p then return end
			for id, v in pairs(p.values) do OPT.set(id, v) end
			Spring.Echo("[Options] applied graphics preset: " .. p.name)
		  end },

		{ type = "separator", name = "Display" },
		{ id = "resolution", name = "Resolution", type = "select", options = resolutions,
		  get = CurrentResolutionIndex, set = ApplyResolution,
		  desc = "Changing resolution in windowed mode can occasionally freeze the engine." },
		{ id = "fullscreen", name = "Fullscreen", type = "bool", config = "Fullscreen", cmd = "fullscreen %d",
		  onSet = function(v) if v then Spring.SetConfigInt("WindowBorderless", 0) end end },
		{ id = "borderless", name = "Borderless window", type = "bool", config = "WindowBorderless", restart = true,
		  desc = "Takes effect next game. Turn fullscreen off for this to apply.",
		  onSet = function(v)
			if v then
				Spring.SetConfigInt("Fullscreen", 0)
				Spring.SetConfigInt("WindowPosX", 0)
				Spring.SetConfigInt("WindowPosY", 0)
				Spring.SetConfigInt("WindowState", 0)
			else
				Spring.SetConfigInt("WindowState", 1)
			end
		  end },
		{ id = "vsync", name = "V-sync", type = "bool", config = "VSync", cmd = "vsync %d" },
		{ id = "msaa", name = "Anti-aliasing (MSAA)", type = "slider", steps = {0, 2, 4, 8, 16}, config = "MSAALevel", restart = true, format = "%dx",
		  desc = "Multisample anti-aliasing. Higher values cost GPU time." },

		{ type = "separator", name = "World" },
		{ id = "shadows", name = "Shadows", type = "bool", config = "Shadows", cmd = "shadows %d",
		  desc = "Requires advanced map shading.",
		  children = {
			{ id = "shadowmapsize", name = "Shadow detail", type = "slider", steps = {1024, 2048, 4096, 8192}, config = "ShadowMapSize", cmd = "shadows 1 %d" },
			{ id = "shadowopacity", name = "Shadow opacity", type = "slider", min = 0.3, max = 1, step = 0.01,
			  get = function() return gl.GetSun("shadowDensity") end,
			  set = function(v) Spring.SetSunLighting({ groundShadowDensity = v, modelShadowDensity = v }) end },
		  } },
		{ id = "water", name = "Water", type = "select", options = {"Basic", "Reflective", "Dynamic", "Reflective and refractive", "Bump-mapped"},
		  values = {0, 1, 2, 3, 4}, config = "Water", cmd = "water %d" },
		{ id = "decals", name = "Ground decals", type = "slider", min = 0, max = 5, step = 1, config = "GroundDecals", cmd = "grounddecals %d",
		  desc = "How long scars, tracks and building shading stay on the ground. 0 disables them." },
		{ id = "grounddetail", name = "Ground detail", type = "slider", min = 32, max = 200, step = 1, config = "GroundDetail", cmd = "grounddetail %d",
		  desc = "Terrain mesh detail. Above 120 is hard to notice; 64 is a sensible default." },
		{ id = "featuredrawdist", name = "Feature draw distance", type = "slider", min = 2500, max = 15000, step = 500, config = "FeatureDrawDistance",
		  desc = "Wrecks, rocks and other features stop drawing beyond this distance." },
		{ id = "grass", name = "Grass", type = "bool", widget = "Map Grass GL4", requires = "Map Grass GL4" },
		{ id = "particles", name = "Max particles", type = "slider", min = 5000, max = 100000, step = 1000, config = "MaxParticles",
		  desc = "Explosions, smoke, fire and trails. Too low and some effects will not show." },
		{ id = "nanoparticles", name = "Max nano particles", type = "slider", min = 0, max = 5000, step = 100, config = "MaxNanoParticles",
		  desc = "Nano particles are CPU heavy." },
		{ id = "softparticles", name = "Soft particles", type = "bool", config = "softparticles",
		  desc = "Particles fade where they intersect terrain instead of clipping." },
		{ id = "disticon", name = "Strategic icon distance", type = "slider", min = 0, max = 900, step = 10, config = "UnitIconDist", cmd = "disticon %d",
		  desc = "Camera height at which units become icons. Lower is cheaper." },
		{ id = "minimapiconscale", name = "Minimap icon scale", type = "slider", min = 1.5, max = 5, step = 0.25, config = "MinimapIconScale", cmd = "minimap unitsize %s" },

		{ type = "separator", name = "Post-processing" },
		{ id = "bloom", name = "Bloom", type = "bool", widget = "Bloom (Mip Chain)", requires = "Bloom (Mip Chain)",
		  desc = "Bright and emissive surfaces glow.",
		  children = {
			{ id = "bloomintensity", name = "Intensity", type = "slider", min = 0, max = 2, step = 0.05, api = {"bloom", "getIntensity", "setIntensity"}, configVar = {"Bloom (Mip Chain)", "intensity"} },
			{ id = "bloomthreshold", name = "Threshold", type = "slider", min = 0, max = 1, step = 0.05, api = {"bloom", "getThreshold", "setThreshold"}, configVar = {"Bloom (Mip Chain)", "threshold"},
			  desc = "Brightness at which a pixel starts to bloom." },
			{ id = "bloomknee", name = "Softness", type = "slider", min = 0, max = 1, step = 0.05, api = {"bloom", "getKnee", "setKnee"}, configVar = {"Bloom (Mip Chain)", "knee"} },
			{ id = "bloomscatter", name = "Spread", type = "slider", min = 0.5, max = 0.9, step = 0.05, api = {"bloom", "getScatter", "setScatter"}, configVar = {"Bloom (Mip Chain)", "scatter"} },
			{ id = "bloomemit", name = "Emissive boost", type = "slider", min = 0, max = 3, step = 0.1, api = {"bloom", "getEmitBoost", "setEmitBoost"}, configVar = {"Bloom (Mip Chain)", "emitBoost"},
			  desc = "Extra bloom on emissive model pixels. Needs deferred model rendering." },
		  } },
		{ id = "tonemap", name = "Tonemap and color grade", type = "bool", widget = "Tonemap and Color Grade", requires = "Tonemap and Color Grade",
		  children = {
			{ id = "tonemapper", name = "Curve", type = "select", options = {"None", "ACES", "Hable filmic"}, values = {0, 1, 2}, api = {"tonemap", "getTonemapper", "setTonemapper"}, configVar = {"Tonemap and Color Grade", "tonemapper"} },
			{ id = "exposure", name = "Exposure", type = "slider", min = 0.3, max = 2, step = 0.05, api = {"tonemap", "getExposure", "setExposure"}, configVar = {"Tonemap and Color Grade", "exposure"} },
			{ id = "contrast", name = "Contrast", type = "slider", min = 0.5, max = 1.5, step = 0.05, api = {"tonemap", "getContrast", "setContrast"}, configVar = {"Tonemap and Color Grade", "contrast"} },
			{ id = "saturation", name = "Saturation", type = "slider", min = 0, max = 2, step = 0.05, api = {"tonemap", "getSaturation", "setSaturation"}, configVar = {"Tonemap and Color Grade", "saturation"} },
			{ id = "temperature", name = "Temperature", type = "slider", min = -1, max = 1, step = 0.05, api = {"tonemap", "getTemperature", "setTemperature"}, configVar = {"Tonemap and Color Grade", "temperature"},
			  desc = "Negative is cooler, positive is warmer." },
			{ id = "lift", name = "Lift blacks", type = "slider", min = 0, max = 0.1, step = 0.005, api = {"tonemap", "getLift", "setLift"}, configVar = {"Tonemap and Color Grade", "lift"} },
			{ id = "vignette", name = "Vignette", type = "slider", min = 0, max = 0.6, step = 0.05, api = {"tonemap", "getVignette", "setVignette"}, configVar = {"Tonemap and Color Grade", "vignette"} },
			{ id = "dither", name = "Dither", type = "bool", api = {"tonemap", "getDither", "setDither"}, configVar = {"Tonemap and Color Grade", "dither"},
			  desc = "Sub-pixel noise that stops gradients banding." },
		  } },
		{ id = "cas", name = "Sharpening (CAS)", type = "bool", widget = "Contrast Adaptive Sharpen", requires = "Contrast Adaptive Sharpen",
		  desc = "AMD FidelityFX contrast adaptive sharpening.",
		  children = {
			{ id = "cassharpness", name = "Sharpness", type = "slider", min = 0, max = 1, step = 0.05, api = {"cas", "getSharpness", "setSharpness"}, configVar = {"Contrast Adaptive Sharpen", "SHARPNESS"} },
		  } },
		{ id = "ssao", name = "Ambient occlusion (SSAO)", type = "bool", widget = "SSAO", requires = "SSAO",
		  desc = "Screen-space ambient occlusion. Contact shadows in creases and under units.",
		  children = {
			{ id = "ssaoquality", name = "Quality", type = "select", options = {"Low", "Medium", "High"}, values = {1, 2, 3}, api = {"ssao", "getPreset", "setPreset"}, configVar = {"SSAO", "preset"} },
			{ id = "ssaostrength", name = "Strength", type = "slider", min = 1, max = 12, step = 0.5, api = {"ssao", "getStrength", "setStrength"}, configVar = {"SSAO", "strength"} },
			{ id = "ssaoradius", name = "Radius", type = "slider", min = 2, max = 8, step = 0.5, api = {"ssao", "getRadius", "setRadius"}, configVar = {"SSAO", "radius"} },
		  } },
		{ id = "lighteffects", name = "Light effects", type = "bool", widget = "Deferred rendering GL4", requires = "Deferred rendering GL4",
		  desc = "Dynamic lights on projectiles, explosions and wrecks.",
		  children = {
			{ id = "lighteffectsbrightness", name = "Brightness", type = "slider", min = 0.25, max = 3, step = 0.05, api = {"lightsgl4", nil, "IntensityMultiplier"}, configVar = {"Deferred rendering GL4", "intensityMultiplier"}, default = 1 },
			{ id = "lighteffectsradius", name = "Radius", type = "slider", min = 0.5, max = 2, step = 0.05, api = {"lightsgl4", nil, "RadiusMultiplier"}, configVar = {"Deferred rendering GL4", "radiusMultiplier"}, default = 1,
			  desc = "Larger lights are heavier on the GPU." },
			{ id = "lighteffectsshadows", name = "Screen space shadows", type = "select", options = {"Off", "Low", "High"}, values = {0, 1, 2}, api = {"lightsgl4", nil, "ScreenSpaceShadows"}, configVar = {"Deferred rendering GL4", "screenSpaceShadows"}, default = 2,
			  desc = "Lights are blocked by nearby geometry. High is expensive with many lights on screen." },
			{ id = "cursorlight", name = "Cursor light", type = "bool", api = {"lightsgl4", nil, "ShowPlayerCursorLight"}, configVar = {"Deferred rendering GL4", "showPlayerCursorLight"}, default = false },
		  } },
		{ id = "distortion", name = "Heat distortion", type = "bool", widget = "Distortion GL4", requires = "Distortion GL4",
		  desc = "Heat shimmer and shockwaves on weapons, explosions and thrusters.",
		  children = {
			{ id = "distortionstrength", name = "Strength", type = "slider", min = 0.25, max = 2, step = 0.05, api = {"distortionsgl4", nil, "IntensityMultiplier"}, configVar = {"Distortion GL4", "intensityMultiplier"}, default = 1 },
		  } },
		{ id = "outline", name = "Unit outline", type = "bool", widget = "Outline (deferred)", requires = "Outline (deferred)",
		  desc = "Thin dark outline around units so they read clearly against the terrain." },
		{ id = "underconstruction", name = "Under-construction highlight", type = "bool", widget = "Under construction gfx", requires = "Under construction gfx",
		  children = {
			{ id = "underconstructionopacity", name = "Opacity", type = "slider", min = 0.1, max = 0.6, step = 0.01, api = {"underconstructiongfx", "getOpacity", "setOpacity"}, configVar = {"Under construction gfx", "highlightAlpha"} },
			{ id = "underconstructionshader", name = "Edge shader", type = "bool", api = {"underconstructiongfx", "getShader", "setShader"}, configVar = {"Under construction gfx", "useHighlightShader"} },
		  } },
		{ id = "dof", name = "Depth of field", type = "bool", widget = "Depth of Field", requires = "Depth of Field",
		  desc = "Blurs distant terrain. Expensive.",
		  children = {
			{ id = "dofautofocus", name = "Autofocus", type = "bool", api = {"dof", "getAutofocus", "setAutofocus"}, configVar = {"Depth of Field", "autofocus"} },
			{ id = "dofquality", name = "High quality", type = "bool", api = {"dof", "getHighQuality", "setHighQuality"}, configVar = {"Depth of Field", "highQuality"} },
		  } },

		{ type = "separator", name = "Effects" },
		{ id = "lups", name = "Lups particle effects", type = "bool", widget = "LupsManager", requires = "LupsManager",
		  desc = "Jet flames, ground flashes, energy balls and other shader particle effects." },
		{ id = "unitsonfire", name = "Burning units", type = "bool", widget = "Units on Fire", requires = "Units on Fire" },
		{ id = "aircrafttrails", name = "Aircraft trails", type = "bool", widget = "Aircraft Trails GL4", requires = "Aircraft Trails GL4" },
		{ id = "disruptionfx", name = "Disruption electricity", type = "bool", widget = "Disruption Electricity", requires = "Disruption Electricity" },
		{ id = "weather", name = "Weather", type = "bool", widget = "Weather", requires = "Weather",
		  desc = "Time cycle weather: rain, fog and heat shimmer on maps that use them." },
		{ id = "snow", name = "Snow", type = "bool", widget = "Snow", requires = "Snow",
		  desc = "Maps with wintery names get snow by default.",
		  children = {
			{ id = "snowmap", name = "Snow on this map", type = "bool", api = {"snow", "getSnowMap", "setSnowMap"}, default = true,
			  desc = "Remembered per map." },
			{ id = "snowautoreduce", name = "Auto reduce at low FPS", type = "bool", api = {"snow", nil, "setAutoReduce"}, configVar = {"Snow", "autoReduce"}, default = true },
			{ id = "snowamount", name = "Amount", type = "slider", min = 0.2, max = 2, step = 0.2, api = {"snow", nil, "setMultiplier"}, configVar = {"Snow", "customParticleMultiplier"}, default = 1 },
		  } },
		{ id = "darkenmap", name = "Darken map", type = "bool", widget = "Darken map", requires = "Darken map",
		  desc = "Darkens the terrain (not units). Remembered per map.",
		  children = {
			{ id = "darkenmapamount", name = "Amount", type = "slider", min = 0, max = 0.5, step = 0.01, api = {"darkenmap", "getMapDarkness", "setMapDarkness"}, configVar = {"Darken map", "maps", Game.mapName:lower()}, default = 0 },
			{ id = "darkenfeatures", name = "Darken features too", type = "bool", api = {"darkenmap", "getDarkenFeatures", "setDarkenFeatures"}, configVar = {"Darken map", "darkenFeatures"}, default = false,
			  desc = "CPU heavy: every visible feature is drawn a second time." },
		  } },
	},
}
