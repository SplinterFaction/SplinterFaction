--------------------------------------------------------------------------------
-- These represent both the area of effect and the camerashake amount as well as the light effect on the ground and surrounding units
smallExplosion = 100
mediumExplosion = 200
largeExplosion = 300
hugeExplosion = 600

smallExplosionTTL = 15
mediumExplosionTTL = 30
largeExplosionTTL = 60
hugeExplosionTTL = 120

-- colors
red = [[1 0 0]]
yellow = [[1 1 0]]
green = [[0 1 0]]
blue = [[0 0 1]]
orange = [[1 0.5 0]]
white = [[1 1 1]]
purple = [[0.2 0 1]]

--[[
-- These go in Weapons CustomParams
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second

-- Projectile (in-flight) light, read by LuaUI/Configs/DeferredLightsGL4WeaponsConfig.lua.
-- Cannons that fire a modelled shell (model = "projectile/...") get no engine glow sprite,
-- so give them one of these or the shell looks unlit. Match the color to the model name.
			light_color			= orange,
			light_opacity		= 0.2,  -- 0.1 for spam (flak fragments), 0.3 for big slow shells
			-- light_radius / light_radius_mult / light_mult / light_skip are also available
]]--