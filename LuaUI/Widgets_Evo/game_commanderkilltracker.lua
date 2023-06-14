function widget:GetInfo()
	return {
		name      = "Commander Kills Tracker",
		desc      = "Tracks and writes the number of enemy commanders your team has killed to a file",
		author    = "",
		date      = "",
		license   = "",
		layer     = 0,
		enabled   = false
	}
end

local killsFile = "luaui/config/sf_ckc"
local killCount = 0
local myTeamID = Spring.GetMyTeamID

function widget:Initialize()
	-- See if the kills file exists
	if not VFS.FileExists(killsFile) then
		Spring.Echo("THE KILLS FILE DOES NOT EXIST SO I WILL CREATE IT")
		file = io.open(killsFile, "w");
		file:write("")
		file:close()
	end

	-- Load previous kill count from file
	if VFS.FileExists(killsFile) then
		Spring.Echo("THE KILLS FILE EXISTS")
		local file = io.open(killsFile, "r")
		local content = file:read("*all")
		io.close(file)
		killCount = tonumber(content) or 0
	end
end

--So apparently, unitdestroyed in widgetspace is only called when one of your own units dies
--Unfortunately, the only way I can see this ever actually working is to have a gadget that adds enemy team commander deaths to a rulesparam and keeps incrementing a counter. Then,in gameover() in the widget we can read the number there, add it to the number we got from the existing file, and write that to the count file. Unfortunately I quite possibly lack the skill to do this. This widget will stick around until a figure out how to do it. Everything is a damn project.
function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	Spring.Echo("A UNIT DIED")
	if unitTeam and attackerTeam ~= myTeamID() then
		Spring.Echo("THE UNIT IS NOT ON MY TEAM")
		if Spring.GetUnitDefID(unitID) == UnitDefNames["lozcommander"].id or
				Spring.GetUnitDefID(unitID) == UnitDefNames["lozcommander_up1"].id or
				Spring.GetUnitDefID(unitID) == UnitDefNames["lozcommander_up2"].id or
				Spring.GetUnitDefID(unitID) == UnitDefNames["lozcommander_up3"].id or
				Spring.GetUnitDefID(unitID) == UnitDefNames["lozcommander_up4"].id or
				Spring.GetUnitDefID(unitID) == UnitDefNames["fedcommander"].id or
				Spring.GetUnitDefID(unitID) == UnitDefNames["fedcommander_up1"].id or
				Spring.GetUnitDefID(unitID) == UnitDefNames["fedcommander_up2"].id or
				Spring.GetUnitDefID(unitID) == UnitDefNames["fedcommander_up3"].id or
				Spring.GetUnitDefID(unitID) == UnitDefNames["fedcommander_up4"].id then
			Spring.Echo("AN ENEMY COMMANDER DIED")
			killCount = killCount + 1
			WriteKillCountToFile()
		end
	end
end

function WriteKillCountToFile()
	local file = io.open(killsFile, "w")
	file:write(tostring(killCount))
	io.close(file)
end
