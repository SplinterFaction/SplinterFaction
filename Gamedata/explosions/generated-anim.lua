return {
	["generated-anim"] = {
		flame = {
			air        = true,
			class      = [[CSimpleParticleSystem]],
			count      = 1,
			ground     = true,
			properties = {
				airdrag             = 0.97,
				colormap            = [[0.4 0.2 0.5 0.9   0.5 0.2 0.6 1  0.8 0.7 0.55 0.88   0.22 0.13 0.1 0.066   0.023 0.022 0.022 0.025   0 0 0 0.01]],
				directional         = false,
				emitrot             = 70,
				emitrotspread       = 40,
				emitvector          = [[0,0,0]],
				gravity             = [[0,0.25,0]],
				numparticles        = [[1]],
				particlelife        = 20,
				particlelifespread  = 9,
				particlesize        = 18.4,
				particlesizespread  = 18.8,
				particlespeed       = 0.3,
				particlespeedspread = 0.6,
				rotParams           = [[-24 r48, -60 r120, -180 r360]],
				animParams          = [[4,4,20]], --[xTiles, yTiles, animLength in game frames]
				pos                 = [[0,0,0]],
				sizegrowth          = 0.5,
				sizemod             = 1,
				texture             = [[generated-anim3]],
				drawOrder           = 0,
				castShadow          = true,
			},

		},
	},
}