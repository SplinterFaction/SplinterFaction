--------------------------------------------------------------------------------
-- Controls tab: camera, mouse, command helpers
--------------------------------------------------------------------------------

local CAM_MODES  = { "First person", "Overhead", "Spring", "Rotating overhead", "Free" }
local CAM_CMDS   = { "viewfps", "viewta", "viewspring", "viewrot", "viewfree" }

return {
	id = "control", name = "Controls", order = 40,
	options = {
		{ type = "separator", name = "Camera" },
		{ id = "camera", name = "Camera mode", type = "select", options = CAM_MODES, values = {0, 1, 2, 3, 4}, config = "CamMode",
		  onSet = function(idx) Spring.SendCommands(CAM_CMDS[idx]) end },
		{ id = "camerasmoothness", name = "Camera smoothing", type = "slider", min = 0, max = 2, step = 0.01, store = true, default = 0.2,
		  desc = "Transition time for camera moves made by widgets." },
		{ id = "camerashake", name = "Camera shake", type = "bool", widget = "CameraShake", requires = "CameraShake",
		  desc = "Shakes the camera on nearby explosions." },
		{ id = "fovchanger", name = "Field of view hotkeys", type = "bool", widget = "FOV changer", requires = "FOV changer",
		  desc = "Keypad 1 / 7 or Ctrl+O / Ctrl+P change the camera field of view." },
		{ id = "scrollspeed", name = "Zoom speed", type = "slider", min = 1, max = 45, step = 1,
		  get = function() return math.abs(Spring.GetConfigInt("ScrollWheelSpeed", 25)) end,
		  set = function(v)
			local inv = Spring.GetConfigInt("ScrollWheelSpeed", 25) < 0
			Spring.SetConfigInt("ScrollWheelSpeed", inv and -v or v)
		  end },
		{ id = "scrollinverse", name = "Invert zoom", type = "bool",
		  get = function() return Spring.GetConfigInt("ScrollWheelSpeed", 25) < 0 end,
		  set = function(v)
			local speed = math.abs(Spring.GetConfigInt("ScrollWheelSpeed", 25))
			Spring.SetConfigInt("ScrollWheelSpeed", v and -speed or speed)
		  end },
		{ id = "screenedgemove", name = "Screen edge moves camera", type = "bool", restart = true,
		  get = function() return Spring.GetConfigInt("FullscreenEdgeMove", 1) == 1 end,
		  set = function(v)
			Spring.SetConfigInt("FullscreenEdgeMove", v and 1 or 0)
			Spring.SetConfigInt("WindowedEdgeMove", v and 1 or 0)
		  end },

		{ type = "separator", name = "Mouse" },
		{ id = "hwcursor", name = "Hardware cursor", type = "bool", config = "HardwareCursor", cmd = "hardwarecursor %d",
		  desc = "When off, the cursor refresh rate is tied to your in-game FPS." },
		{ id = "crossalpha", name = "Pan cursor opacity", type = "slider", min = 0, max = 1, step = 0.05,
		  get = function() return tonumber(Spring.GetConfigString("CrossAlpha", "1")) or 1 end,
		  set = function(v)
			Spring.SetConfigString("CrossAlpha", tostring(v))
			Spring.SendCommands("cross " .. (Spring.GetConfigInt("CrossSize", 10)) .. " " .. v)
		  end,
		  desc = "Opacity of the crosshair shown while panning the camera with the middle mouse button." },
		{ id = "containmouse", name = "Keep mouse inside window", type = "bool", widget = "Grabinput Local", requires = "Grabinput Local",
		  desc = "In windowed mode, stops the cursor leaving the game window." },
		{ id = "doubleclickfight", name = "Double right-click to fight", type = "bool", widget = "Double-Click Fight", requires = "Double-Click Fight" },

		{ type = "separator", name = "Command helpers" },
		{ id = "customformations", name = "Custom formations", type = "bool", widget = "CustomFormations2", requires = "CustomFormations2",
		  desc = "Drag a line while giving an order to spread units along it." },
		{ id = "areaattacktweak", name = "Area attack tweak", type = "bool", widget = "Area Attack Tweak", requires = "Area Attack Tweak" },
		{ id = "aacommandhelper", name = "AA area attack filter", type = "bool", widget = "AA Command Helper", requires = "AA Command Helper",
		  desc = "Anti-air units ignore ground targets inside an area attack." },
		{ id = "splitbuildorders", name = "Split build orders", type = "bool", widget = "Build Order Splitter", requires = "Build Order Splitter",
		  desc = "Queued build orders are shared evenly between selected builders." },
		{ id = "queuecopypaste", name = "Copy and paste queues", type = "bool", widget = "QueueCopypasta", requires = "QueueCopypasta",
		  desc = "Space+Alt+number copies a queue, Space+number pastes it." },
		{ id = "persistentbuildspacing", name = "Remember build spacing", type = "bool", widget = "Persistent Build Spacing", requires = "Persistent Build Spacing" },
		{ id = "autofirstfacing", name = "Auto face first building", type = "bool", widget = "Auto First Build Facing", requires = "Auto First Build Facing",
		  desc = "The first structure you place faces the map center." },
		{ id = "statereversetoggle", name = "Reverse-toggle state buttons", type = "bool", widget = "State Reverse Toggle", requires = "State Reverse Toggle",
		  desc = "Right-click cycles multi-state buttons backwards." },
		{ id = "stopselfd", name = "Stop cancels self-destruct", type = "bool", widget = "Stop Self-D", requires = "Stop Self-D" },
		{ id = "splitselection", name = "Split selection hotkeys", type = "bool", widget = "Split Selection Hotkeys", requires = "Split Selection Hotkeys" },
		{ id = "commandinsert", name = "Command insert", type = "bool", widget = "CommandInsert", requires = "CommandInsert",
		  desc = "Space+order inserts at the front of the queue instead of the back." },
	},
}
