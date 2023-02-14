return {
	["generated-anim"] = {
		flame = {
			air        = true,
			class      = [[CSimpleParticleSystem]],
			count      = 1,
			ground     = true,
			properties = {
				airdrag             = 0.97,
				colormap            = [[0.5 0 0 0.01  0.8 0.5 0 0.01	0 0 0 0.01]],
				directional         = false,
				emitrot             = 70,
				emitrotspread       = 40,
				emitvector          = [[0,0,0]],
				gravity             = [[0,0,0]],
				numparticles        = [[1]],
				particlelife        = 40,
				particlelifespread  = 0,
				particlesize        = 10,
				particlesizespread  = 1,
				particlespeed       = 0,
				particlespeedspread = 0,
				rotParams           = [[-24 r48, -60 r120, -180 r360]],
				animParams          = [[4,4,40]], --[xTiles, yTiles, animLength in game frames]
				pos                 = [[0,0,0]],
				sizegrowth          = 0,
				sizemod             = 1,
				texture             = [[generated-fireball]],
				drawOrder           = 0,
				-- castshadow          = true,
			},

		},
	},
}