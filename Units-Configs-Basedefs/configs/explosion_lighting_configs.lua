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
purple = [[0.50999999940395 0 0.68999999165535]]

--[[
-- These go in Weapons CustomParams
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
]]--