--------------------------------------------------------------------------------
--  Reads the engine's sync messages out of console lines. Load with
--  include("rml/syncmessages.lua"); used by the desync alert and the chat.
--
--  When a player's game stops matching the host's, the game server sends
--  every client (and the replay) a system message, and repeats it about every
--  400 frames for as long as the desync lasts (rts/Net/GameServer.cpp,
--  CheckSync; the strings are in rts/System/MsgStrings.h):
--
--    Sync error for <names> in frame <n> (got <hex>, correct is <hex>)
--    Error: Player <names> did not send sync checksum for frame <n>
--
--  <names> is one name, or several joined by ", " when they share the same
--  wrong checksum. The host's own log may carry the server's copy as well,
--  prefixed "[GameServer] Error: ".
--
--  Only lines that START with these texts are taken: a chat line always starts
--  with "<name>", so a player cannot fake a desync by typing one.
--------------------------------------------------------------------------------

local sync = {}

local function Names(list)
	local names = {}
	for name in (list .. ","):gmatch("%s*(.-)%s*,") do
		if name ~= "" then
			names[#names + 1] = name
		end
	end
	return names
end

-- the message itself, without what may be put in front of it
local function Strip(line)
	line = line:gsub("^%[f=%-?%d+%]%s*", "")
	line = line:gsub("^%[GameServer%]%s*", "")
	line = line:gsub("^Error:%s*(Sync error)", "%1")
	return line
end

-- Returns nil, or a table:
--   kind   "desync"     the players' games no longer match the host's
--          "noresponse" the players did not report in time (lag or a stall;
--                       not a desync by itself)
--   names  the players' names
--   frame  the frame the report is about
function sync.Parse(line)
	if type(line) ~= "string" then
		return nil
	end
	line = Strip(line)
	local list, frame = line:match("^Sync error for (.+) in frame (%d+) %(got %x+, correct is %x+%)")
	if list then
		return { kind = "desync", names = Names(list), frame = tonumber(frame) }
	end
	list, frame = line:match("^Error: Player (.+) did not send sync checksum for frame (%d+)")
	if list then
		return { kind = "noresponse", names = Names(list), frame = tonumber(frame) }
	end
	return nil
end

-- "the game state was saved to <file>", written by every client on the first
-- desync when the server asks for it (DumpState)
function sync.ParseDump(line)
	if type(line) ~= "string" then
		return nil
	end
	return Strip(line):match("^%[DumpState%].-to dump%-file (.+)$")
end

-- frame number to game time, "m:ss"
function sync.FrameTime(frame)
	local seconds = math.floor((frame or 0) / 30)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- "A", "A and B", "A, B and C"
function sync.JoinNames(names)
	if #names <= 1 then
		return names[1] or ""
	end
	return table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
end

return sync
