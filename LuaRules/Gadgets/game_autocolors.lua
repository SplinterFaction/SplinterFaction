function gadget:GetInfo()
	return {
		name = "AutoColorPicker",
		desc = "Automatically assigns colors to teams",
		author = "Damgam, Born2Crawl (color palette)",
		date = "2021",
		license = "GNU GPL, v2 or later",
		layer = -100,
		enabled = true,
	}
end

local function hex2RGB(hex)
    hex = hex:gsub("#","")
    return {tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))}
end

-- Special colors
local armBlueColor       = "#004DFF" -- Armada Blue
local corRedColor        = "#FF1005" -- Cortex Red
local scavPurpColor      = "#6809A1" -- Scav Purple
local chickenOrangeColor = "#CC8914" -- Chicken Orange
local gaiaGrayColor      = "#7F7F7F" -- Gaia Grey

if gadgetHandler:IsSyncedCode() then

	-- NEW IceXuick Colors V6
	local ffaColors = {
		"#004DFF", -- 1
		"#FF1005", -- 2
		"#0CE908", -- 3
		"#FFD200", -- 4
		"#F80889", -- 5
		"#09F5F5", -- 6
		"#FF6107", -- 7
		"#F190B3", -- 8
		"#097E1C", -- 9
		"#C88B2F", -- 10
		"#7CA1FF", -- 11
		"#9F0D05", -- 12
		"#3EFFA2", -- 13
		"#F5A200", -- 14
		"#C4A9FF", -- 15
		"#0B849B", -- 16
		"#B4FF39", -- 17
		"#FF68EA", -- 18
		"#D8EEFF", -- 19
		"#689E3D", -- 20
		"#B04523", -- 21
		"#FFBB7C", -- 22
		"#3475FF", -- 23
		"#DD783F", -- 24
		"#FFAAF3", -- 25
		"#4A4376", -- 26
		"#773A01", -- 27
		"#B7EA63", -- 28
		"#9F0D05", -- 29
		"#7EB900", -- 30
	}

	local survivalColors = {
		"#0B3EF3", -- 1
		"#FF1005", -- 2
		"#0CE908", -- 3
		"#F80889", -- 4
		"#09F5F5", -- 5
		"#FCEEA4", -- 6
		"#097E1C", -- 7
		"#F190B3", -- 8
		"#2C32AC", -- 9
		"#3EFFA2", -- 10
		"#FF6058", -- 11
		"#7CA1FF", -- 12
		"#A35274", -- 13
		"#B04523", -- 14
		"#B4FF39", -- 15
		"#773A01", -- 16
		"#D8EEFF", -- 17
		"#689E3D", -- 18
		"#0B849B", -- 19
		"#FFD200", -- 20
		"#971C48", -- 21
		"#4A4376", -- 22
		"#764A4A", -- 23
		"#4F2684", -- 24
	}

	local teamColors = {
		{ -- One Team (not possible)
			{ -- First Team
				"#004DFF", -- Armada Blue
			},
		},

		{ -- Two Teams
			{ -- First Team (Cool)
				"#0B3EF3", --1
				"#0CE908", --2
				"#872DFA", --3
				"#09F5F5", --4
				"#097E1C", --5
				"#7CA1FF", --6
				"#B4FF39", --7
				"#3EFFA2", --8
				"#0B849B", --9
				"#689E3D", --10
				"#4F2684", --11
				"#2C32AC", --12
				"#6968A0", --13
				"#D8EEFF", --14
				"#3475FF", --15
				"#7EB900", --16
				"#4A4376", --17
				"#B7EA63", --18
				"#C4A9FF", --19
				"#37713A", --20
			},
			{ -- Second Team (Warm)
				"#FF1005", --1
				"#FFD200", --2
				"#FF6107", --3
				"#F80889", --4
				"#FCEEA4", --5
				"#FF6058", --6
				"#F190B3", --7
				"#C88B2F", --8
				"#B04523", --9
				"#FFBB7C", --10
				"#A35274", --11
				"#773A01", --12
				"#F5A200", --13
				"#BBA28B", --14
				"#971C48", --15
				"#FF68EA", --16
				"#DD783F", --17
				"#FFAAF3", --18
				"#764A4A", --19
				"#9F0D05", --20
			},
		},

		{ -- Three Teams
			{ -- First Team (Blue)
				"#004DFF", -- 1
				"#09F5F5", -- 2
				"#7CA1FF", -- 3
				"#2C32AC", -- 4
				"#D8EEFF", -- 5
				"#0B849B", -- 6
				"#3C7AFF", -- 7
				"#5F6492", -- 8
			},
			{ -- Second Team (Red)
				"#FF1005", -- 1
				"#FF6107", -- 2
				"#FFD200", -- 3
				"#FF6058", -- 4
				"#FFBB7C", -- 5
				"#C88B2F", -- 6
				"#F5A200", -- 7
				"#9F0D05", -- 8
			},
			{ -- Third Team (Green)
				"#0CE818", -- 1
				"#B4FF39", -- 2
				"#097E1C", -- 3
				"#3EFFA2", -- 4
				"#689E3D", -- 5
				"#7EB900", -- 6
				"#B7EA63", -- 7
				"#37713A", -- 8
			},
		},

		{ -- Four Teams
			{ -- First Team (Blue)
				"#004DFF", -- 1
				"#7CA1FF", -- 2
				"#D8EEFF", -- 3
				"#09F5F5", -- 4
				"#3475FF", -- 5
				"#0B849B", -- 6
			},
			{ -- Second Team (Red)
				"#FF1005", -- 1
				"#FF6107", -- 2
				"#FF6058", -- 3
				"#B04523", -- 4
				"#F80889", -- 5
				"#971C48", -- 6
			},
			{ -- Third Team (Green)
				"#0CE818", -- 1
				"#B4FF39", -- 2
				"#097E1C", -- 3
				"#3EFFA2", -- 4
				"#689E3D", -- 5
				"#7EB900", -- 6
			},
			{ -- Fourth Team (Yellow)
				"#FFD200", -- 1
				"#F5A200", -- 2
				"#FCEEA4", -- 3
				"#FFBB7C", -- 4
				"#BBA28B", -- 5
				"#C88B2F", -- 6
			},
		},

		{ -- Five Teams
			{ -- First Team (Blue)
				"#004DFF", -- 1
				"#7CA1FF", -- 2
				"#D8EEFF", -- 3
				"#09F5F5", -- 4
				"#3475FF", -- 5
			},
			{ -- Second Team (Red)
				"#FF1005", -- 1
				"#FF6107", -- 2
				"#FF6058", -- 3
				"#B04523", -- 4
				"#9F0D05", -- 5
			},
			{ -- Third Team (Green)
				"#0CE818", -- 1
				"#B4FF39", -- 2
				"#097E1C", -- 3
				"#3EFFA2", -- 4
				"#689E3D", -- 5
			},
			{ -- Fourth Team (Yellow)
				"#FFD200", -- 1
				"#F5A200", -- 2
				"#FCEEA4", -- 3
				"#FFBB7C", -- 4
				"#C88B2F", -- 5
			},
			{ -- Fifth Team (Fuchsia)
				"#F80889", -- 1
				"#FF68EA", -- 2
				"#FFAAF3", -- 3
				"#AA0092", -- 4
				"#701162", -- 5
			},
		},

		{ -- Six Teams
			{ -- First Team (Blue)
				"#004DFF", -- 1
				"#7CA1FF", -- 2
				"#D8EEFF", -- 3
				"#2C32AC", -- 4
			},
			{ -- Second Team (Red)
				"#FF1005", -- 1
				"#FF6058", -- 2
				"#B04523", -- 3
				"#9F0D05", -- 4
			},
			{ -- Third Team (Green)
				"#0CE818", -- 1
				"#B4FF39", -- 2
				"#097E1C", -- 3
				"#3EFFA2", -- 4
			},
			{ -- Fourth Team (Yellow)
				"#FFD200", -- 1
				"#F5A200", -- 2
				"#FCEEA4", -- 3
				"#9B6408", -- 4
			},
			{ -- Fifth Team (Fuchsia)
				"#F80889", -- 1
				"#FF68EA", -- 2
				"#FFAAF3", -- 3
				"#971C48", -- 4
			},
			{ -- Sixth Team (Orange)
				"#FF6107", -- 1
				"#FFBB7C", -- 2
				"#DD783F", -- 3
				"#773A01", -- 4
			},
		},

		{ -- Seven Teams
			{ -- First Team (Blue)
				"#004DFF", -- 1
				"#7CA1FF", -- 2
				"#2C32AC", -- 3
			},
			{ -- Second Team (Red)
				"#FF1005", -- 1
				"#FF6058", -- 2
				"#9F0D05", -- 3
			},
			{ -- Third Team (Green)
				"#0CE818", -- 1
				"#B4FF39", -- 2
				"#097E1C", -- 3
			},
			{ -- Fourth Team (Yellow)
				"#FFD200", -- 1
				"#F5A200", -- 2
				"#FCEEA4", -- 3
			},
			{ -- Fifth Team (Fuchsia)
				"#F80889", -- 1
				"#FF68EA", -- 2
				"#FFAAF3", -- 3
			},
			{ -- Sixth Team (Orange)
				"#FF6107", -- 1
				"#FFBB7C", -- 2
				"#DD783F", -- 3
			},
			{ -- Seventh Team (Cyan)
				"#09F5F5", -- 1
				"#0B849B", -- 2
				"#D8EEFF", -- 3
			},
		},

		{ -- Eight Teams
			{ -- First Team (Blue)
				"#004DFF", -- 1
				"#7CA1FF", -- 2
				"#2C32AC", -- 3
			},
			{ -- Second Team (Red)
				"#FF1005", -- 1
				"#FF6058", -- 2
				"#9F0D05", -- 3
			},
			{ -- Third Team (Green)
				"#0CE818", -- 1
				"#B4FF39", -- 2
				"#097E1C", -- 3
			},
			{ -- Fourth Team (Yellow)
				"#FFD200", -- 1
				"#F5A200", -- 2
				"#FCEEA4", -- 3
			},
			{ -- Fifth Team (Fuchsia)
				"#F80889", -- 1
				"#FF68EA", -- 2
				"#971C48", -- 3
			},
			{ -- Sixth Team (Orange)
				"#FF6107", -- 1
				"#FFBB7C", -- 2
				"#DD783F", -- 3
			},
			{ -- Seventh Team (Cyan)
				"#09F5F5", -- 1
				"#0B849B", -- 2
				"#D8EEFF", -- 3
			},
			{ -- Eigth Team (Purple)
				"#872DFA", -- 1
				"#6809A1", -- 2
				"#C4A9FF", -- 3
			},
		},

	}

	local gaiaTeamID = Spring.GetGaiaTeamID()
	local teamList = Spring.GetTeamList()
	local allyTeamList = Spring.GetAllyTeamList()
	local teamCount = #teamList - 1
	local allyTeamCount = #allyTeamList - 1

	local isFFA = false
	if #teamList == #allyTeamList and teamCount > 2 then
		isFFA = true
	elseif not teamColors[allyTeamCount] then
		isFFA = true
	end
	local isSurvival = Spring.Utilities.Gametype.IsScavengers() or Spring.Utilities.Gametype.IsChickens()

	local survivalColorNum = 1 -- Starting from color #1
	local survivalColorVariation = 0 -- Current color variation
	local ffaColorNum = 1 -- Starting from color #1
	local ffaColorVariation = 0 -- Current color variation
	local colorVariationDelta = 128 -- Delta for color variation
	local allyTeamNum = 0
	local teamSizes = {}

	local function setUpTeamColor(teamID, allyTeamID, isAI)
		if isAI and string.find(isAI, "Scavenger") then
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", hex2RGB(scavPurpColor)[1])
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", hex2RGB(scavPurpColor)[2])
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", hex2RGB(scavPurpColor)[3])
		elseif isAI and string.find(isAI, "Chicken") then
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", hex2RGB(chickenOrangeColor)[1])
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", hex2RGB(chickenOrangeColor)[2])
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", hex2RGB(chickenOrangeColor)[3])
		elseif teamID == gaiaTeamID then
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", hex2RGB(gaiaGrayColor)[1])
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", hex2RGB(gaiaGrayColor)[2])
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", hex2RGB(gaiaGrayColor)[3])
		elseif isSurvival then
			if not survivalColors[survivalColorNum] then -- If we have no color for this team anymore
				survivalColorNum = 1 -- Starting from the first color again..
				survivalColorVariation = survivalColorVariation + colorVariationDelta -- ..but adding random color variations with increasing amplitude with every cycle
			end

			-- Assigning R,G,B values with specified color variations
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", hex2RGB(survivalColors[survivalColorNum])[1] + math.random(-survivalColorVariation, survivalColorVariation))
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", hex2RGB(survivalColors[survivalColorNum])[2] + math.random(-survivalColorVariation, survivalColorVariation))
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", hex2RGB(survivalColors[survivalColorNum])[3] + math.random(-survivalColorVariation, survivalColorVariation))
			survivalColorNum = survivalColorNum + 1 -- Will start from the next color next time
		elseif isFFA then
			if not ffaColors[ffaColorNum] then -- If we have no color for this team anymore
				ffaColorNum = 1 -- Starting from the first color again..
				ffaColorVariation = ffaColorVariation + colorVariationDelta -- ..but adding random color variations with increasing amplitude with every cycle
			end

			-- Assigning R,G,B values with specified color variations
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", hex2RGB(ffaColors[ffaColorNum])[1] + math.random(-ffaColorVariation, ffaColorVariation))
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", hex2RGB(ffaColors[ffaColorNum])[2] + math.random(-ffaColorVariation, ffaColorVariation))
			Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", hex2RGB(ffaColors[ffaColorNum])[3] + math.random(-ffaColorVariation, ffaColorVariation))
			ffaColorNum = ffaColorNum + 1 -- Will start from the next color next time

		else
			if not teamSizes[allyTeamID] then
				allyTeamNum = allyTeamNum + 1
				teamSizes[allyTeamID] = {allyTeamNum, 1, 0} -- Team number, Starting color number, Color variation
			end
			if teamColors[allyTeamCount] -- If we have the color set for this number of teams
				and teamColors[allyTeamCount][teamSizes[allyTeamID][1]] then -- And this team number exists in the color set
				if not teamColors[allyTeamCount][teamSizes[allyTeamID][1]][teamSizes[allyTeamID][2]] then -- If we have no color for this player anymore
					teamSizes[allyTeamID][2] = 1 -- Starting from the first color again..
					teamSizes[allyTeamID][3] = teamSizes[allyTeamID][3] + colorVariationDelta -- ..but adding random color variations with increasing amplitude with every cycle
				end

				-- Assigning R,G,B values with specified color variations
				Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", hex2RGB(teamColors[allyTeamCount][teamSizes[allyTeamID][1]][teamSizes[allyTeamID][2]])[1] + math.random(-teamSizes[allyTeamID][3], teamSizes[allyTeamID][3]))
				Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", hex2RGB(teamColors[allyTeamCount][teamSizes[allyTeamID][1]][teamSizes[allyTeamID][2]])[2] + math.random(-teamSizes[allyTeamID][3], teamSizes[allyTeamID][3]))
				Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", hex2RGB(teamColors[allyTeamCount][teamSizes[allyTeamID][1]][teamSizes[allyTeamID][2]])[3] + math.random(-teamSizes[allyTeamID][3], teamSizes[allyTeamID][3]))
				teamSizes[allyTeamID][2] = teamSizes[allyTeamID][2] + 1 -- Will start from the next color next time
			else
				Spring.Echo("[AUTOCOLORS] Error: Team Colors Table is broken or missing for this allyteam set")
				Spring.SetTeamRulesParam(teamID, "AutoTeamColorRed", 255)
				Spring.SetTeamRulesParam(teamID, "AutoTeamColorGreen", 255)
				Spring.SetTeamRulesParam(teamID, "AutoTeamColorBlue", 255)
			end
		end
	end

	local AutoColors = {}
	for i = 1,#teamList do
		local teamID = teamList[i]
		local allyTeamID = select(6, Spring.GetTeamInfo(teamID))
		local isAI = Spring.GetTeamLuaAI(teamID)
		setUpTeamColor(teamID, allyTeamID, isAI)

		local r = Spring.GetTeamRulesParam(teamID, "AutoTeamColorRed")
		local g = Spring.GetTeamRulesParam(teamID, "AutoTeamColorGreen")
		local b = Spring.GetTeamRulesParam(teamID, "AutoTeamColorBlue")

		AutoColors[i] = {
			teamID = teamID,
			r = r,
			g = g,
			b = b,
		}
	end

	-- Spring.SendLuaRulesMsg("AutoColors", Json.encode(AutoColors))


