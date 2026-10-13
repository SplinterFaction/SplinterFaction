--------------------------------------------------------------------------------
--  Shared helpers for the RmlUi HUD widgets. Load with include("rml/hud.lua").
--
--  Every widget gets its own copy of this module (include runs the file each
--  time), so module-level state here is per widget. Anything that must be
--  shared between widgets lives in WG.
--------------------------------------------------------------------------------

local hud = {}

local CONTEXT_NAME = "shared"

-- The HUD is laid out in "dp" for a 1920x1080 screen and scaled from there.
local BASE_WIDTH = 1920
local BASE_HEIGHT = 1080

-- Saira SemiCondensed is the HUD typeface. RmlUi names a face by the family
-- name stored in the file, and these two files carry different ones:
--   SemiBold -> family "Saira SemiCondensed SemiBold" (the body face)
--   Bold     -> family "Saira SemiCondensed", weight bold (figures, titles)
-- The first face is also registered as the fallback face, so a glyph or a
-- family that is missing never leaves text blank.
local FONT_FILES = {
	"LuaUI/Fonts/Saira_SemiCondensed-SemiBold.ttf",
	"LuaUI/Fonts/Saira_SemiCondensed-Bold.ttf",
}

-- Loads the HUD fonts once per LuaUI session (WG is shared by all widgets).
-- Returns true when every face is available.
function hud.LoadFonts()
	if WG.sfHudFonts ~= nil then
		return WG.sfHudFonts
	end
	local allLoaded = true
	for i, path in ipairs(FONT_FILES) do
		local ok, loaded = pcall(RmlUi.LoadFontFace, path, i == 1)
		if not ok or loaded == false then
			allLoaded = false
			Spring.Echo("[SF HUD] could not load font " .. path .. (ok and "" or (": " .. tostring(loaded))))
		end
	end
	WG.sfHudFonts = allLoaded
	return allLoaded
end

-- The context every HUD document lives in (created in LuaUI/rml_setup.lua).
function hud.GetContext()
	local context = RmlUi.GetContext(CONTEXT_NAME)
	if not context then
		context = RmlUi.CreateContext(CONTEXT_NAME)
	end
	return context
end

-- Pixels per dp: the resolution relative to 1080p, times the user's ui_scale.
function hud.GetScale()
	local vsx, vsy = Spring.GetViewGeometry()
	local userScale = Spring.GetConfigFloat("ui_scale", 1)
	if not userScale or userScale <= 0 then
		userScale = 1
	end
	local scale = math.min(vsx / BASE_WIDTH, vsy / BASE_HEIGHT) * userScale
	scale = math.floor(scale * 100 + 0.5) / 100
	if scale < 0.5 then
		scale = 0.5
	end
	return scale
end

-- Call when a HUD widget starts and whenever the view is resized.
function hud.UpdateScale()
	local context = hud.GetContext()
	if context then
		local scale = hud.GetScale()
		if context.dp_ratio ~= scale then
			context.dp_ratio = scale
		end
	end
	return context
end

-- Loads a document into the shared context, with the fonts in place first so
-- its text is laid out with them. Returns the document, or nil and a reason.
function hud.LoadDocument(path, widget)
	if not RmlUi then
		return nil, "RmlUi is not available"
	end
	local context = hud.UpdateScale()
	if not context then
		return nil, "no RmlUi context"
	end
	hud.LoadFonts()
	local ok, result = pcall(context.LoadDocument, context, path, widget)
	if not ok or not result then
		return nil, "could not load " .. path .. (ok and "" or (": " .. tostring(result)))
	end
	return result
end

-- Shows a document without giving it keyboard focus, so a passive HUD panel
-- never swallows key presses.
function hud.ShowPassive(document)
	if RmlUi.RmlModalFlag and RmlUi.RmlFocusFlag then
		document:Show(RmlUi.RmlModalFlag.None, RmlUi.RmlFocusFlag.None)
	else
		document:Show()
	end
end

--------------------------------------------------------------------------------
--  Panel placement
--
--  A panel is an absolutely positioned element of a known size in dp. Its
--  position is its default spot unless the player has dragged it in tweak
--  mode (Ctrl+F11), which is still handled by api_staticgui_layout.lua
--  (WG.StaticLayout) while old and new panels live side by side.
--
--  defaultOrigin(vsx, vsy, w, h, scale) returns the default bottom-left
--  corner in screen pixels (y counts up from the bottom, as everywhere in
--  LuaUI). RmlUi counts y down from the top; the conversion happens here.
--------------------------------------------------------------------------------

function hud.PlacePanel(element, name, widthDp, heightDp, defaultOrigin)
	if not element then
		return
	end
	local vsx, vsy = Spring.GetViewGeometry()
	local scale = hud.GetScale()
	local w = math.floor(widthDp * scale + 0.5)
	local h = math.floor(heightDp * scale + 0.5)
	local x1, y1 = defaultOrigin(vsx, vsy, w, h, scale)
	x1, y1 = math.floor(x1), math.floor(y1)
	local layout = WG.StaticLayout
	if layout and layout.Place then
		x1, y1 = layout.Place(name, x1, y1, w, h)
	end
	element.style["left"] = string.format("%dpx", x1)
	element.style["top"] = string.format("%dpx", vsy - (y1 + h))
	return x1, y1, w, h
end

-- Registers a panel with tweak mode. onMove is called after the player drops
-- the panel somewhere new; it should call hud.PlacePanel again.
function hud.RegisterPanel(name, label, onMove)
	local layout = WG.StaticLayout
	if layout and layout.Register then
		layout.Register(name, {label = label, onMove = onMove})
		return true
	end
	return false
