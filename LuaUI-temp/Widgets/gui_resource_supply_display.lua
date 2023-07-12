function widget:GetInfo()
    return {
        name = "Resource: Supply Text Display",
        desc = "Displays supply economy parameters as text",
        author = "Code_Man",
        date = "11/4/2016",
        license = "MIT X11",
        layer = 1,
        enabled = false
    }
end

local white = "\255\255\255\255"
local yellow = "\255\255\255\0"
local orange = "\255\255\135\0"
local green = "\255\0\255\0"
local red = "\255\255\0\0"
local skyblue = "\255\136\197\226"

local str = ""
local FontSize = 15
local vsx, vsy = gl.GetViewSizes()
local posx, posy = vsx - 245, vsy - 60
local maxSupply = 200

local increment = 0

function widget:GameFrame(n)
	local myTeamID = Spring.GetMyTeamID()
	--math.round(Spring.GetTeamRulesParam(myTeamID, "supplyUsed")) -- (su)
	--math.round(Spring.GetTeamRulesParam(myTeamID, "supplyMax")) -- (sm)
    local su, sm = math.round(Spring.GetTeamRulesParam(myTeamID, "supplyUsed")), math.round(Spring.GetTeamRulesParam(myTeamID, "supplyMax"))
	if su <= maxSupply * 0.95 then
		if su >= sm * 0.9 and sm ~= maxSupply then
			warning = true
		else
			warning = false
		end
		
		if warning == true then
			if increment == 0 then
				countUp = true
			end
		
			if increment < 255 and countUp == true then
				increment = increment + 15
			elseif increment > 0 then
				countUp = false
				increment = increment - 15
			end
			
			warningColor = "\255\255" .. string.char (increment) .. "\0"

		else
			warningColor = green
		end
	else
		warningColor = green
	end

	str = warningColor .. "Supply: " .. white .. su .. "/" .. sm .. " (" .. orange .. "�" .. tostring(sm - su) .. white .. "/" .. green .. maxSupply .. white .. ")"
end

function widget:TweakMousePress(x, y, button)
    if x >= posx and x < posx + 100 and y >= posy and y < posy + FontSize * 2 then
        return true
    end
end

function widget:TweakMouseMove(x, y, dx, dy, button)
    if x >= 0 and x < vsx - 100 and y >= 0 and y < vsy then
        posx = x
        posy = y
    end
end

function DrawScreen()
    local vsx, vsy = gl.GetViewSizes()
    gl.Text(str, posx, posy, FontSize, "on")  
end