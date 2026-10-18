--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Pause screen of the RmlUi HUD: while the game is paused the picture is
--  washed out to grey and a "Game Paused" banner stands in the middle of the
--  screen. Both fade in and out.
--
--  The banner is RmlUi. The wash is a screen shader, drawn with gl in
--  DrawScreenEffects (under the whole interface), as before.
--
--  Replaces gui_pauseScreen.lua by Floris (kept in Widgets/disabled/).
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Bastion Pause Screen",
		previousNames = {"Pause Screen"},
		desc    = "Washes the picture out and shows a banner while the game is paused (RmlUi)",
		author  = "Floris; SplinterFaction Team",
		date    = "2026-10-13",
		license = "GNU GPL v2",
		layer   = 99999999,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local DOCUMENT_PATH = "LuaUI/rml/pause.rml"

-- must match #pause in pause.rml
local BANNER_WIDTH  = 360
local BANNER_HEIGHT = 70

local LAYOUT_NAME = "pausebanner"

local FADE_TIME           = 0.4  -- seconds to fade in or out
local FADE_STEPS          = 20   -- the banner's fade moves in this many steps
local MAX_SHADER_ALPHA    = 0.25 -- strength of the wash
local MAX_NONSHADER_ALPHA = 0.12 -- darkening used when the shader is not available

local hud
local document
local view

local paused   = false
local gameover = false
local progress = 0     -- 0 = not paused, 1 = fully paused
local startTime = os.clock()

local vsx, vsy = Spring.GetViewGeometry()
local screencopy
local shaderProgram
local alphaLoc

local fragmentShaderSource = [[
	uniform sampler2D screencopy;
	uniform float alpha;

	float getIntensity(vec4 color) {
	  vec3 intensityVector = color.rgb * vec3(0.66,0.66,0.66);
	  return length(intensityVector);
	}

	void main() {
	  vec2 texCoord = vec2(gl_TextureMatrix[0] * gl_TexCoord[0]);
	  vec4 origColor = texture2D(screencopy, texCoord);
	  float intensity = getIntensity(origColor);
	  intensity = intensity * 1.15;
	  float multi = intensity * 0.9;
	  if (intensity > 1) intensity = 1;
	  if (intensity < 0.5) {
			if (intensity < 0.2) {
			  gl_FragColor = vec4(multi*0.22, multi*0.22, multi*0.22, alpha);
			} else if (intensity < 0.35) {
			  gl_FragColor = vec4(multi*0.32, multi*0.32, multi*0.32, alpha);
			} else {
			  gl_FragColor = vec4(multi*0.55, multi*0.55, multi*0.55, alpha);
			}
	  } else {
			if (intensity < 0.75) {
				gl_FragColor = vec4(multi*0.7, multi*0.7, multi*0.7, alpha);
			} else {
			  gl_FragColor = vec4(multi*0.82, multi*0.82, multi*0.82, alpha);
			}
	  }
	}
]]

--------------------------------------------------------------------------------
-- showing
--------------------------------------------------------------------------------

local function Refresh()
	if not document then
		return
	end
	local shown = progress > 0 and not Spring.IsGUIHidden()
	view.SetClass("pause", "hidden", not shown)
	if shown then
		view.SetStyle("pause", "opacity", string.format("%.2f", math.ceil(progress * FADE_STEPS) / FADE_STEPS))
	end
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

local function DefaultOrigin(sizeX, sizeY, w, h, scale)
	return (sizeX - w) * 0.5, (sizeY - h) * 0.5
end

local function Place()
	hud.PlacePanel(view.Element("pause"), LAYOUT_NAME, BANNER_WIDTH, BANNER_HEIGHT, DefaultOrigin)
end

local function CreateScreenCopy()
	if screencopy then
		gl.DeleteTexture(screencopy)
	end
	screencopy = gl.CreateTexture(vsx, vsy, {
		border = false,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,
	})
end

function widget:Initialize()
	vsx, vsy = Spring.GetViewGeometry()
	local _, gameSpeed, isPaused = Spring.GetGameSpeed()
	if isPaused or gameSpeed == 0 then -- when the host (admin) paused, it is just game speed 0
		paused = true
		progress = 1 -- a /luaui reload while paused does not animate again
	end

	if gl.CreateShader and (Platform == nil or Platform.gpuVendor ~= 'Intel') then
		shaderProgram = gl.CreateShader({
			fragment = fragmentShaderSource,
			uniformInt = { screencopy = 0 },
		})
		if shaderProgram then
			alphaLoc = gl.GetUniformLocation(shaderProgram, "alpha")
			CreateScreenCopy()
		end
	end

	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		Spring.Echo("[Pause Screen] " .. tostring(reason))
		return -- the wash still works without the banner
	end
	hud = helpers
	document = result
	view = hud.NewView(document)
	view.Assume("pause", "hidden", true) -- set in the markup

	hud.RegisterPanel(LAYOUT_NAME, "Pause Banner", Place, function() return progress > 0 end)
	Place()
	hud.ShowPassive(document)
	pcall(function() document:PullToFront() end)
	Refresh()
end

function widget:Shutdown()
	if shaderProgram then
		gl.DeleteShader(shaderProgram)
		shaderProgram = nil
	end
	if screencopy then
		gl.DeleteTexture(screencopy)
		screencopy = nil
	end
	if hud then
		hud.UnregisterPanel(LAYOUT_NAME)
	end
	if document then
		document:Close()
		document = nil
	end
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	if shaderProgram then
		CreateScreenCopy()
	end
	if hud and document then
		hud.UpdateScale()
		Place()
	end
end

function widget:GameOver()
	gameover = true
end

function widget:GamePaused(playerID, isGamePaused)
	paused = isGamePaused
end

function widget:Update(dt)
	local _, _, isPaused = Spring.GetGameSpeed()
	local wasPaused = paused
	paused = (not gameover and isPaused) and true or false
	if paused and not wasPaused and document then
		pcall(function() document:PullToFront() end)
	end

	-- idle cost stops here: not paused and fully faded out
	if not paused and progress == 0 then
		return
	end
	local step = (dt or 0) / FADE_TIME
	if paused then
		progress = math.min(1, progress + step)
	else
		progress = math.max(0, progress - step)
	end
	Refresh()
end

-- the wash: under the whole interface
function widget:DrawScreenEffects()
	if progress <= 0 or Spring.IsGUIHidden() then return end
	if shaderProgram and screencopy then
		gl.CopyToTexture(screencopy, 0, 0, 0, 0, vsx, vsy)
		gl.Texture(0, screencopy)
		gl.UseShader(shaderProgram)
		gl.Uniform(alphaLoc, progress * MAX_SHADER_ALPHA)
		gl.TexRect(0, vsy, vsx, 0)
		gl.Texture(0, false)
		gl.UseShader(0)
	else
		gl.Color(0, 0, 0, progress * MAX_NONSHADER_ALPHA)
		gl.Rect(0, 0, vsx, vsy)
		gl.Color(1, 1, 1, 1)
	end
end
