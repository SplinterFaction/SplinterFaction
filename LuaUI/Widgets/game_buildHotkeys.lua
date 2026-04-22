function widget:GetInfo()
	return {
		version   = "1.1",
		name      = "SplinterFaction Build Hotkeys",
		desc      = "Use hotkeys to build units",
		author    = "CommonPlayer",
		date      = "5 Oct 2018",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true,
		handler   = true, --can use widgetHandler:x()
	}
end

VFS.Include("luaui/configs/evo_buildHotkeysConfig.lua")

-- Taken from gui_red_buildordermenu
local sGetActiveCmdDescs = Spring.GetActiveCmdDescs
local ssub = string.sub

-- Hiddencmds defined once at module level, not inside GetCommands() every call
local hiddencmds = {
	[76] = true, --load units clone
	[65] = true, --selfd
	[9] = true, --gatherwait
	[8] = true, --squadwait
	[7] = true, --deathwait
	[6] = true, --timewait
	[39812] = true, --raw move
	[34922] = true, -- set unit target
	--[34923] = true, -- set target
}

local function GetCommands()
	local buildcmds = {}
	local buildcmdscount = 0
	for index, cmd in pairs(sGetActiveCmdDescs()) do
		if (type(cmd) == "table") then
			if (
					(not hiddencmds[cmd.id]) and
							(cmd.action ~= nil) and
							(not widgetHandler.commands[index].hidden) and
							(cmd.type ~= 21) and
							(cmd.type ~= 18) and
							(cmd.type ~= 17)
			) then
				if ((cmd.type == 20) or (ssub(cmd.action, 1, 10) == "buildunit_")) then
					buildcmdscount = buildcmdscount + 1
					buildcmds[buildcmdscount] = cmd
				end
			end
		end
	end
	return buildcmds
end

local sGetModKeyState = Spring.GetModKeyState
local sGetCmdDescIndex = Spring.GetCmdDescIndex
local sSetActiveCommand = Spring.SetActiveCommand
local sGetConfigInt    = Spring.GetConfigInt
local schar            = string.char

local updateCommands = false
local buildOptions = {}
local lengBuildOptions = 0

local lengKeysPressed = 0
local keysPressed = {}

local hotkeyText = ""
local hotkeyDirty = false  -- only redraw text when state actually changes
local screenWidth = gl.GetViewSizes()

-- Pre-allocated reusable staging table for building hotkeyText
local hotkeyParts = {}

local function updateHotkeyText()
	if lengKeysPressed > 0 then
		hotkeyParts[1] = "Build hotkey: "
		local n = 1
		for i = 1, lengKeysPressed do
			local k = keysPressed[i]
			if k >= 97 and k <= 122 then
				n = n + 1
				hotkeyParts[n] = schar(k):upper()
				n = n + 1
				hotkeyParts[n] = " + "
			end
		end
		hotkeyText = table.concat(hotkeyParts, "", 1, n)
	else
		hotkeyText = ""
	end
	hotkeyDirty = false
end

local function shortenHotkeyText()
	hotkeyText = hotkeyText:sub(1, -4)
end

local function hotkeyTargetDisabled()
	hotkeyText = hotkeyText:sub(1, -4) .. ' (Locked)'
end

WG.buildHotkeys = {}
WG.buildHotkeys.keysPressed = {}
WG.buildHotkeys.hasUpdated = false

-- Clears a table in-place to avoid allocating a new one each call
local function clearTable(t)
	for k in pairs(t) do t[k] = nil end
end

local function updateWidgetVar()
	local wkp = WG.buildHotkeys.keysPressed
	clearTable(wkp)
	for i = 1, lengKeysPressed do
		local k = keysPressed[i]
		if k >= 97 and k <= 122 then wkp[i] = schar(k):upper() end
	end
	WG.buildHotkeys.hasUpdated = true
end

function widget:CommandsChanged()
	updateCommands = true
end

local oldBuildOptions, oldLengBuildOptions

function widget:Update(dt)
	if not updateCommands then return end
	updateCommands = false

	local same = (oldLengBuildOptions ~= nil)
	buildOptions = {}
	lengBuildOptions = 0
	local buildcmds = GetCommands()
	for i = 1, #buildcmds do
		local name = buildcmds[i].name
		if name:find("_up", -5) then name = name:sub(1, -5) end
		if nameToKeyCode[name] then
			lengBuildOptions = lengBuildOptions + 1
			buildOptions[lengBuildOptions] = {
				keyCode  = nameToKeyCode[name],
				id       = buildcmds[i].id,
				disabled = buildcmds[i].disabled
			}
			if same and
					(lengBuildOptions > oldLengBuildOptions or
							buildOptions[lengBuildOptions].keyCode ~= oldBuildOptions[lengBuildOptions].keyCode) then
				same = false
			end
		end
	end
	if not same then
		lengKeysPressed = 0
		keysPressed = {}
		updateHotkeyText()
	end
	oldBuildOptions = buildOptions
	oldLengBuildOptions = lengBuildOptions
end

-- Reusable match result table — avoids allocation on every keypress
local matches = {}
local matchDisabled = {}
local matchSameLeng = {}

local function resetKeys()
	lengKeysPressed = 0
	keysPressed = {}
	updateHotkeyText()
	updateWidgetVar()
end

function widget:KeyPress(key, mods, isRepeat)
	if key == 304 or key == 306 or key == 308 then return false end -- shift, ctrl, alt

	lengKeysPressed = lengKeysPressed + 1
	keysPressed[lengKeysPressed] = key
	updateHotkeyText()
	updateWidgetVar()

	local lengMatches = 0
	for i = 1, lengBuildOptions do
		local getKeyCode = buildOptions[i].keyCode
		local lengKeyCode = #getKeyCode
		if lengKeyCode >= lengKeysPressed then
			local match = true
			for j = 1, lengKeysPressed do
				if keysPressed[j] ~= getKeyCode[j] then
					match = false
					break
				end
			end
			if match then
				lengMatches = lengMatches + 1
				matches[lengMatches]     = buildOptions[i].id
				matchDisabled[lengMatches] = buildOptions[i].disabled
				matchSameLeng[lengMatches] = (lengKeyCode == lengKeysPressed)
			end
		end
	end

	if lengMatches > 0 then
		for i = 1, lengMatches do
			if matchSameLeng[i] then
				if matchDisabled[i] then
					hotkeyTargetDisabled()
				else
					local alt, ctrl, meta, shift = sGetModKeyState()
					local rmb = 1
					if sGetConfigInt("evo_ctrl_dequeue", 1) == 1 then rmb, ctrl = ctrl and 3 or 1, false end
					local index = sGetCmdDescIndex(matches[i])
					sSetActiveCommand(index, rmb, true, false, alt, ctrl, meta, shift)
					shortenHotkeyText()
					updateWidgetVar()
				end
				keysPressed[lengKeysPressed] = nil
				lengKeysPressed = lengKeysPressed - 1
				if matchDisabled[i] then updateWidgetVar() end
				return true
			end
		end
	else
		resetKeys()
	end
	return false
end

function widget:MousePress(x, y, button)
	if button == 1 or button == 3 then
		resetKeys()
	end
	return false
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

function widget:ViewResize(vsx, vsy)
	screenWidth = vsx
end

function widget:DrawScreen()
	if chobbyInterface or hotkeyText == "" then return end
	gl.Text(hotkeyText, screenWidth * 0.5, 60, 20, "onc")
end