end

function hud.UnregisterPanel(name)
	local layout = WG.StaticLayout
	if layout and layout.Unregister then
		layout.Unregister(name)
	end
end

--------------------------------------------------------------------------------
--  Unit pictures
--------------------------------------------------------------------------------

-- RML for a unit's picture. The picture is loaded as a plain image file from
-- unitpics/, the same file the engine uses as the build picture. A unit with
-- no picture gets an empty box of the same size.
local PICTURE_EXTENSIONS = {"dds", "png", "tga", "jpg", "bmp", "pcx"}
local picturePaths = {}

function hud.GetUnitPicturePath(unitDefID)
	local path = picturePaths[unitDefID]
	if path == nil then
		path = false
		local def = UnitDefs[unitDefID]
		if def then
			local candidates = {}
			local named = def.buildPic or def.buildpicname
			if type(named) == "string" and named ~= "" then
				candidates[#candidates + 1] = "unitpics/" .. named
			end
			for _, extension in ipairs(PICTURE_EXTENSIONS) do
				candidates[#candidates + 1] = "unitpics/" .. def.name .. "." .. extension
			end
			for _, candidate in ipairs(candidates) do
				if VFS.FileExists(candidate) then
					path = candidate
					break
				end
			end
		end
		picturePaths[unitDefID] = path
	end
	return path or nil
end

-- class: the RCSS class that sizes the picture; attributes: extra RML
-- attributes for the element, e.g. 'data-def="12"'
function hud.UnitPictureRML(unitDefID, class, attributes)
	local path = hud.GetUnitPicturePath(unitDefID)
	attributes = attributes and (" " .. attributes) or ""
	if path then
		-- the leading slash makes the path absolute instead of relative to the document
		return string.format('<img class="%s" src="/%s"%s/>', class, path, attributes)
	end
	return string.format('<div class="%s"%s/>', class, attributes)
end

--------------------------------------------------------------------------------
--  Views
--------------------------------------------------------------------------------

-- A view wraps a document and only touches it when a value actually changes,
-- so a widget can simply restate everything on every refresh.
function hud.NewView(document)
	local view = {document = document}
	local elements = {}
	local shownText, shownClass, shownStyle = {}, {}, {}

	function view.Element(id)
		local element = elements[id]
		if element == nil then
			element = document:GetElementById(id) or false
			elements[id] = element
		end
		return element
	end

	function view.SetText(id, text)
		if shownText[id] ~= text then
			local element = view.Element(id)
			if element then
				element.inner_rml = text
			end
			shownText[id] = text
		end
	end

	function view.SetClass(id, class, state)
		state = state and true or false
		local key = id .. "." .. class
		if shownClass[key] ~= state then
			local element = view.Element(id)
			if element then
				element:SetClass(class, state)
			end
			shownClass[key] = state
		end
	end

	function view.SetStyle(id, property, value)
		local key = id .. "." .. property
		if shownStyle[key] ~= value then
			local element = view.Element(id)
			if element then
				element.style[property] = value
			end
			shownStyle[key] = value
		end
	end

	-- Tell the view what the markup already says, so the first refresh does
	-- not rewrite it (e.g. an element that starts with class "hidden").
	function view.Assume(id, class, state)
		shownClass[id .. "." .. class] = state
	end

	-- Forget everything that was cached. Call right after replacing a
	-- container's content with inner_rml: the new elements may reuse the ids
	-- of the old ones but start from what the new markup says.
	function view.Forget()
		elements = {}
		shownText, shownClass, shownStyle = {}, {}, {}
	end

	-- For styles set from outside the view (hud.PlacePanel).
	function view.ForgetStyles()
		shownStyle = {}
	end

	return view
end

-- Calls handler() when the element with this id is left-clicked.
function hud.OnClick(view, id, handler)
	local element = view.Element(id)
	if element then
		element:AddEventListener("mousedown", function(event)
			if event.parameters and event.parameters.button == 0 then
				handler(event)
			end
		end)
	end
end

-- For event handlers on a container: the numeric value of the given attribute
-- on the element the event happened on, or on one of its ancestors.
function hud.EventAttribute(event, attribute)
	local element = event.target_element
	for _ = 1, 8 do
		if not element then
			return nil
		end
		if element:HasAttribute(attribute) then
			return tonumber(element:GetAttribute(attribute))
		end
		element = element.parent_node
	end
	return nil
end

-- Where the mouse is along an element, from 0 at its left edge to 1 at its
-- right edge. For sliders: call it while the left button is held.
function hud.MouseFraction(element)
	if not element then
		return nil
	end
	local width = element.offset_width
	if not width or width <= 0 then
		return nil
	end
	local mouseX = Spring.GetMouseState()
	return math.max(0, math.min(1, (mouseX - element.absolute_left) / width))
end

-- Hide-GUI (F5) support: call at the start of a widget's Update. Hides the
-- document while the engine's GUI is hidden and shows it again afterwards.
-- Returns true while hidden, so the widget can skip its refresh.
local guiHidden = false

function hud.FollowGuiHidden(document)
	local hidden = Spring.IsGUIHidden() and true or false
	if hidden ~= guiHidden then
		guiHidden = hidden
		if hidden then
			document:Hide()
		else
			hud.ShowPassive(document)
		end
	end
	return hidden
end

-- Text coming from the game (messages, names) must be escaped before it is
-- assigned to inner_rml.
function hud.Escape(text)
	text = tostring(text or "")
	text = text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	return text
end

return hud
