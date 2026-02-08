--[[
------------------------------------------------------------
		Tech Tree gadget (STICKY + NO RANGED TECH)
------------------------------------------------------------
Changes vs original:
- Tech is STICKY: once a team reaches a tech level, it never decreases.
------------------------------------------------------------
Notes:
- ProviderSum[team] tracks the *current* provider sum (still updated).
- UnlockedMax[team] tracks the *maximum ever reached* and is what is used for checks.
- TeamRulesParam "technology:<techname>" now publishes the sticky value (UnlockedMax).
------------------------------------------------------------

-- Legacy comments that explainthe gadget's inner workings:

--[[
------------------------------------------------------------
		Tech Tree gadget
------------------------------------------------------------
To make use of this gadget:
	Edit the FBI of your units,
	adding RequireTech and ProvideTech tags
	in the CustomParams section of UnitInfo.

	RequireTech: The technologies required to unlock the build button to build that unit.
		If more that one, separate them by comma.
		Each tech can be prefixed by a number, or a minus. If not, default to 1.
		You must have a space or tab between the number and the techname.
		The tech are required but not "consummed". Use along with negative ProvideTech to "consume" technologies.

	ProvideTech: The technologies given by that unit.
		If more that one, separate them by comma.
		Each tech can be prefixed by a number, or a minus. If not, default to 1.
		You must have a space or tab between the number and the techname.
		If you build more that one unit providing the same tech, they add up.
		If the prefixing number is negative, then it is taken into account both while the unit is under construction and finished.
		If the prefixing number is positive, then it is taken into account only once the unit is finished.

	ProvideTechRange: Limit the area in which a unit with a ProvideTech provides the technologies.
		Must be a number. All technologies listed in ProvideTech will use that same range.
		WARNING: DO NOT USE ProvideTechRange ON MOBILE UNIT!
		If a unit sporting a ProvideTechRange range moves, then units affected by it will not update.
		However, you can now have mobile units requiring tech unlocked by ranged providers, they'll get updated as they move.
------------------------------------------------------------
	The COB functions TechLost and TechGranted will be called
	by the gadget if a unit requiring a tech has them.
------------------------------------------------------------
Exemple of FBI declaring tech trees that would be managed by this gadget:

[UNITINFO]
{
	Name=Research Center;
	Unitname=searchlab;
	Description=Unlock new technologies;
	[CustomParams]
	{
		ProvideTech=SuperComputers, Exotic Alloys;
	}
	FootprintX=6;
	FootprintZ=6;
	MaxDamage=40000;
	....
}

[UNITINFO]
{
	Name=Stealth tank;
	Unitname=stlthtnk;
	Description=Made of absorbing material;
	[CustomParams]
	{
		RequireTech=Exotic Alloys;
	}
	FootprintX=3;
	FootprintZ=3;
	MaxDamage=8000;
	....
}

[UNITINFO]
{
	Name=Spatial Study Center;
	Unitname=spacelab;
	Description=Unlock spatial technologies;
	[CustomParams]
	{
		RequireTech=2 SuperComputers, Big-Rockets;
		ProvideTech=Satellite, 10 Exotic Alloys;
	}
	FootprintX=8;
	FootprintZ=8;
	MaxDamage=30000;
	....
}

[UNITINFO]
	{
	Name=Depollution Facility;
	Unitname=deppool;
	Description=Process waste into energy;
	[CustomParams]
	{
		ProvideTech=20 PowerGen,-Pollution;
	}
	...
}

// Two mutually exclusive unit, of which you can have only one at a time:
[UNITINFO]
	{
	Name=Russell Edwin Nash;
	Unitname=macleod;
	Description=There can be only one;
	[CustomParams]
	{
		RequireTech=0 Highlander;
		ProvideTech=-Highlander;
	}
	...
}
[UNITINFO]
	{
	Name=Victor Kruger;
	Unitname=kurgan;
	Description=There can be only one;
	[CustomParams]
	{
		RequireTech=0 Highlander;
		ProvideTech=-Highlander;
	}
	...
}


// Hero
[UNITINFO]
	{
	...
	[CustomParams]
	{
		RequireTech=Hero;
		ProvideTech=-Hero;
	}
	...
}
// Great Hero, count triple
[UNITINFO]
	{
	...
	[CustomParams]
	{
		RequireTech=3 Hero;
		ProvideTech=-3 Hero;
	}
	...
}
// Structure to raise hero cap
[UNITINFO]
	{
	Name=Altar of Heroes;
	Unitname=tavern;
	Description=Where heroes gather;
	[CustomParams]
	{
		ProvideTech=5 Hero;
	}
	...
}



------------------------------------------------------------
As a bonus:
				Advanced users only!
	Sticking to the FBI should cover all your needs already.
------------------------------------------------------------
Other synced gadgets may access the four following functions:


	GG.TechAddDependency([Providers],[Requirings],[TechName],[Range])
		Make the technology "TechName" be required by the unitdefs defined by "Requirings"
		Make the technology "TechName" be provided in a "Range" radius around by the unitdefs defined by "Providers"
		If "TechName" is nil or not provided, then one is automatically generated
		If "Range" is nil or not provided, then the providers are map-wide
		"Providers" and "Requiring" can be the following:
			- nil
			- unitname
			- {unitname1,unitname2,unitname3,...}
			- unitDefID
			- {unitDefID1,unitDefID2,unitDefID3,...}
			- a function applicable to an unitDefID, returning nil, false, true, or a number
		When the function return false or nil on an unitDefID, then that unitDefID is discarded
		When the function return true on an unitDefID, then that unitDefID is kept
		When the function return a number on an unitDefID, then that unitDefID is kept, and given a quantity equal to the returned number

		Exemple:
		-- Make nuclear missile launchers need nuclear power plant closeby:
		GG.TechAddDependency({"ArmFus","CorFus"},{UnitDefNames.armsilo.id,UnitDefNames.corsilo.id},"plutonium",200)
		-- Make factories need 3 mexxes:
		GG.TechAddDependency(
			function (ud) return UnitDefs[ud].isMetalExtractor end,
			function (ud) return UnitDefs[ud].isFactory and 3 end,
			"mining")


	GG.TechSlaveCommand(commandID,requirements)
		Makes a command locked until all the techs in the string requirements are reached.
		Useful to lock commands that are not build commands.
		Cannot be used more than once on the same command.

		Exemple: GG.TechSlaveCommand(CMD.DGUN,"Heavy Weapons, Offensive Commander")
		Would make the D-Gun button locked until both "heavy weapons" and "offensive commander" technologies are reached.


	GG.TechCheckCommand(CommandID,TeamID,[...])
		If any provider of any tech needed by that command is ranged then the last argument(s) must be of a form amongst:
			UnitID    x,z    x,y,z    {x,z}    {x,y,z}    {x=x,z=z}    {x=x,y=y,z=z}
		return true if the command is unlocked for the team
		return false if the command is locked for the team


	GG.TechCheck(TechName,TeamID,[Threshold],[...])
		If Threshold is false or nil or not provide, default to 1
		If any provider of that tech is ranged then the last argument(s) must be of a form amongst:
			UnitID    x,z    x,y,z    {x,z}    {x,y,z}    {x=x,z=z}    {x=x,y=y,z=z}
		return nil if TechName is not a known technology
		return false if team has not reached the tech
		return true if team has reached the tech


	GG.TechGrant(TechName,TeamID,[Quantity])
		Makes a team get a tech for free
		Quantity default to math.huge

		Exemple:
		-- Give all teams as many "hero" as the modoption maxhero, defaulting to 5 if that modoption not present
		for _,team in ipairs(Spring.GetTeamList()) do
			GG.TechGrant("hero",team,tonumber(Spring.GetModOptions()["maxhero"]) or 5)
		end


	GG.TechRefreshButtons(ids)
		Refresh the buttons of the units passed as argument.
		In theory, you should never need it.
		In practice, it will be useful if in some unforeseen case the buttons don't update while they should.
		ids can be:
			- nil: then it does all unit
			- a single unit id
			- a list of unit id


	GG.TechDump()
		Write to infolog the list of tech as well as what produce, consume or require them.

------------------------------------------------------------
Any widgets and gadgets, synced or unsynced, may use:

	Spring.GetTeamRulesParam(team,"technology:"..techname)
		Returns the number of unit providing access to a tech.
		Warning: techname must be lower case.

	For instance, assuming the mod use FBIs such as above,
	Spring.GetTeamRulesParam(Spring.GetMyTeamID(),"technology:exotic alloys")
	would return 0 at game start, and 5 after you finish
	three "Research Center" and two "Spatial Study Center".

	Note that: Spring.GetTeamRulesParam(team,"technology:"..techname)>=1
	Would return the same as GG.TechCheck(techname,team).
	Save that GG.TechCheck is limited to synced gadget,
	while Spring.GetTeamRulesParam is allowed in every lua.
------------------------------------------------------------
Those four functions and those TeamRules are only available
after the Initialize phase of gadgets. Check the layer value
in GetInfo if you need to call them in Initialize.
------------------------------------------------------------
]]--

function gadget:GetInfo()
	return {
		name = "Tech Trees (sticky, no range)",
		desc = "Prerequisites (sticky unlocks; no ranged tech)",
		author = "zwzsg + edits",
		date = "October 2009 (modified 2026)",
		license = "Public domain",
		layer = -10,
		enabled = true
	}
end

if (Spring.GetModOptions().comm == "feature") then
	gadgetHandler.RemoveGadget()
end

local function dbgEcho(...)
	if Spring.IsDevLuaEnabled() or false then -- toggle false->true for debug
		Spring.Echo(...)
	end
end

local function NthCharIs(str, n, charlist)
	local char = string.sub(str, n, n)
	for _, c in ipairs(charlist) do
		if char == c then
			return true
		end
	end
	return false
end

if (gadgetHandler:IsSyncedCode()) then

	------------------------------------------------------------
	-- Config
	------------------------------------------------------------
	local STICKY_TECH = true -- once reached, never lost

	------------------------------------------------------------
	-- State
	------------------------------------------------------------
	local TechTable = {}
	local ProviderTable = {}
	local AccessionTable = {}
	local ProviderIDs = {}
	local AccessionIDs = {}

	local OriDesc = {}
	local GrantDesc = {}

	local RecheckTeams = {}

	local UnitsWithScripts = {}

	------------------------------------------------------------
	-- String parsing helpers
	------------------------------------------------------------
	local function SplitStringComma(Line)
		local words = {}
		local str = Line
		local delimiters = { "," }
		local whitespaces = { " ", "\t" }

		while string.len(str) > 0 do
			local cursor1 = 1
			while NthCharIs(str, cursor1, delimiters) and cursor1 <= string.len(str) do
				cursor1 = cursor1 + 1
			end
			local cursor2 = cursor1
			while cursor2 <= string.len(str) and not NthCharIs(str, cursor2, delimiters) do
				cursor2 = cursor2 + 1
			end
			if cursor1 < cursor2 then
				table.insert(words, string.sub(str, cursor1, cursor2 - 1))
			end
			str = string.sub(str, cursor2, -1)
		end

		for w, word in ipairs(words) do
			local cursor1 = 1
			while NthCharIs(word, cursor1, whitespaces) and cursor1 < string.len(word) do
				cursor1 = cursor1 + 1
			end
			local cursor2 = string.len(word)
			while NthCharIs(word, cursor2, whitespaces) and cursor2 >= 1 do
				cursor2 = cursor2 - 1
			end
			words[w] = string.lower(string.sub(word, cursor1, cursor2))
		end

		for w = #words, 1, -1 do
			if string.len(words[w]) < 1 then
				table.remove(words, w)
			end
		end
		return words
	end

	local function SplitStringNameAndQuantity(word)
		local numericchars = { ".", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" }
		local whitespaces = { " ", "\t" }
		local sign = 1

		if string.len(word) > 1 and string.sub(word, 1, 1) == "-" then
			sign = -1
			word = string.sub(word, 2)
			while string.len(word) > 1 and NthCharIs(word, 1, whitespaces) do
				word = string.sub(word, 2)
			end
		end

		local cursor1 = 0
		while 1 + cursor1 <= string.len(word) and NthCharIs(word, 1 + cursor1, numericchars) do
			cursor1 = cursor1 + 1
		end
		local cursor2 = cursor1 + 1
		while cursor2 <= string.len(word) and NthCharIs(word, cursor2, whitespaces) do
			cursor2 = cursor2 + 1
		end

		if cursor1 > 0 and cursor2 < string.len(word) and cursor1 + 1 < cursor2 and tonumber(string.sub(word, 1, cursor1)) then
			return string.sub(word, cursor2, string.len(word)), sign * tonumber(string.sub(word, 1, cursor1))
		else
			return word, sign
		end
	end

	local function ConcatProvList(techtable, separator)
		local pos, neg = nil, nil
		separator = separator or ", "
		for _, tech in pairs(techtable) do
			local q = tech.quantity
			if (q or 1) < 0 then
				neg = (neg and neg .. separator or "Consumes +")
						.. "\255\255\64\255"
						.. ((q ~= -1) and (-q .. " ") or "")
						.. tech.tech
						.. "\255\255\255\255"
			else
				pos = (pos and pos .. separator or "Provides +")
						.. "\255\64\255\255"
						.. ((q and q ~= 1) and (q .. " ") or "")
						.. tech.tech
						.. "\255\255\255\255"
			end
		end
		return (neg or "") .. (neg and pos and "   /   " or "") .. (pos or "") .. ((neg or pos) and "\r" or "")
	end

	------------------------------------------------------------
	-- Tech bookkeeping
	------------------------------------------------------------
	local function InitTechEntry(techname)
		if not TechTable[techname] then
			TechTable[techname] = {
				name = techname,
				ProvidedBy = {},
				AccessTo = {},
				ProviderSum = {},
				UnlockedMax = {},
			}
			dbgEcho("New Technology declared: \"" .. techname .. "\"")
			for _, team in ipairs(Spring.GetTeamList()) do
				TechTable[techname].ProviderSum[team] = 0
				TechTable[techname].UnlockedMax[team] = 0
				Spring.SetTeamRulesParam(team, "technology:" .. techname, 0)
			end
		end
	end

	local function GetTechLevel(techname, team)
		local tt = TechTable[techname]
		if not tt then
			return 0
		end
		if STICKY_TECH then
			return tt.UnlockedMax[team] or 0
		else
			return tt.ProviderSum[team] or 0
		end
	end

	local function PublishTechLevel(techname, team)
		Spring.SetTeamRulesParam(team, "technology:" .. techname, GetTechLevel(techname, team))
	end

	local function UpdateUnlockedMax(techname, team)
		if not STICKY_TECH then
			return
		end
		local tt = TechTable[techname]
		local cur = tt.ProviderSum[team] or 0
		local best = tt.UnlockedMax[team] or 0
		if cur > best then
			tt.UnlockedMax[team] = cur
		end
	end

	local function isComplete(u)
		local _, _, _, _, buildProgress = Spring.GetUnitHealth(u)
		return (buildProgress and buildProgress >= 1) and true or false
	end

	------------------------------------------------------------
	-- Parse helper for UnitDef selection (GG.TechAddDependency)
	------------------------------------------------------------
	local function ParseUnitDefID(those)
		local udq = {}
		if type(those) == "number" then
			udq[those] = true
		elseif type(those) == "string" then
			udq[UnitDefNames[string.lower(those)].id] = true
		elseif type(those) == "table" then
			for _, udn in pairs(those) do
				if type(udn) == "number" then
					udq[udn] = true
				elseif type(udn) == "string" then
					udq[UnitDefNames[string.lower(udn)].id] = true
				end
			end
		elseif type(those) == "function" then
			for _, ud in pairs(UnitDefs) do
				local q = those(ud.id)
				if q then
					udq[ud.id] = q
				end
			end
		end
		return udq
	end

	------------------------------------------------------------
	-- Public checks
	------------------------------------------------------------
	local function CheckTech(TechName, Team, Threshold)
		TechName = string.lower(TechName)
		if not TechTable[TechName] then
			return nil
		elseif not TechTable[TechName].ProviderSum[Team] then
			Spring.Echo("Bad call to Check Tech: TechName=\"" .. TechName .. "\", Team=" .. Team .. " (wrong)")
			return nil
		end
		return GetTechLevel(TechName, Team) >= (Threshold or 1)
	end

	local function CheckCmd(cmd, team)
		if not AccessionTable[cmd] then
			return true
		end
		for _, req in pairs(AccessionTable[cmd]) do
			if not CheckTech(req.tech, team, req.quantity) then
				dbgEcho("cmd " .. cmd .. " forbidden for lack of " .. req.tech)
				return false
			end
		end
		return true
	end

	------------------------------------------------------------
	-- GG.TechAddDependency (Range is ignored)
	------------------------------------------------------------
	local function DpdcAdd(Providers, Requirings, TechName, _RangeIgnored)
		-- Tech name
		if type(TechName) ~= "string" or string.len(TechName) < 1 then
			local count = 1
			for _, _ in pairs(TechTable) do
				count = count + 1
			end
			TechName = "Tech#" .. count
		end
		TechName = string.lower(TechName)
		InitTechEntry(TechName)

		-- Providers
		local p = ParseUnitDefID(Providers)
		for id, quantity in pairs(p) do
			local q = (type(quantity) == "number") and quantity or nil
			dbgEcho(UnitDefs[id].humanName .. " is now provider of "
					        .. ((q and q ~= 1) and (q .. " ") or "")
					        .. "\"" .. TechName .. "\"")

			local tp = { tech = TechName }
			if q and q ~= 1 then
				tp.quantity = q
			end

			if not ProviderTable[id] then
				ProviderTable[id] = {}
				table.insert(ProviderIDs, id)
			end
			if not ProviderTable[id][TechName] then
				table.insert(TechTable[TechName].ProvidedBy, id)
			end
			ProviderTable[id][TechName] = tp
		end

		-- Users
		local r = ParseUnitDefID(Requirings)
		for id, quantity in pairs(r) do
			local q = (type(quantity) == "number") and quantity or nil
			dbgEcho(UnitDefs[id].humanName .. " is now user of "
					        .. ((q and q ~= 1) and (q .. " ") or "")
					        .. "\"" .. TechName .. "\"")

			local tp = { tech = TechName }
			if q and q ~= 1 then
				tp.quantity = q
			end

			if not AccessionTable[-id] then
				AccessionTable[-id] = {}
				table.insert(AccessionIDs, -id)
			end
			if not AccessionTable[-id][TechName] then
				table.insert(TechTable[TechName].AccessTo, -id)
			end
			AccessionTable[-id][TechName] = tp
		end

		for _, team in ipairs(Spring.GetTeamList()) do
			RecheckTeams[team] = team
		end
	end

	------------------------------------------------------------
	-- Debug dump
	------------------------------------------------------------
	local function DumpTech()
		local count = 0
		local str = "\r\n"
		str = str .. "Technological dump from \"" .. GetInfo().name .. "\" gadget:\r\n"
		for _, tech in pairs(TechTable) do
			count = count + 1
			str = str .. "'" .. string.upper(tech.name) .. "'"

			local provider_str, consumer_str, access_str, team_str = nil, nil, nil, nil

			for _, p in ipairs(tech.ProvidedBy) do
				local q = ProviderTable[p][tech.name].quantity
				local qrt = (q and q .. " " or "") .. "by " .. UnitDefs[p].humanName
				if (q or 1) < 0 then
					consumer_str = (consumer_str and consumer_str .. ", " or "\r\n\tConsumed: ") .. qrt
				else
					provider_str = (provider_str and provider_str .. ", " or "\r\n\tProvided: ") .. qrt
				end
			end

			for _, r in ipairs(tech.AccessTo) do
				local q = AccessionTable[r][tech.name].quantity or 1
				access_str = (access_str and access_str .. ", " or "\r\n\tRequired: ")
						.. (q and q .. " " or "")
						.. "by "
						.. ((r < 0 and UnitDefs[-r]) and UnitDefs[-r].humanName or "CMD " .. r)
			end

			for _, team in ipairs(Spring.GetTeamList()) do
				team_str = (team_str and team_str .. " " or "\r\n\t")
						.. "Team" .. team .. ":" .. GetTechLevel(tech.name, team)
			end

			str = str .. (provider_str or "") .. (consumer_str or "") .. (access_str or "") .. (team_str or "") .. "\r\n"
		end
		str = str .. "Total: " .. count .. " technologies found.\r\n"
		Spring.Echo(str)
	end

	------------------------------------------------------------
	-- Button editing (no ranged/yellow logic)
	------------------------------------------------------------
	local function EditButtons(u, ud, team)
		ud = ud or Spring.GetUnitDefID(u)
		team = team or Spring.GetUnitTeam(u)

		local function GrantingToolTip(u, ucd, cmd)
			if not GrantDesc[cmd] then
				if not OriDesc[cmd] then
					OriDesc[cmd] = Spring.GetUnitCmdDescs(u)[ucd].tooltip
				end
				GrantDesc[cmd] = ConcatProvList(ProviderTable[-cmd], ", ") .. OriDesc[cmd]
			end
			return GrantDesc[cmd]
		end

		-- What is granted (tooltips for build buttons that grant tech)
		for _, pud in ipairs(ProviderIDs) do
			local UnitCmdDesc = Spring.FindUnitCmdDesc(u, -pud)
			if UnitCmdDesc then
				Spring.EditUnitCmdDesc(u, UnitCmdDesc, { tooltip = GrantingToolTip(u, UnitCmdDesc, -pud) })
			end
		end

		-- What is required (disable locked buttons)
		for _, cid in ipairs(AccessionIDs) do
			local UnitCmdDesc = Spring.FindUnitCmdDesc(u, cid)
			if UnitCmdDesc then
				if not OriDesc[cid] then
					OriDesc[cid] = Spring.GetUnitCmdDescs(u)[UnitCmdDesc].tooltip
				end

				local Allowed = true
				local ReqDesc = nil

				for _, req in pairs(AccessionTable[cid]) do
					local color
					if CheckTech(req.tech, team, req.quantity) then
						color = "\255\64\255\64" -- green
					else
						color = "\255\255\64\64" -- red
						Allowed = false
					end
					local q = req.quantity
					ReqDesc = (ReqDesc and ReqDesc .. "\255\255\255\255, " or "\255\255\255\255Requires ")
							.. color
							.. ((q and q ~= 1) and (q .. " ") or "")
							.. req.tech
				end

				ReqDesc = ReqDesc .. "\n\255\255\255\255" .. (GrantDesc[cid] or OriDesc[cid])

				Spring.EditUnitCmdDesc(u, UnitCmdDesc, { disabled = not Allowed, tooltip = ReqDesc })
			end
		end

		-- Call COB scripts when tech state changes (for units that require tech)
		if UnitsWithScripts[u] then
			local newstate = CheckCmd(-Spring.GetUnitDefID(u), team)
			if newstate ~= UnitsWithScripts[u].state then
				UnitsWithScripts[u].state = newstate
				if newstate then
					if UnitsWithScripts[u].TechGrantedCOBFuncID then
						Spring.CallCOBScript(u, UnitsWithScripts[u].TechGrantedCOBFuncID, 0)
					end
				else
					if UnitsWithScripts[u].TechLostCOBFuncID then
						Spring.CallCOBScript(u, UnitsWithScripts[u].TechLostCOBFuncID, 0)
					end
				end
			end
		end
	end

	local function RefreshButtonsWrap(arg)
		local us = {}
		if type(arg) == "number" then
			us = { arg }
		elseif type(arg) == "table" then
			us = arg
		else
			us = Spring.GetAllUnits()
		end
		for _, u in pairs(us) do
			EditButtons(u)
		end
	end

	------------------------------------------------------------
	-- GG.TechSlaveCommand
	------------------------------------------------------------
	local function SlvCmd(cmd, str_reqs)
		if AccessionTable[cmd] then
			Spring.Echo("Slave Command Error: command " .. cmd .. " already tech-slaved")
			return false
		end

		local lst_reqs = SplitStringComma(str_reqs)
		AccessionTable[cmd] = {}
		table.insert(AccessionIDs, cmd)

		for _, w in ipairs(lst_reqs) do
			local t, q = SplitStringNameAndQuantity(w)
			dbgEcho("CMD " .. cmd .. " is user of " .. ((q and q ~= 1) and q .. " " or "") .. "\"" .. t .. "\"")
			InitTechEntry(t)

			local tp = { tech = t }
			if q and q ~= 1 then
				tp.quantity = q
			end

			AccessionTable[cmd][t] = tp
			table.insert(TechTable[t].AccessTo, cmd)
		end

		for _, u in ipairs(Spring.GetAllUnits()) do
			local UnitCmdDesc = Spring.FindUnitCmdDesc(u, cmd)
			if UnitCmdDesc then
				EditButtons(u)
			end
		end

		return true
	end

	------------------------------------------------------------
	-- GG.TechGrant (sticky aware)
	------------------------------------------------------------
	local function GrantTech(TechName, Team, Quantity)
		TechName = string.lower(TechName)
		InitTechEntry(TechName)

		if not TechTable[TechName].ProviderSum[Team] then
			Spring.Echo("Bad call to Grant Tech: TechName=\"" .. TechName .. "\", Team=" .. Team .. " (wrong)")
			return false
		end

		local val = Quantity or math.huge
		TechTable[TechName].ProviderSum[Team] = val
		if STICKY_TECH then
			TechTable[TechName].UnlockedMax[Team] = val
		end

		PublishTechLevel(TechName, Team)
		RecheckTeams[Team] = Team
		return true
	end

	------------------------------------------------------------
	-- Provider sum mutations
	------------------------------------------------------------
	local function UnitLost(u, ud, team)
		if ProviderTable[ud] then
			for _, pt in pairs(ProviderTable[ud]) do
				if (isComplete(u) or (pt.quantity or 1) < 0) then
					local tech = pt.tech
					TechTable[tech].ProviderSum[team] = TechTable[tech].ProviderSum[team] - (pt.quantity or 1)
					-- Sticky: do NOT decrease UnlockedMax
					PublishTechLevel(tech, team)
					RecheckTeams[team] = team
				end
			end
		end
	end

	------------------------------------------------------------
	-- Engine hooks
	------------------------------------------------------------
	function gadget:UnitCreated(u, ud, team)
		local idl, idg = Spring.GetCOBScriptID(u, "TechLost"), Spring.GetCOBScriptID(u, "TechGranted")
		if AccessionTable[-ud] and (idl or idg) then
			UnitsWithScripts[u] = { state = nil, TechLostCOBFuncID = idl, TechGrantedCOBFuncID = idg }
		end

		if ProviderTable[ud] then
			Spring.SetUnitTooltip(u, ConcatProvList(ProviderTable[ud]) .. Spring.GetUnitTooltip(u))
			for _, pt in pairs(ProviderTable[ud]) do
				-- Negative provide counts while under construction
				if (pt.quantity or 1) < 0 then
					local tech = pt.tech
					TechTable[tech].ProviderSum[team] = TechTable[tech].ProviderSum[team] + (pt.quantity or 1)
					UpdateUnlockedMax(tech, team)
					PublishTechLevel(tech, team)
					RecheckTeams[team] = team
				end
			end
		end

		EditButtons(u, ud, team)
	end

	function gadget:UnitFinished(u, ud, team)
		if ProviderTable[ud] then
			for _, pt in pairs(ProviderTable[ud]) do
				-- Positive provide counts only once finished
				if (pt.quantity or 1) >= 0 then
					local tech = pt.tech
					TechTable[tech].ProviderSum[team] = TechTable[tech].ProviderSum[team] + (pt.quantity or 1)
					UpdateUnlockedMax(tech, team)
					PublishTechLevel(tech, team)
					RecheckTeams[team] = team
				end
			end
		end
		EditButtons(u, ud, team)
	end

	function gadget:UnitDestroyed(u, ud, team)
		if ProviderTable[ud] then
			UnitLost(u, ud, team)
		end
		UnitsWithScripts[u] = nil
	end

	function gadget:UnitGiven(u, ud, team, oldteam)
		if ProviderTable[ud] then
			for _, pt in pairs(ProviderTable[ud]) do
				if (isComplete(u) or (pt.quantity or 1) < 0) and not Spring.GetUnitIsDead(u) then
					local tech = pt.tech
					TechTable[tech].ProviderSum[team] = TechTable[tech].ProviderSum[team] + (pt.quantity or 1)
					UpdateUnlockedMax(tech, team)
					PublishTechLevel(tech, team)
					RecheckTeams[team] = team
				end
			end
		end
		EditButtons(u, ud, team)
	end

	function gadget:UnitTaken(u, ud, team, newteam)
		if ProviderTable[ud] then
			UnitLost(u, ud, team)
		end
	end

	function gadget:AllowCommand(u, ud, team, cmd, param, opt, synced)
		local ok = CheckCmd(cmd, team)
		if not ok then
			local x, y, z = Spring.GetUnitPosition(u)
			if x then
				Spring.SpawnCEG("moarpower", x, y, z)
			end
		end
		return ok
	end

	function gadget:AllowUnitCreation(ud, isBuilder, team, x, y, z)
		return CheckCmd(-ud, team)
	end

	------------------------------------------------------------
	-- Initialize: parse UnitDefs
	------------------------------------------------------------
	function gadget:Initialize()
		for _, ud in pairs(UnitDefs) do
			local cp = ud.customParams
			if cp then
				local str_p = cp.providestech or cp.providetech
				local str_r = cp.requirestech or cp.requiretech

				if str_p then
					local lst_p = SplitStringComma(str_p)
					ProviderTable[ud.id] = {}
					table.insert(ProviderIDs, ud.id)

					for _, w in ipairs(lst_p) do
						local t, q = SplitStringNameAndQuantity(w)
						dbgEcho(ud.humanName .. " is provider of "
								        .. ((q and q ~= 1) and (q .. " ") or "")
								        .. "\"" .. t .. "\"")

						InitTechEntry(t)

						local tp = { tech = t }
						if q and q ~= 1 then
							tp.quantity = q
						end
						ProviderTable[ud.id][t] = tp
						table.insert(TechTable[t].ProvidedBy, ud.id)
					end
				end

				if str_r then
					local lst_r = SplitStringComma(str_r)
					AccessionTable[-ud.id] = {}
					table.insert(AccessionIDs, -ud.id)

					for _, w in ipairs(lst_r) do
						local t, q = SplitStringNameAndQuantity(w)
						dbgEcho(ud.humanName .. " is user of "
								        .. ((q and q ~= 1) and (q .. " ") or "")
								        .. "\"" .. t .. "\"")

						InitTechEntry(t)

						local tp = { tech = t }
						if q and q ~= 1 then
							tp.quantity = q
						end
						AccessionTable[-ud.id][t] = tp
						table.insert(TechTable[t].AccessTo, -ud.id)
					end
				end
			end
		end

		-- Expose API
		GG.TechAddDependency = DpdcAdd
		GG.TechSlaveCommand = SlvCmd
		GG.TechCheckCommand = CheckCmd
		GG.TechCheck = CheckTech
		GG.TechGrant = GrantTech
		GG.TechDump = DumpTech
		GG.TechRefreshButtons = RefreshButtonsWrap
	end

	------------------------------------------------------------
	-- Periodic refresh
	------------------------------------------------------------
	function gadget:GameFrame(frame)
		if frame % 19 == 17 then
			if RecheckTeams then
				for _, team in pairs(RecheckTeams) do
					for _, u in ipairs(Spring.GetTeamUnits(team)) do
						EditButtons(u, nil, team)
					end
				end
				RecheckTeams = {}
			end
		end
	end

else
	-- No unsynced section needed (ranged tech removed).
end
