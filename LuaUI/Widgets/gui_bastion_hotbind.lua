--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Hotbind of the RmlUi HUD: bind a build or order button to a key by
--  pointing at it.
--
--  Hover any button in the build or order menu and press Ctrl+Insert. A prompt
--  appears, the next key you press becomes that button's binding, and the
--  change is written to sf_uikeys.txt at once. Ctrl+Delete over the same
--  button removes its binding. Esc or a click cancels the prompt.
--
--  Two things make this correct rather than approximate:
--
--    * The bind string is not synthesized. Every command description the
--      engine hands to the layout handler carries an .action field:
--      "buildunit_<name>" for build buttons (BuilderCAI.cpp / FactoryCAI.cpp),
--      plain verbs like "reclaim" or "guard" for orders.
--      CGuiHandler::SetActiveCommand matches a pressed keyset's action against
--      cmdDesc.action and nothing else, so reading .action straight off the
--      hovered button is exactly right.
--
--    * sf_uikeys.txt has exactly one writer. This widget never opens that
--      file; it calls WG.StaticKeybinds.Bind / .Unbind so the change joins the
--      same edit list the keybinds window holds in memory. Hotbinds therefore
--      show up in that window, can be removed there, and are cleared by Reset
--      All Rebinds.
--
--  It costs next to nothing while idle: nothing is polled, and the hovered
--  button is asked for (WG.StaticBuildOrderMenu.GetHovered) only when one of
--  the two keys is actually pressed.
--
--  Replaces gui_static_hotbind.lua (kept in Widgets/disabled/).
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Bastion Hotbind",
		previousNames = {"Hotbind"},
		desc    = "Hover a build or order button and press Ctrl+Insert to bind it to a key; Ctrl+Delete to unbind. Writes through the Keybinds widget. (RmlUi)",
		author  = "SplinterFaction Team",
		date    = "2026-10-13",
		license = "GNU GPL, v2 or later",
		layer   = -110, -- ahead of Keybinds (-100) so capture wins the key
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local DOCUMENT_PATH = "LuaUI/rml/hotbind.rml"

local BIND_KEY     = "insert" -- with Ctrl: start capture for the hovered button
local UNBIND_KEY   = "delete" -- with Ctrl: clear the hovered button's binding
local REQUIRE_CTRL = true

local STATUS_TIME = 4 -- seconds a result message stays up

-- must match #hotbind in hotbind.rml
local PANEL_WIDTH  = 320
local PANEL_HEIGHT = 78
-- Where the middle of the prompt sits, as a share of the screen's height from
-- the bottom. 0.62 is clear of the build menu on the left and the tooltip.
local PANEL_Y_FRAC = 0.62

local LAYOUT_NAME = "hotbind" -- same as the old widget, so a saved position carries over

local spGetKeySymbol = Spring.GetKeySymbol

local hud
local document
local view

local capture -- {action = , label = } while waiting for a key
local status  -- {title = , detail = , kind = "ok" | "warn" | "err" | "dim", expires = }

local MOD_KEYS = {
	alt = true, ctrl = true, meta = true, shift = true,
	lalt = true, ralt = true, lctrl = true, rctrl = true,
	lshift = true, rshift = true, lmeta = true, rmeta = true,
	super = true, lsuper = true, rsuper = true,
}

--------------------------------------------------------------------------------
-- showing
--------------------------------------------------------------------------------

local function Refresh()
	if status and os.clock() >= status.expires then
		status = nil
	end
	local show = capture ~= nil or status ~= nil
	view.SetClass("hotbind", "hidden", not show)
	if not show then
		return
	end
	local kind
	if capture then
		view.SetText("first", "Press a key")
		view.SetText("second", hud.Escape(capture.label))
		view.SetText("third", "Esc or click cancels")
	else
		kind = status.kind
		view.SetText("first", hud.Escape(status.title))
		view.SetText("second", hud.Escape(status.detail or ""))
		view.SetText("third", "")
	end
	for _, name in ipairs({"ok", "warn", "err", "dim"}) do
		view.SetClass("hotbind", name, kind == name)
	end
end

local function SetStatus(title, detail, kind)
	status = {title = title, detail = detail, kind = kind, expires = os.clock() + STATUS_TIME}
end

local function PlayClickSound()
	Spring.PlaySoundFile("leftclick", 1.0, "ui")
end

--------------------------------------------------------------------------------
-- what is under the mouse
--------------------------------------------------------------------------------

-- "Ctrl+q" style keyset string, matching what the keybinds window produces.
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

-- Returns cmd, label, action -- or nil plus a reason string to show the user.
local function HoveredBindable()
	local api = WG.StaticBuildOrderMenu
	if not api or not api.GetHovered then
		return nil, "build menu not available"
	end

	local cmd = api.GetHovered()
	if not cmd then
		return nil, nil -- nothing hovered: stay silent, pass the key through
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
-- actions
--------------------------------------------------------------------------------

local function BeginCapture()
	local cmd, label, action = HoveredBindable()
	if not cmd then
		if label then -- second return is the reason string in the failure case
			SetStatus("Cannot bind", label, "err")
			return true
		end
		return false -- nothing hovered: let Ctrl+Insert do whatever it normally does
	end

	if not (WG.StaticKeybinds and WG.StaticKeybinds.Bind) then
		SetStatus("Cannot bind", "Keybinds widget is not running", "err")
		return true
	end

	capture = {action = action, label = label}
	status  = nil
	-- the key pressed next is the bind, not a command to run
	if widgetHandler.TakeKeyboard then
		widgetHandler:TakeKeyboard()
	end
	return true
