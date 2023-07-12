
-- disable for intel cards (else it will render solid dark screen)
if Platform ~= nil and Platform.gpuVendor == 'Intel' then
    return
end


function widget:GetInfo()
  return {
    name      = "GUI Shader",
    desc      = "Blurs the 3D-world under several other widgets UI elements.",
    author    = "Floris (original blurapi widget by: jK)",
    date      = "17 february 2015",
    license   = "GNU GPL, v2 or later",
    layer     = -99999999,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
-------------------------------------------------------------------

local defaultBlurIntensity = 0.002

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--hardware capability

local canRTT    = (gl.RenderToTexture ~= nil)
local canCTT    = (gl.CopyToTexture ~= nil)
local canShader = (gl.CreateShader ~= nil)
local canFBO    = (gl.DeleteTextureFBO ~= nil)

local NON_POWER_OF_TWO = gl.HasExtension("GL_ARB_texture_non_power_of_two")

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local renderDlists = {}
local deleteDlistQueue = {}
local blurShader
local screencopy
local blurtex
local blurtex2
local stenciltex
local stenciltexScreen
local screenBlur = false

local blurIntensity = defaultBlurIntensity
local guishaderRects = {}
local guishaderDlists = {}
local guishaderScreenRects = {}
local guishaderScreenDlists = {}
local updateStencilTexture = false
local updateStencilTextureScreen = false

local oldvs = 0
local vsx, vsy   = widgetHandler:GetViewSizes()
local ivsx, ivsy = vsx, vsy
function widget:ViewResize(viewSizeX, viewSizeY)
  vsx, vsy  = viewSizeX,viewSizeY
  ivsx,ivsy = vsx, vsy

  if (gl.DeleteTextureFBO) then
    gl.DeleteTextureFBO(blurtex)
    gl.DeleteTextureFBO(blurtex2)
    gl.DeleteTexture(screencopy)
  end

  screencopy = gl.CreateTexture(vsx, vsy, {
    border = false,
    min_filter = GL.NEAREST,
    mag_filter = GL.NEAREST,
  })
  blurtex = gl.CreateTexture(ivsx, ivsy, {
    border = false,
    wrap_s = GL.CLAMP,
    wrap_t = GL.CLAMP,
    fbo = true,
  })
  blurtex2 = gl.CreateTexture(ivsx, ivsy, {
    border = false,
    wrap_s = GL.CLAMP,
    wrap_t = GL.CLAMP,
    fbo = true,
  })

  if (blurtex == nil)or(blurtex2 == nil)or(screencopy == nil) then
    Spring.Log(widget:GetInfo().name, LOG.ERROR, "guishader api: texture error")
    widgetHandler:RemoveWidget(self)
    return false
  end

  updateStencilTexture = true
  updateStencilTextureScreen = true
end


function widget:UpdateCallIns()
  self:ViewResize(vsx, vsy)
  self.DrawScreenEffects = DrawScreenEffectsBlur
  widgetHandler:UpdateCallIn("DrawScreenEffects")
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function DrawStencilTexture(world,fullscreen)
  local usedStencilTex
  if world then usedStencilTex = stenciltex else usedStencilTex = stenciltexScreen end

  if (next(guishaderRects) or next(guishaderScreenRects) or next(guishaderDlists)) then

    if (usedStencilTex == nil)or(vsx+vsy~=oldvs) then
      gl.DeleteTextureFBO(usedStencilTex)

      oldvs = vsx+vsy
        usedStencilTex = gl.CreateTexture(vsx, vsy, {
        border = false,
        min_filter = GL.NEAREST,
        mag_filter = GL.NEAREST,
        wrap_s = GL.CLAMP,
        wrap_t = GL.CLAMP,
        fbo = true,
      })

      if (usedStencilTex == nil) then
        Spring.Log(widget:GetInfo().name, LOG.ERROR, "guishader api: texture error")
        widgetHandler:RemoveWidget(self)
        return false
      end
    end
  else
    gl.RenderToTexture(usedStencilTex, gl.Clear, GL.COLOR_BUFFER_BIT ,0,0,0,0)
    return
  end

  gl.RenderToTexture(usedStencilTex, function()
    gl.Clear(GL.COLOR_BUFFER_BIT,0,0,0,0)
    gl.PushMatrix()
      gl.Translate(-1,-1,0)
      gl.Scale(2/vsx,2/vsy,0)
      if world then
        for _,rect in pairs(guishaderRects) do
            gl.Rect(rect[1],rect[2],rect[3],rect[4])
        end
        for _,dlist in pairs(guishaderDlists) do
            gl.CallList(dlist)
        end
	  elseif fullscreen then
        gl.Rect(0,0,vsx,vsy)
      else
        for _,rect in pairs(guishaderScreenRects) do
            gl.Rect(rect[1],rect[2],rect[3],rect[4])
        end
        for _,dlist in pairs(guishaderScreenDlists) do
            gl.CallList(dlist)
        end
      end
    gl.PopMatrix()
  end)

    if world then stenciltex = usedStencilTex else stenciltexScreen = usedStencilTex end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function CheckHardware()
  if (not canCTT) then
    Spring.Echo("guishader api: your hardware is missing the necessary CopyToTexture feature")
    widgetHandler:RemoveWidget(self)
    return false
  end

  if (not canRTT) then
    Spring.Echo("guishader api: your hardware is missing the necessary RenderToTexture feature")
    widgetHandler:RemoveWidget(self)
    return false
  end

  if (not canShader) then
    Spring.Echo("guishader api: your hardware does not support shaders, OR: change springsettings: \"enable lua shaders\" ")
    widgetHandler:RemoveWidget(self)
    return false
  end

  if (not canFBO) then
    Spring.Echo("guishader api: your hardware does not fbo textures")
    widgetHandler:RemoveWidget(self)
    return false
  end

  if (not NON_POWER_OF_TWO) then
    Spring.Echo("guishader api: your hardware does not non-2^n-textures")
    widgetHandler:RemoveWidget(self)
    return false
  end

  --if Platform ~= nil then
  --   if Platform.gpuVendor == 'Intel' then
  --       widgetHandler:RemoveWidget(self)
  --       Spring.SendCommands("luaui disablewidget GUI Shader")
  --       return false
  --   end
  --end
  return true
end


function widget:Initialize()
  if (not CheckHardware()) then return false end
  
  CreateShaders()

  self:UpdateCallIns()
  
  WG['guishader'] = {}
  WG['guishader'].InsertDlist = function(dlist,name)
      guishaderDlists[name] = dlist
      updateStencilTexture = true
  end
  WG['guishader'].RemoveDlist = function(name)
      local found = false
      if guishaderDlists[name] ~= nil then
          found = true
      end
      guishaderDlists[name] = nil
      updateStencilTexture = true
      return found
  end
  WG['guishader'].DeleteDlist = function(name)
      local found = false
      if guishaderDlists[name] ~= nil then
          found = true
          deleteDlistQueue[name] = guishaderDlists[name]
      end
      return found
  end
  WG['guishader'].InsertRect = function(left,top,right,bottom,name)
      guishaderRects[name] = {left,top,right,bottom}
      updateStencilTexture = true
  end
  WG['guishader'].RemoveRect = function(name)
      local found = false
      if guishaderRects[name] ~= nil then
          found = true
      end
      guishaderRects[name] = nil
      updateStencilTexture = true
      return found
  end
  WG['guishader'].InsertScreenDlist = function(dlist,name)
      guishaderScreenDlists[name] = dlist
      updateStencilTextureScreen = true
  end
  WG['guishader'].RemoveScreenDlist = function(name)
      local found = false
      if guishaderScreenDlists[name] ~= nil then
          found = true
      end
      guishaderScreenDlists[name] = nil
      updateStencilTextureScreen = true
      return found
  end
  WG['guishader'].DeleteScreenDlist = function(name)
      local found = false
      if guishaderScreenDlists[name] ~= nil then
          found = true
          deleteDlistQueue[name] = guishaderScreenDlists[name]
      end
      return found
  end
  WG['guishader'].InsertScreenRect = function(left,top,right,bottom,name)
      guishaderScreenRects[name] = {left,top,right,bottom}
      updateStencilTextureScreen = true
  end
  WG['guishader'].RemoveScreenRect = function(name)
      local found = false
      if guishaderScreenRects[name] ~= nil then
          found = true
      end
      guishaderScreenRects[name] = nil
      updateStencilTextureScreen = true
      return found
  end
  WG['guishader'].getBlurDefault = function()
  	return defaultBlurIntensity
  end
  WG['guishader'].getBlurIntensity = function()
  	return blurIntensity
  end
  WG['guishader'].setBlurIntensity = function(value)
  	if value == nil then value = defaultBlurIntensity end
  	blurIntensity = value
  end

  WG['guishader'].setScreenBlur = function(value)
    updateStencilTextureScreen = true
  	screenBlur = value
  end
  WG['guishader'].getScreenBlur = function(value)
  	return screenBlur
  end

  -- will let it draw a given dlist to be rendered on top of screenblur
  WG['guishader'].insertRenderDlist = function(value)
      renderDlists[value] = true
  end
  WG['guishader'].removeRenderDlist = function(value)
      if renderDlists[value] then
          renderDlists[value] = nil
      end
  end

    widgetHandler:RegisterGlobal('GuishaderInsertRect', WG['guishader'].InsertRect)
    widgetHandler:RegisterGlobal('GuishaderRemoveRect', WG['guishader'].RemoveRect)
end


function CreateShaders()

  if (blurShader) then
    gl.DeleteShader(blurShader or 0)
  end
  
  -- create blur shaders
  blurShader = gl.CreateShader({
    fragment = [[
		#version 150 compatibility
        uniform sampler2D tex2;
        uniform sampler2D tex0;
        uniform float intensity;

        void main(void)
        {
            vec2 texCoord = vec2(gl_TextureMatrix[0] * gl_TexCoord[0]);
            float stencil = texture2D(tex2, texCoord).a;
            if (stencil<0.01)
            {
                gl_FragColor = texture2D(tex0, texCoord);
                return;
            }
            gl_FragColor = vec4(0.0,0.0,0.0,1.0);

            float sum = 0.0;
            for (int i = -1; i <= 1; ++i)
                for (int j = -1; j <= 1; ++j) {
                    vec2 samplingCoords = texCoord + vec2(i, j) * intensity;
                    float samplingCoordsOk = float( all( greaterThanEqual(samplingCoords, vec2(0.0)) ) && all( lessThanEqual(samplingCoords, vec2(1.0)) ) );
                    gl_FragColor.rgb += texture2D(tex0, samplingCoords).rgb * samplingCoordsOk;
                    sum += samplingCoordsOk;
            }
            gl_FragColor.rgb /= sum;
        }
    ]],

    uniformInt = {
      tex0 = 0,
      tex2 = 2,
    },
    uniformFloat = {
      intensity = blurIntensity,
    }
  })
	
  if (blurShader == nil) then
    Spring.Log(widget:GetInfo().name, LOG.ERROR, "guishader blurShader: shader error: "..gl.GetShaderLog())
    widgetHandler:RemoveWidget(self)
    return false
  end

  -- create blurtextures
  screencopy = gl.CreateTexture(vsx, vsy, {
    border = false,
    min_filter = GL.NEAREST,
    mag_filter = GL.NEAREST,
  })
  blurtex = gl.CreateTexture(ivsx, ivsy, {
    border = false,
    wrap_s = GL.CLAMP,
    wrap_t = GL.CLAMP,
    fbo = true,
  })
  blurtex2 = gl.CreateTexture(ivsx, ivsy, {
    border = false,
    wrap_s = GL.CLAMP,
    wrap_t = GL.CLAMP,
    fbo = true,
  })
  
	intensityLoc = gl.GetUniformLocation(blurShader, "intensity")
	
  -- debug?
  if (blurtex == nil)or(blurtex2 == nil)or(screencopy == nil) then
    Spring.Log(widget:GetInfo().name, LOG.ERROR, "guishader api: texture error")
    widgetHandler:RemoveWidget(self)
    return false
  end
end


function DeleteShaders()
  if (gl.DeleteTextureFBO) then
    gl.DeleteTextureFBO(blurtex)
    gl.DeleteTextureFBO(blurtex2)
    gl.DeleteTextureFBO(stenciltex)
    gl.DeleteTextureFBO(stenciltexScreen)
  end
  gl.DeleteTexture(screencopy or 0)

  if (gl.DeleteShader) then
    gl.DeleteShader(blurShader or 0)
  end
  blurShader = nil
end

function widget:Shutdown()
  DeleteShaders()
  WG['guishader'] = nil
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:DrawScreenEffectsBlur()
  if Spring.IsGUIHidden() then return end

  if not screenBlur and blurShader then
	  if not next(guishaderRects) and not next(guishaderDlists) then return end

	  gl.Texture(false)
	  gl.Color(1,1,1,1)
	  gl.Blending(false)

	  if updateStencilTexture then
	    DrawStencilTexture(true);
	    updateStencilTexture = false;
	  end

	  gl.CopyToTexture(screencopy, 0, 0, 0, 0, vsx, vsy)
	  gl.Texture(screencopy)
	  gl.RenderToTexture(blurtex, gl.TexRect, -1,1,1,-1)

      gl.UseShader(blurShader)
      gl.Uniform(intensityLoc, blurIntensity)

      gl.Texture(2,stenciltex)
      gl.Texture(blurtex)
      gl.RenderToTexture(blurtex2, gl.TexRect, -1,1,1,-1)
      gl.Texture(blurtex2)
      gl.RenderToTexture(blurtex, gl.TexRect, -1,1,1,-1)
      gl.Texture(2,false)
      gl.UseShader(0)

      if blurIntensity >= 0.0016 then
          gl.UseShader(blurShader)
          gl.Uniform(intensityLoc, blurIntensity*0.5)

          gl.Texture(blurtex)
          gl.RenderToTexture(blurtex2, gl.TexRect, -1,1,1,-1)
          gl.Texture(blurtex2)
          gl.RenderToTexture(blurtex, gl.TexRect, -1,1,1,-1)
          gl.UseShader(0)
      end

	  gl.Texture(blurtex)
	  gl.TexRect(0,vsy,vsx,0)
	  gl.Texture(false)

	  gl.Blending(true)
  end
end

function widget:DrawScreen()
  if Spring.IsGUIHidden() then return end

	if ((screenBlur or next(guishaderScreenRects) or next(guishaderScreenDlists))) and blurShader  then
	  gl.Texture(false)
	  gl.Color(1,1,1,1)
	  gl.Blending(false)

	  if updateStencilTextureScreen then
	    DrawStencilTexture(false, screenBlur)
	    updateStencilTextureScreen = false
	  end

	  gl.CopyToTexture(screencopy, 0, 0, 0, 0, vsx, vsy)
	  gl.Texture(screencopy)
	  gl.RenderToTexture(blurtex, gl.TexRect, -1,1,1,-1)

	  gl.UseShader(blurShader)
        if screenBlur then
            gl.Uniform(intensityLoc, math.max(blurIntensity, 0.0015))
        else
            gl.Uniform(intensityLoc, blurIntensity)
        end

		gl.Texture(2,stenciltexScreen)
		gl.Texture(2,false)

		gl.Texture(blurtex)
		gl.RenderToTexture(blurtex2, gl.TexRect, -1,1,1,-1)
		gl.Texture(blurtex2)
		gl.RenderToTexture(blurtex, gl.TexRect, -1,1,1,-1)
	  gl.UseShader(0)

	  --2nd pass
	  gl.UseShader(blurShader)
	    gl.Uniform(intensityLoc, blurIntensity*0.5)

	    gl.Texture(blurtex)
	    gl.RenderToTexture(blurtex2, gl.TexRect, -1,1,1,-1)
	    gl.Texture(blurtex2)
	    gl.RenderToTexture(blurtex, gl.TexRect, -1,1,1,-1)
	  gl.UseShader(0)

	  gl.Texture(blurtex)
	  gl.TexRect(0,vsy,vsx,0)
	  gl.Texture(false)

	  gl.Blending(true)
    end

    for k,v in pairs(renderDlists) do
        gl.CallList(k)
    end

    for k,v in pairs(deleteDlistQueue) do
        gl.DeleteList(deleteDlistQueue[v])
        if guishaderDlists[k] then
            guishaderDlists[k] = nil
        elseif guishaderScreenDlists[k] then
            guishaderScreenDlists[k] = nil
        end
        updateStencilTexture = true
    end
    deleteDlistQueue = {}
end

function widget:GetConfigData(data)
    savedTable = {}
    savedTable.blurIntensity = blurIntensity
    return savedTable
end

function widget:SetConfigData(data)
    if data.blurIntensity ~= nil then
        blurIntensity = data.blurIntensity
    end
end

function widget:RecvLuaMsg(msg, playerID)
    if msg:sub(1,18) == 'LobbyOverlayActive' then
        screenBlur = (msg:sub(1,19) == 'LobbyOverlayActive1')
        updateStencilTextureScreen = true
    end
end