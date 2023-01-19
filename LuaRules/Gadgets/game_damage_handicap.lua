function gadget:GetInfo()
	return {
		name = "Damage Handicap",
		desc = "aaaaaaaaaa",
		author = "Damgam",
		date = "2023",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

local teamList = {}

local teams = Spring.GetTeamList()
for _, teamID in ipairs(teams) do
    teamList[teamID] = 1
end

if not gadgetHandler:IsSyncedCode() then

    function gadget:Initialize()
        gadgetHandler:AddChatAction('handicap', handicap, "") -- /luarules handicap playername multiplier
    end

    function handicap(_, line, words)
        local msg = "handicap"
        for i=1,5 do
            if words[i] then 
                msg = msg .. " " .. tostring(words[i])
            end
        end
        Spring.SendLuaRulesMsg(msg)
    end

else

    function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
        return damage*teamList[unitTeam]
    end

    function gadget:RecvLuaMsg(msg, playerID)
        if string.find(msg, "handicap") then
            if (not Spring.IsCheatingEnabled()) then
                Spring.Echo("[Damage Handicap] Cheating must be enabled")
                return false
            end
            -- Spring.Echo("[Damage Handicap] Cheating is enabled")
            -- "/luarules handicap ForbodingAngel 5"
            local run = 1
            local teamID = -1
            for cutMsg in string.gmatch(msg, "[^%s]+") do
                
                if run == 1 then -- command name, we want to skip it

                    run = 2

                elseif run == 2 then -- player name
                    
                    local playerList = Spring.GetPlayerList()
                    
                    for i = 1, #playerList do
                        if cutMsg == Spring.GetPlayerInfo(playerList[i]) then
                            teamID = select(4, Spring.GetPlayerInfo(playerList[i]))
                            -- Spring.Echo("[Damage Handicap] teamID is " .. teamID)
                        end
                    end
                    run = 3

                elseif run == 3 and teamID >= 0 then -- handicap we want to set

                    teamList[teamID] = tonumber(cutMsg)

                end
            end
        end
    end
end

