function widget:GetInfo()
  return {
    name      = "Game CMDCOLORS.TXT",
    desc      = "Sets custom cmdcolors, disable to load engine defaults again",
    author    = "Floris",
    date      = "2016",
    license   = "parrot",
    layer     = 99999999999,
    enabled   = true,
	}
end

function widget:Initialize()
	local file = VFS.LoadFile("cmdcolors_mod.txt")
	if file then
		Spring.LoadCmdColorsConfig(file)
	end
end

function widget:Shutdown()
	local file = VFS.LoadFile("cmdcolors.txt")
	if file then
		Spring.LoadCmdColorsConfig(file)
	end
end
