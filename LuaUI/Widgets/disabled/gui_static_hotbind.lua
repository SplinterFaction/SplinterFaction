function widget:GetInfo()
	return {
		name      = "Static Hotbind",
		desc      = "Hover a build or order button and press Ctrl+Insert to bind it to a key; Ctrl+Delete to unbind. Writes through the Static Keybinds widget.",
		author    = "",
		date      = "2026",
		license   = "GNU GPL, v2 or later",
		layer     = -110,   -- ahead of Static Keybinds (-100) so capture wins the key
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- How this works
--
-- Hover any button in the build or order menu and press Ctrl+Insert. A prompt
-- appears, the next key you press becomes that button's binding, and the change
-- is written to sf_uikeys.txt immediately. Ctrl+Delete over the same button
-- removes its binding.
--
-- Two things make this correct rather than approximate:
--
--   * The bind string is not synthesized. Every command description the engine
--     hands to the layout handler carries a .action field -- "buildunit_<name>"
--     for build buttons (BuilderCAI.cpp / FactoryCAI.cpp), plain verbs like
--     "reclaim" or "guard" for orders. CGuiHandler::SetActiveCommand matches a
--     pressed keyset's action against cmdDesc.action and nothing else, so
--     reading .action straight off the hovered button is exactly right.
--
--   * sf_uikeys.txt has exactly one writer. This widget never opens that file;
--     it calls WG.StaticKeybinds.Bind / .Unbind so the change joins the same
--     edit list the keybinds panel holds in memory. Hotbinds therefore show up
--     in the panel, can be removed there, and are cleared by Reset All Rebinds.
--
-- Cost when idle is essentially zero. There is no Update callin, no mouse-move
-- tracking, and no polling: hover comes from WG.StaticBuildOrderMenu.GetHovered,
-- which reads a variable the build menu already maintains as part of its normal
-- draw pass, and it is only ever called on the one frame where a hotkey is
-- actually pressed. DrawScreen returns on its first line unless a prompt or a
-- status message is on screen.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local BIND_KEY    = "insert"    -- with Ctrl: start capture for the hovered button
local UNBIND_KEY  = "delete"    -- with Ctrl: clear the hovered button's binding
local REQUIRE_CTRL = true

local STATUS_TIME = 4           -- seconds a result message stays up

local BASE_RESOLUTION     = 1080
local PANEL_WIDTH         = 320
local PANEL_HEIGHT        = 78
local OUTER_CORNER        = 8
local INNER_CORNER        = 6.5
local INNER_INSET         = 2.25
local PANEL_ACCENT_HEIGHT = 4
local INNER_PAD           = 10

-- Vertical placement as a fraction of screen height (centre of the prompt).
-- 0.62 sits clear of the build menu on the left and the tooltip panel.
local PANEL_Y_FRAC = 0.62

local bgcorner  = "LuaUI/Images/bgcorner.png"
local accentImg = ":n:LuaUI/Images/staticgui_accent.png"

--------------------------------------------------------------------------------
-- Theme
--------------------------------------------------------------------------------

local COL = {
	border      = {0.15, 0.15, 0.15, 0.90},
	borderGui   = {0.15, 0.15, 0.15, 0.90},
	panelBg     = {0.05, 0.05, 0.06, 0.94},
	panelBgGui  = {0.00, 0.00, 0.00, 0.32},

	accentPanel = {0.18, 0.52, 0.98, 1},   -- blue: capturing
	accentOk    = {0.22, 0.78, 0.35, 1},   -- green: bound
	accentWarn  = {0.95, 0.65, 0.18, 1},   -- amber: unbound / nothing to do
	accentErr   = {0.90, 0.22, 0.22, 1},   -- red: cannot bind

	text        = {0.96, 0.96, 0.96, 1},
	textDim     = {0.62, 0.64, 0.67, 1},
	keyBound    = {0.95, 0.85, 0.25, 1},
	ok          = {0.35, 0.85, 0.45, 1},
	warn        = {0.95, 0.65, 0.18, 1},
	err         = {0.90, 0.40, 0.40, 1},
}

local TAG_TEXT = "\255\244\244\244"

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local rawColor   = gl.Color
local rawRect    = gl.Rect
local rawTexture = gl.Texture
local rawTexRect = gl.TexRect

local glColor, RectRound, AccentStrip, Flush

local spGetViewGeometry = Spring.GetViewGeometry
local spGetKeySymbol    = Spring.GetKeySymbol
local spIsGUIHidden     = Spring.IsGUIHidden
local spPlaySoundFile   = Spring.PlaySoundFile
local spEcho            = Spring.Echo

local math_floor = math.floor
local os_clock   = os.clock

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local vsx, vsy = spGetViewGeometry()
local uiScale  = 1.0
local font

local panelRect = { x1 = 0, y1 = 0, x2 = 0, y2 = 0 }

-- capture = { action = , label = } while waiting for a key, nil otherwise.
local capture = nil
-- status  = { title = , detail = , accent = , color = , expires = } or nil.
local status  = nil

local chobbyInterface = false

local MOD_KEYS = {
	alt = true, ctrl = true, meta = true, shift = true,
	lalt = true, ralt = true, lctrl = true, rctrl = true,
	lshift = true, rshift = true, lmeta = true, rmeta = true,
	super = true, lsuper = true, rsuper = true,
}

--------------------------------------------------------------------------------
-- Drawing shim
--
-- Same arrangement as the rest of the Static GUI suite: shapes go through
-- WG.StaticGUI so they batch into one instanced draw call, with an immediate
-- mode fallback if that module failed to come up.
--------------------------------------------------------------------------------

local function WrapFont(f)
	local SG = WG.StaticGUI
	if f and SG and SG.WrapFont then
		return SG.WrapFont(f)
	end
	return f
end

local function ReleaseFont(f)
	if not f then return end
	local SG = WG.StaticGUI
	if SG and SG.DeleteFont then
		SG.DeleteFont(f)
	else
		gl.DeleteFont(f)
	end
end

local function LegacyRectRound(px, py, sx, sy, cs)
	px, py, sx, sy, cs = math_floor(px), math_floor(py), math_floor(sx), math_floor(sy), math_floor(cs)
	rawRect(px + cs, py, sx - cs, sy)
	rawRect(sx - cs, py + cs, sx, sy - cs)
	rawRect(px, py + cs, px + cs, sy - cs)
	rawTexture(bgcorner)
	rawTexRect(px, py + cs, px + cs, py)
	rawTexRect(sx, py + cs, sx - cs, py)
	rawTexRect(px, sy - cs, px + cs, sy)
	rawTexRect(sx, sy - cs, sx - cs, sy)
	rawTexture(false)
end

local function LegacyAccentStrip(x1, y1, x2, y2)
	rawTexture(accentImg)
	rawTexRect(x1, y1, x2, y2)
	rawTexture(false)
end

local function NoOp() end

local function BindDrawing()
	local SG = WG.StaticGUI
	if SG then
		glColor     = SG.Color
		RectRound   = SG.RectRound
		AccentStrip = SG.AccentStrip
		Flush       = SG.Flush
	else
		glColor     = rawColor
		RectRound   = LegacyRectRound
		AccentStrip = LegacyAccentStrip
		Flush       = NoOp
	end
end

BindDrawing()

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function PlayClickSound() spPlaySoundFile("leftclick", 1.0, "ui") end

local function GetBorderColor()
	if WG.guishader then return COL.borderGui end
	return COL.border
end

local function GetPanelBGColor()
	if WG.guishader then return COL.panelBgGui end
	return COL.panelBg
end

local function SetStatus(title, detail, accent, color)
	status = {
		title   = title,
		detail  = detail,
		accent  = accent or COL.accentPanel,
		color   = color or COL.text,
		expires = os_clock() + STATUS_TIME,
	}
end

--------------------------------------------------------------------------------
-- Layout (api_staticgui_layout.lua). The layout module owns this panel's origin
-- once the user has dragged it in tweak mode (Ctrl+F11); until then, and when
-- the module is absent, the default computed below is used unchanged.
--------------------------------------------------------------------------------

local LAYOUT_ID = "hotbind"

local function LayoutPlace(x1, y1, w, h)
	local L = WG.StaticLayout
	if L then return L.Place(LAYOUT_ID, x1, y1, w, h) end
	return x1, y1
end

local function BuildGeometry()
	uiScale = vsy / BASE_RESOLUTION

	local pw = math_floor(PANEL_WIDTH  * uiScale)
	local ph = math_floor(PANEL_HEIGHT * uiScale)
	local x1 = math_floor(vsx * 0.5 - pw * 0.5)
	local y1 = math_floor(vsy * PANEL_Y_FRAC - ph * 0.5)
	x1, y1 = LayoutPlace(x1, y1, pw, ph)

	panelRect.x1, panelRect.y1 = x1, y1
	panelRect.x2, panelRect.y2 = x1 + pw, y1 + ph
end

-- "Ctrl+q" style keyset string, matching what the keybinds panel produces.
-- Returns nil for a bare modifier press, which the caller swallows and waits on.
local function KeysetFromKey(key, mods)
	local sym = spGetKeySymbol(key)
	if not sym or sym == "" or MOD_KEYS[sym] then return nil end

	local prefix = ""
	if mods.alt   then prefix = prefix .. "Alt+"   end
	if mods.ctrl  then prefix = prefix .. "Ctrl+"  end
	if mods.meta  then prefix = prefix .. "Meta+"  end
	if mods.shift then prefix = prefix .. "Shift+" end
	return prefix .. sym
end

-- Readable name for a command description. Build buttons carry the unit's
-- internal name in cmd.name, so resolve it to the display name.
local function CommandLabel(cmd)
	local ud = UnitDefNames and cmd.name and UnitDefNames[cmd.name]
	if ud then
		local human = ud.translatedHumanName or ud.humanName
		if human and human ~= "" then return human end
	end
	if cmd.name and cmd.name ~= "" then return cmd.name end
	return cmd.action or "?"
end

--------------------------------------------------------------------------------
-- Hover source
--------------------------------------------------------------------------------

-- Returns cmd, label, action -- or nil plus a reason string to show the user.
local function HoveredBindable()
	local api = WG.StaticBuildOrderMenu
	if not api or not api.GetHovered then
		return nil, "build menu not available"
	end

	local cmd = api.GetHovered()
	if not cmd then
		return nil, nil   -- nothing hovered: stay silent, pass the key through
	end

	local action = cmd.action
	if type(action) ~= "string" or action == "" then
		-- Lua-injected custom commands have no engine action, so there is
		-- nothing a keyset could be matched against.
		return nil, "\"" .. CommandLabel(cmd) .. "\" has no bindable action"
	end

	return cmd, CommandLabel(cmd), action
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------

local function BeginCapture()
	local cmd, label, action = HoveredBindable()
	if not cmd then
		if label then   -- second return is the reason string in the failure case
			SetStatus("Cannot bind", label, COL.accentErr, COL.err)
			return true
		end
		return false    -- nothing hovered: let Ctrl+Insert do whatever it normally does
	end

	if not (WG.StaticKeybinds and WG.StaticKeybinds.Bind) then
		SetStatus("Cannot bind", "Static Keybinds widget is not running", COL.accentErr, COL.err)
		return true
	end

	capture = { action = action, label = label }
	status  = nil
	return true
end

local function FinishCapture(keyset)
	local action, label = capture.action, capture.label
	capture = nil

	local ok, displaced = WG.StaticKeybinds.Bind(action, keyset)
	if not ok then
		SetStatus("Bind failed", action, COL.accentErr, COL.err)
		return
	end

	local detail = label
	if displaced and #displaced > 0 then
		-- Option (a): take the key, and name what lost it so the change is not
		-- silent. It is undoable from the keybinds panel either way.
		detail = detail .. "   (took the key from " .. displaced[1].line
		if #displaced > 1 then
			detail = detail .. " +" .. (#displaced - 1) .. " more"
		end
		detail = detail .. ")"
	end

	PlayClickSound()
	SetStatus(keyset, detail, COL.accentOk, COL.ok)
end

local function ClearHovered()
	local cmd, label, action = HoveredBindable()
	if not cmd then
		if label then
			SetStatus("Cannot unbind", label, COL.accentErr, COL.err)
			return true
		end
		return false
	end

	if not (WG.StaticKeybinds and WG.StaticKeybinds.Unbind) then
		SetStatus("Cannot unbind", "Static Keybinds widget is not running", COL.accentErr, COL.err)
		return true
	end

	local ok, removed = WG.StaticKeybinds.Unbind(action)
	if not ok then
		SetStatus("Not bound", label, COL.accentWarn, COL.warn)
		return true
	end

	PlayClickSound()
	SetStatus("Unbound " .. table.concat(removed, ", "), label, COL.accentWarn, COL.warn)
	return true
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

function widget:KeyPress(key, mods, isRepeat)
	local sym = spGetKeySymbol(key)

	if capture then
		if sym == "esc" or sym == "escape" then
			capture = nil
			SetStatus("Cancelled", nil, COL.accentWarn, COL.textDim)
			return true
		end
		if isRepeat then return true end

		local keyset = KeysetFromKey(key, mods)
		if keyset then
			-- Binding the hotbind combo to a button would lock the feature out
			-- of its own trigger, so refuse it rather than accept a keyset that
			-- can never be pressed again for this purpose.
			if (sym == BIND_KEY or sym == UNBIND_KEY) and mods.ctrl then
				SetStatus("Reserved key", "Ctrl+" .. sym .. " is the hotbind key", COL.accentErr, COL.err)
				capture = nil
				return true
			end
			FinishCapture(keyset)
		end
		return true   -- swallow everything, including bare modifiers, while capturing
	end

	if REQUIRE_CTRL and not mods.ctrl then return false end

	if sym == BIND_KEY then
		return BeginCapture()
	elseif sym == UNBIND_KEY then
		return ClearHovered()
	end

	return false
end

-- Clicking while the prompt is up cancels it, so a mis-triggered capture never
-- eats a build order.
function widget:MousePress(x, y, button)
	if not capture then return false end
	capture = nil
	SetStatus("Cancelled", nil, COL.accentWarn, COL.textDim)
	return true
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

local function DrawPrompt(accent, line1, line1Col, line2, line3)
	local bc, pc = GetBorderColor(), GetPanelBGColor()
	local ins    = INNER_INSET * uiScale
	local pad    = INNER_PAD * uiScale
	local ah     = PANEL_ACCENT_HEIGHT * uiScale

	glColor(bc[1], bc[2], bc[3], bc[4])
	RectRound(panelRect.x1, panelRect.y1, panelRect.x2, panelRect.y2, OUTER_CORNER * uiScale)

	glColor(pc[1], pc[2], pc[3], pc[4])
	RectRound(panelRect.x1 + ins, panelRect.y1 + ins, panelRect.x2 - ins, panelRect.y2 - ins, INNER_CORNER * uiScale)

	glColor(accent[1], accent[2], accent[3], 1)
	AccentStrip(panelRect.x1 + ins, panelRect.y2 - ins - ah, panelRect.x2 - ins, panelRect.y2 - ins)

	-- "co" (centred + outline) with explicit baselines, matching the rest of the
	-- suite rather than relying on a vertical alignment flag.
	local cx  = math_floor((panelRect.x1 + panelRect.x2) * 0.5)
	local top = panelRect.y2 - ins - ah - pad

	font:Begin()

	font:SetTextColor(line1Col[1], line1Col[2], line1Col[3], line1Col[4])
	font:Print(TAG_TEXT .. line1, cx, math_floor(top - 15 * uiScale), 16 * uiScale, "co")

	if line2 then
		font:SetTextColor(COL.text[1], COL.text[2], COL.text[3], COL.text[4])
		font:Print(line2, cx, math_floor(top - 33 * uiScale), 13 * uiScale, "co")
	end

	if line3 then
		font:SetTextColor(COL.textDim[1], COL.textDim[2], COL.textDim[3], COL.textDim[4])
		font:Print(line3, cx, math_floor(top - 49 * uiScale), 11 * uiScale, "co")
	end

	font:End()
end

function widget:DrawScreen()
	-- Idle cost stops here: one comparison per frame when nothing is on screen.
	if not capture and not status then return end
	if chobbyInterface or spIsGUIHidden() or not font then return end

	if capture then
		DrawPrompt(COL.accentPanel,
			"Press a key",
			COL.keyBound,
			capture.label,
			"Esc or click cancels")
	else
		if os_clock() >= status.expires then
			status = nil
			return
		end
		DrawPrompt(status.accent, status.title, status.color, status.detail, nil)
	end

	Flush()
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function widget:Initialize()
	BindDrawing()

	vsx, vsy = spGetViewGeometry()
	-- Same file, size and outline as the build menu's main font, so the engine
	-- font cache can hand back the existing atlas instead of building another.
	font = WrapFont(gl.LoadFont("fonts/Saira_SemiCondensed-SemiBold.ttf", 24, 2, 2))

	BuildGeometry()

	if not (WG.StaticBuildOrderMenu and WG.StaticBuildOrderMenu.GetHovered) then
		spEcho("[Static Hotbind] build/order menu hover API not found - hotbinding disabled until it loads")
	end

	WG.StaticHotbind = {
		IsCapturing = function() return capture ~= nil end,
		Cancel      = function() capture = nil end,
	}

	if WG.StaticLayout then
		WG.StaticLayout.Register(LAYOUT_ID, {
			label  = "Hotbind Prompt",
			onMove = function() widget:ViewResize(vsx, vsy) end,
			isVisible = function() return capture ~= nil end,
		})
	end
end

function widget:Shutdown()
	if WG.StaticLayout then WG.StaticLayout.Unregister(LAYOUT_ID) end
	if font then ReleaseFont(font) end
	WG.StaticHotbind = nil
end

function widget:ViewResize(nx, ny)
	vsx, vsy = nx, ny
	BuildGeometry()
end
