function widget:GetInfo()
	return {
		name    = "Unit Guide CSV Export",
		desc    = "Dumps every unitdef's display name and customparams.unitguide to a CSV file. Exports on load; also /unitguidecsv or /luaui unitguidecsv.",
		author  = "Scary le Poo",
		date    = "2026",
		license = "GNU GPL v2 or later",
		layer   = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

-- Default output filename. The engine chdir's to the writeable data directory
-- at startup (DataDirLocater::ChangeCwdToWriteDir), so a relative path lands
-- in the same folder as infolog.txt.
local OUTPUT_FILE = "unitguide.csv"

-- Export automatically when the widget loads. Left ON so that simply enabling
-- or reloading the widget produces the file -- no chat command needed.
local EXPORT_ON_LOAD = true

-- The customParams key we are looking for. The engine lowercases customParams
-- keys at load time, so "unitGuide" in the unitdef arrives here as "unitguide".
-- We still do a case-insensitive sweep below in case that ever changes.
local GUIDE_PARAM = "unitguide"

-- Include a row for units with no unitguide tag (or an empty one). Handy for
-- spotting which units still need guide text. Set false to export only units
-- that actually have text.
local INCLUDE_MISSING = true

-- Replace real newlines inside the guide text with a literal "\n" so every unit
-- occupies exactly one line. Set false to keep real line breaks (still valid
-- CSV, since every field is quoted, but harder to eyeball in a text editor).
local FLATTEN_NEWLINES = true

-- Prefix the file with a UTF-8 byte order mark. Excel needs this to display
-- non-ASCII correctly; LibreOffice and Sheets don't care. Set false if a script
-- is going to eat this file and won't strip BOMs.
local WRITE_BOM = true

-- If the file cannot be opened for writing, echo the CSV rows to the console
-- instead. They land in infolog.txt, which is always writeable, prefixed with
-- CSVROW| so you can grep them back out.
local ECHO_FALLBACK = true

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------

local spEcho = Spring.Echo

local LOG_PREFIX = "[UnitGuideCSV] "
local COLUMN_HEADERS = { "unitDefName", "displayName", "hasGuide", "unitGuide" }

local actionRegistered = false

local function Log(text)
	spEcho(LOG_PREFIX .. tostring(text))
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- Trim leading/trailing whitespace. Accepts anything, including nil, and always
-- returns a string.
local function Trim(value)
	if value == nil then
		return ""
	end
	local text = tostring(value)
	text = text:gsub("^%s+", "")
	text = text:gsub("%s+$", "")
	return text
end

-- Quote a single CSV field per RFC 4180. We quote unconditionally rather than
-- only-when-needed: it is always valid, and it means a stray comma, quote or
-- newline in someone's guide text can never shift the columns.
local function CsvEscape(value)
	local text = tostring(value or "")

	if FLATTEN_NEWLINES then
		text = text:gsub("\r\n", "\n")
		text = text:gsub("\r", "\n")
		text = text:gsub("\n", "\\n")
	end

	-- A literal double quote inside a quoted field is escaped by doubling it.
	text = text:gsub('"', '""')

	return '"' .. text .. '"'
end

local function CsvLine(fields)
	return table.concat(fields, ",")
end

-- Pull the guide text out of a unitdef's customParams.
-- Returns "" if the table, the key, or the value is missing or blank.
local function GetGuideText(unitDef)
	local customParams = unitDef.customParams
	if type(customParams) ~= "table" then
		return ""
	end

	-- Fast path: exact key match.
	local direct = customParams[GUIDE_PARAM]
	if direct ~= nil then
		return Trim(direct)
	end

	-- Slow path: case-insensitive match, so "unitGuide" / "UnitGuide" / etc.
	-- still get picked up if the engine ever stops lowercasing keys.
	local wanted = GUIDE_PARAM:lower()
	for key, value in pairs(customParams) do
		if type(key) == "string" and key:lower() == wanted then
			return Trim(value)
		end
	end

	return ""
end

-- Build one CSV row for a unitdef. Returns nil if the unit should be skipped.
-- Called through pcall by the exporter, so a malformed unitdef costs one row
-- rather than the whole export.
local function BuildRow(unitDefID, unitDef)
	if type(unitDef) ~= "table" then
		return nil
	end

	local internalName = unitDef.name or ("unitdefid_" .. tostring(unitDefID))

	-- translatedHumanName exists on newer engine builds and respects the
	-- language files; humanName is the raw unitdef name field. Fall back to the
	-- internal name so this column is never blank.
	local displayName = unitDef.translatedHumanName or unitDef.humanName or internalName

	local guideText = GetGuideText(unitDef)
	local hasGuide = (guideText ~= "")

	if not hasGuide and not INCLUDE_MISSING then
		return nil
	end

	return {
		internalName = tostring(internalName),
		hasGuide = hasGuide,
		fields = {
			CsvEscape(internalName),
			CsvEscape(displayName),
			CsvEscape(hasGuide and "yes" or "no"),
			CsvEscape(guideText),
		},
	}
end

-- Sanitise a user-supplied filename. Engine-side LuaIO::fopen rejects absolute
-- paths and anything containing "..", so strip the path apart entirely and keep
-- filename characters only.
local function SanitiseFilename(argument)
	local name = Trim(argument)
	if name == "" then
		return nil
	end

	name = name:gsub("[^%w%._%-]", "")
	if name == "" then
		return nil
	end

	if not name:lower():find("%.csv$") then
		name = name .. ".csv"
	end

	return name
end

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------

local function CollectRows()
	local rows = {}
	local seen = 0
	local withGuide = 0
	local withoutGuide = 0
	local skipped = 0

	-- pairs() rather than a numeric loop: UnitDefs is normally a 1..N array,
	-- but iterating the table directly means we still get every def even if the
	-- array part is ever sparse or lazily populated.
	for unitDefID, unitDef in pairs(UnitDefs) do
		seen = seen + 1

		local ok, row = pcall(BuildRow, unitDefID, unitDef)

		if not ok then
			-- row holds the error message in this branch.
			skipped = skipped + 1
			Log("skipped unitDefID " .. tostring(unitDefID) .. ": " .. tostring(row))
		elseif row ~= nil then
			rows[#rows + 1] = row
			if row.hasGuide then
				withGuide = withGuide + 1
			else
				withoutGuide = withoutGuide + 1
			end
		end
	end

	-- Alphabetical by internal name, so re-running the export produces a
	-- diffable file rather than whatever order the defs happened to load in.
	table.sort(rows, function(a, b)
		return a.internalName < b.internalName
	end)

	return rows, seen, withGuide, withoutGuide, skipped
end

local function EchoRows(rows)
	Log("dumping rows to console/infolog instead. Grep infolog.txt for CSVROW|")
	spEcho("CSVROW|" .. CsvLine(COLUMN_HEADERS))
	for i = 1, #rows do
		spEcho("CSVROW|" .. CsvLine(rows[i].fields))
	end
end

local function ExportCsv(filename)
	filename = filename or OUTPUT_FILE

	if type(UnitDefs) ~= "table" then
		Log("UnitDefs is not available (" .. type(UnitDefs) .. "). Nothing to export.")
		return false
	end

	local rows, seen, withGuide, withoutGuide, skipped = CollectRows()

	Log("scanned " .. tostring(seen) .. " unitdefs -> " .. tostring(#rows) .. " rows ("
		.. tostring(withGuide) .. " with guide, " .. tostring(withoutGuide) .. " without, "
		.. tostring(skipped) .. " errored).")

	if seen == 0 then
		Log("no unitdefs found -- is the game actually loaded?")
		return false
	end

	local file, openError = io.open(filename, "w")
	if not file then
		Log("io.open failed for '" .. tostring(filename) .. "': " .. tostring(openError))
		if ECHO_FALLBACK then
			EchoRows(rows)
		end
		return false
	end

	local writeOk, writeError = pcall(function()
		if WRITE_BOM then
			file:write("\239\187\191")
		end

		-- Plain "\n" on purpose: the file is opened in text mode, so Windows
		-- translates "\n" to CRLF for us. Writing "\r\n" ourselves would
		-- produce "\r\r\n" there.
		file:write(CsvLine(COLUMN_HEADERS) .. "\n")

		for i = 1, #rows do
			file:write(CsvLine(rows[i].fields) .. "\n")
		end
	end)

	file:close()

	if not writeOk then
		Log("write failed: " .. tostring(writeError))
		if ECHO_FALLBACK then
			EchoRows(rows)
		end
		return false
	end

	-- Read the file back so success is proven rather than assumed. A silent
	-- no-op is the one failure mode worth spending eight lines to rule out.
	local verify = io.open(filename, "r")
	if not verify then
		Log("wrote '" .. tostring(filename) .. "' but could not reopen it to verify.")
		return true
	end

	local bytes = #(verify:read("*a") or "")
	verify:close()

	Log("wrote '" .. tostring(filename) .. "' (" .. tostring(bytes)
		.. " bytes) to your write directory -- the folder containing infolog.txt.")

	return true
end

--------------------------------------------------------------------------------
-- Command handling
--------------------------------------------------------------------------------

-- Shared entry point for the registered action. The action handler passes
-- (cmd, optLine, words, data), so the optional filename arrives in words[1].
local function HandleAction(_, _, words)
	local argument = nil
	if type(words) == "table" then
		argument = words[1]
	end

	ExportCsv(SanitiseFilename(argument))
	return true
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

function widget:Initialize()
	-- Register a real console action so a bare /unitguidecsv works. The engine
	-- action system only knows about commands that have been registered; an
	-- unregistered /command is swallowed before any widget sees it, which is
	-- why TextCommand alone was not enough. Wrapped in pcall because not every
	-- widget handler exposes AddAction.
	local ok = pcall(function()
		widgetHandler:AddAction("unitguidecsv", HandleAction, nil, "t")
		actionRegistered = true
	end)

	if ok and actionRegistered then
		Log("loaded. Type /unitguidecsv (optionally with a filename) to re-export.")
	else
		Log("loaded, but this widget handler has no AddAction. Use /luaui unitguidecsv instead.")
	end

	if EXPORT_ON_LOAD then
		ExportCsv()
	end
end

function widget:Shutdown()
	if actionRegistered then
		pcall(function()
			widgetHandler:RemoveAction("unitguidecsv", "t")
		end)
		actionRegistered = false
	end
end

-- Reached via /luaui unitguidecsv -- the engine's LuaUI action executor
-- forwards everything after "/luaui " to GotChatMsg, which the widget handler
-- turns into a TextCommand. This is the fallback path if AddAction is missing.
function widget:TextCommand(command)
	local verb, argument = tostring(command):match("^%s*(%S+)%s*(.*)$")
	if verb ~= "unitguidecsv" then
		return false
	end

	ExportCsv(SanitiseFilename(argument))
	return true
end