else	-- UNSYNCED


	local anonymousMode = false --Spring.GetModOptions().teamcolors_anonymous_mode

	local iconDevModeColors = {
		armblue       = armBlueColor,
		corred        = corRedColor,
		scavpurp      = scavPurpColor,
		chickenorange = chickenOrangeColor,
		gaiagray      = gaiaGrayColor,
	}
	local iconDevMode = "no" --Spring.GetModOptions().teamcolors_icon_dev_mode
	local iconDevModeColor = iconDevModeColors[iconDevMode]

	local gaiaTeamID = Spring.GetGaiaTeamID()
	local teamList = Spring.GetTeamList()

	local function updateTeamColors()
		local myTeamID = Spring.GetMyTeamID()
		local myAllyTeamID = Spring.GetMyAllyTeamID()
		for i = 1, #teamList do
			local teamID = teamList[i]
			local r = Spring.GetTeamRulesParam(teamID, "AutoTeamColorRed")/255
			local g = Spring.GetTeamRulesParam(teamID, "AutoTeamColorGreen")/255
			local b = Spring.GetTeamRulesParam(teamID, "AutoTeamColorBlue")/255

			if iconDevModeColor then
				Spring.SetTeamColor(teamID, hex2RGB(iconDevModeColor)[1]/255, hex2RGB(iconDevModeColor)[2]/255, hex2RGB(iconDevModeColor)[3]/255)
			elseif Spring.GetConfigInt("SimpleTeamColors", 0) == 1 or (anonymousMode and not Spring.GetSpectatingState()) then
				local allyTeamID = select(6, Spring.GetTeamInfo(teamID))
				if teamID == myTeamID then
					Spring.SetTeamColor(teamID,
						Spring.GetConfigInt("SimpleTeamColorsPlayerR", 0)/255,
						Spring.GetConfigInt("SimpleTeamColorsPlayerG", 77)/255,
						Spring.GetConfigInt("SimpleTeamColorsPlayerB", 255)/255)
				elseif allyTeamID == myAllyTeamID then
					Spring.SetTeamColor(teamID,
						Spring.GetConfigInt("SimpleTeamColorsAllyR", 0)/255,
						Spring.GetConfigInt("SimpleTeamColorsAllyG", 255)/255,
						Spring.GetConfigInt("SimpleTeamColorsAllyB", 0)/255)
				elseif allyTeamID ~= myAllyTeamID and teamID ~= gaiaTeamID then
					Spring.SetTeamColor(teamID,
						Spring.GetConfigInt("SimpleTeamColorsEnemyR", 255)/255,
						Spring.GetConfigInt("SimpleTeamColorsEnemyG", 16)/255,
						Spring.GetConfigInt("SimpleTeamColorsEnemyB", 5)/255)
				else
					Spring.SetTeamColor(teamID, hex2RGB(gaiaGrayColor)[1]/255, hex2RGB(gaiaGrayColor)[2]/255, hex2RGB(gaiaGrayColor)[3]/255)
				end
			else
				Spring.SetTeamColor(teamID, r, g, b)
			end
		end
	end
	updateTeamColors()

	function gadget:Update()
		if math.random(0,60) == 0 then
			updateTeamColors()
		elseif Spring.GetConfigInt("UpdateTeamColors", 0) == 1 then
			updateTeamColors()
			Spring.SetConfigInt("UpdateTeamColors", 0)
			Spring.SetConfigInt("SimpleTeamColors_Reset", 0)
		end
	end
end