end

local function ReleaseKeys()
	if widgetHandler.ReleaseKeyboard then
		widgetHandler:ReleaseKeyboard()
	end
end

local function FinishCapture(keyset)
	local action, label = capture.action, capture.label
	capture = nil
	ReleaseKeys()

	local ok, displaced = WG.StaticKeybinds.Bind(action, keyset)
	if not ok then
		SetStatus("Bind failed", action, "err")
		return
	end

	local detail = label
	if displaced and #displaced > 0 then
		-- Take the key, and name what lost it so the change is not silent. It
		-- can be undone from the keybinds window either way.
		detail = detail .. "   (took the key from " .. displaced[1].line
		if #displaced > 1 then
			detail = detail .. " +" .. (#displaced - 1) .. " more"
		end
		detail = detail .. ")"
	end

	PlayClickSound()
	SetStatus(keyset, detail, "ok")
end

local function ClearHovered()
	local cmd, label, action = HoveredBindable()
	if not cmd then
		if label then
			SetStatus("Cannot unbind", label, "err")
			return true
		end
		return false
	end

	if not (WG.StaticKeybinds and WG.StaticKeybinds.Unbind) then
		SetStatus("Cannot unbind", "Keybinds widget is not running", "err")
		return true
	end

	local ok, removed = WG.StaticKeybinds.Unbind(action)
	if not ok then
		SetStatus("Not bound", label, "warn")
		return true
	end

	PlayClickSound()
	SetStatus("Unbound " .. table.concat(removed, ", "), label, "warn")
	return true
end

local function Cancel()
	if capture then
		capture = nil
		ReleaseKeys()
		SetStatus("Cancelled", nil, "dim")
		if document then
			Refresh()
		end
	end
end

--------------------------------------------------------------------------------
-- widget api
--------------------------------------------------------------------------------

local function DefaultOrigin(vsx, vsy, w, h, scale)
	return (vsx - w) * 0.5, vsy * PANEL_Y_FRAC - h * 0.5
end

local function Place()
	hud.PlacePanel(view.Element("hotbind"), LAYOUT_NAME, PANEL_WIDTH, PANEL_HEIGHT, DefaultOrigin)
end

function widget:Initialize()
	local helpers = include("rml/hud.lua")
	local result, reason = helpers.LoadDocument(DOCUMENT_PATH, widget)
	if not result then
		Spring.Echo("[Hotbind] " .. tostring(reason))
		widgetHandler:RemoveWidget()
		return
	end
	hud = helpers
	document = result

	view = hud.NewView(document)
	view.Assume("hotbind", "hidden", true) -- set in the markup

	if not (WG.StaticBuildOrderMenu and WG.StaticBuildOrderMenu.GetHovered) then
		Spring.Echo("[Hotbind] build/order menu hover API not found - hotbinding disabled until it loads")
	end

	-- The build/order menu calls Cancel when it is clicked while the prompt is
	-- up: a click on an RmlUi panel never reaches this widget's MousePress.
	WG.StaticHotbind = {
		IsCapturing = function() return capture ~= nil end,
		Cancel      = Cancel,
	}

	hud.RegisterPanel(LAYOUT_NAME, "Hotbind Prompt", Place, function() return capture ~= nil end)
	Place()
	hud.ShowPassive(document)
end

function widget:Shutdown()
	WG.StaticHotbind = nil
	ReleaseKeys()
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

function widget:KeyPress(key, mods, isRepeat)
	if not document then return false end
	local sym = spGetKeySymbol(key)

	if capture then
		if sym == "esc" or sym == "escape" then
			Cancel()
			return true
		end
		if isRepeat then return true end

		local keyset = KeysetFromKey(key, mods)
		if keyset then
			-- Binding the hotbind combo to a button would lock the feature out
			-- of its own trigger, so refuse it rather than accept a keyset that
			-- can never be pressed again for this purpose.
			if (sym == BIND_KEY or sym == UNBIND_KEY) and mods.ctrl then
				SetStatus("Reserved key", "Ctrl+" .. sym .. " is the hotbind key", "err")
				capture = nil
				ReleaseKeys()
			else
				FinishCapture(keyset)
			end
			Refresh()
		end
		return true -- swallow everything, including bare modifiers, while capturing
	end

	if REQUIRE_CTRL and not mods.ctrl then return false end

	local handled = false
	if sym == BIND_KEY then
		handled = BeginCapture()
	elseif sym == UNBIND_KEY then
		handled = ClearHovered()
	end
	if handled then
		Refresh()
	end
	return handled
end

-- Clicking while the prompt is up cancels it, so a mis-triggered capture never
-- eats a build order. (This sees clicks on the map; the build/order menu
-- reports clicks on itself through WG.StaticHotbind.Cancel.)
function widget:MousePress(x, y, button)
	if not capture then return false end
	Cancel()
	return true
end

function widget:Update()
	-- idle cost stops here: one comparison per frame when nothing is on screen
	if not capture and not status then return end
	if not document or hud.FollowGuiHidden(document) then return end
	Refresh()
end
