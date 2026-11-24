--------------------------------------------------------------------------------
--
--  common/vfs_guard.lua
--
--  Only the game's own Lua runs. Nothing is loaded from the loose files in a
--  player's data directory (LuaUI/, LuaRules/, common/, modules/ ... beside
--  the engine or in the write directory).
--
--  The engine reads loose files first whenever a script does not say where to
--  read from: VFS.Include(path) with no mode takes the player's copy of that
--  path if there is one, in LuaUI and in unsynced LuaRules alike. Unsynced
--  gadget code sees the whole game, so a loose file there is a map hack, and
--  a loose file in LuaUI is a user widget by another name. (Synced code is
--  already held to the archives by the engine.)
--
--  This file replaces the VFS readers of the Lua state it is included in:
--
--    VFS.Include                 archives only, always. A mode that asks for
--                                loose files has that part removed; a mode
--                                that asks for nothing else loads nothing.
--    VFS.LoadFile, FileExists    the same for anything that is or becomes
--                                code (CODE_EXT below). Other files (text,
--                                images, sound, settings) keep working from
--                                loose files: with no mode the archive is
--                                looked in first, then the data directory.
--    VFS.DirList, VFS.SubDirs    with no mode, a listing that could hold code
--                                is of the archives only; a listing by a
--                                pattern for something else (music, fonts)
--                                is the engine's own.
--
--  It has to be the first thing each entry point does, and it has to be
--  included from the archive itself:
--
--      VFS.Include("common/vfs_guard.lua", nil, VFS.ZIP)
--
--  (luaui.lua, LuaRules/main.lua, LuaRules/draw.lua, LuaIntro/main.lua).
--
--  User widgets. If the including script has set the global
--  VFS_GUARD_USER_WIDGETS to true first (luaui.lua does, from the host's
--  "allowuserwidgets" modoption), code under LuaUI/Widgets/ may come from loose
--  files: when a loose file is asked for outright (the widget handler loading
--  a user widget), and as a fallback for a file the archives do not have (a
--  user widget including its own helper). A loose copy of a file the game has
--  is still never used, and nothing outside LuaUI/Widgets/ is opened up.
--  "Archives" here is everything mounted for the game: the game, its
--  dependencies, the engine's base content and the map.
--
--  What this cannot close: the engine itself picks which LuaIntro/main.lua to
--  run, and it takes a loose one first. That script only lives for the
--  loading screen.
--
--------------------------------------------------------------------------------

if VFS.sfGuarded then
	return
end

local RAW_CHAR = VFS.RAW or "r"
local ZIP = VFS.ZIP
local ZIP_FIRST = VFS.ZIP_FIRST

local rawInclude    = VFS.Include
local rawLoadFile   = VFS.LoadFile
local rawFileExists = VFS.FileExists
local rawDirList    = VFS.DirList
local rawSubDirs    = VFS.SubDirs

-- files that are code, or that the game compiles as code after reading them
local CODE_EXT = { lua = true, glsl = true, cfg = true }

local function IsCode(path)
	if type(path) ~= "string" then
		return true
	end
	local ext = path:match("%.([%w]+)$")
	return ext == nil or CODE_EXT[ext:lower()] == true
end

-- mode with the loose-file part taken out; nil if nothing is left of it
local function ArchivesOnly(mode)
	if mode == nil then
		return ZIP
	end
	if type(mode) ~= "string" then
		return ZIP
	end
	local stripped = mode:gsub(RAW_CHAR, "")
	if stripped == "" then
		return nil
	end
	return stripped
end

-- the one exception: see "User widgets" above
local USER_WIDGETS = (VFS_GUARD_USER_WIDGETS == true)
local function UserWidgetPath(path)
	if not USER_WIDGETS or type(path) ~= "string" or path:find("..", 1, true) then
		return false
	end
	return path:lower():gsub("\\", "/"):find("^luaui/widgets/") ~= nil
end

-- mode for a path that may be loose: what was asked for if it names loose
-- files outright, else the archives first and loose files after
local function UserWidgetMode(mode)
	if type(mode) == "string" and mode:find(RAW_CHAR, 1, true) then
		return mode
	end
	return ZIP_FIRST
end

local warned = {}
local function Refused(what, path)
	local key = what .. tostring(path)
	if not warned[key] then
		warned[key] = true
		Spring.Echo("[VFS guard] " .. what .. " of a loose file refused: " .. tostring(path))
	end
end

-- With no environment given, the engine runs the file in the environment of
-- the code that called VFS.Include (a widget's, a gadget's). Going through
-- this wrapper would make that the global one, so it is looked up here.
-- One thing to know: "return VFS.Include(path)" at the end of a widget or
-- gadget file is a tail call, which leaves no caller to look up, and the file
-- then runs in the global environment. Write "local r = VFS.Include(path)
-- return r", or pass the environment.
local getfenv, pcall, type = getfenv, pcall, type
local GLOBALS = getfenv(0)

function VFS.Include(path, env, mode)
	local m
	if UserWidgetPath(path) then
		m = UserWidgetMode(mode)
	else
		m = ArchivesOnly(mode)
	end
	if m == nil then
		Refused("Include", path)
		return nil
	end
	if env == nil then
		-- level 3 from inside pcall: pcall, this function, its caller
		local ok, callerEnv = pcall(getfenv, 3)
		env = (ok and type(callerEnv) == "table") and callerEnv or GLOBALS
	end
	return rawInclude(path, env, m)
end

function VFS.LoadFile(path, mode)
	if IsCode(path) then
		local m
		if UserWidgetPath(path) then
			m = UserWidgetMode(mode)
		else
			m = ArchivesOnly(mode)
		end
		if m == nil then
			Refused("LoadFile", path)
			return nil
		end
		return rawLoadFile(path, m)
	end
	return rawLoadFile(path, mode or ZIP_FIRST)
end

function VFS.FileExists(path, mode)
	if IsCode(path) then
		local m
		if UserWidgetPath(path) then
			m = UserWidgetMode(mode)
		else
			m = ArchivesOnly(mode)
		end
		if m == nil then
			return false
		end
		return rawFileExists(path, m)
	end
	return rawFileExists(path, mode or ZIP_FIRST)
end

-- a pattern that cannot match code: it names extensions and none is code
local function PatternIsData(pattern)
	if type(pattern) ~= "string" or pattern == "" or pattern == "*" then
		return false
	end
	local any = false
	for ext in pattern:gmatch("%.([%w]+)") do
		any = true
		if CODE_EXT[ext:lower()] then
			return false
		end
	end
	return any
end

function VFS.DirList(dir, pattern, mode, recursive)
	if mode == nil and not PatternIsData(pattern) then
		mode = ZIP
	end
	return rawDirList(dir, pattern, mode, recursive)
end

function VFS.SubDirs(dir, pattern, mode, recursive)
	return rawSubDirs(dir, pattern, mode, recursive)
end

VFS.sfGuarded = true
