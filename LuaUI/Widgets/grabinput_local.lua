function widget:GetInfo()
	return {
		name	= "Grabinput Local",
		desc	= "Enables GrabInput in Windowed mode",
		author	= "abma",
		date	= "2012-08-11",
		license	= "GPL v2 or later",
		layer	= 5,
		enabled	= true
	}
end

function widget:Initialize()
		Spring.SendCommands("grabinput 1")
end

function widget:GameFrame(n)
-- send grabinput every 5 seconds
	if n%150 == 1 then
		Spring.SendCommands("grabinput 1")
	end
end