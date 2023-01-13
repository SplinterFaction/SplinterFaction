return {
	["generated-anim"] = {
		flame = {
			air        = true,
			class      = [[CSimpleParticleSystem]],
			count      = 1,
			ground     = true,
			properties = {
				airdrag             = 0.97,
				colormap            = [[0.8 0.78 0.6 0.9   1.0 0.97 0.7 1  0.8 0.7 0.55 0.88   0.22 0.13 0.1 0.66   0.023 0.022 0.022 0.25   0 0 0 0.01]],
				directional         = false,
				emitrot             = 70,
				emitrotspread       = 40,
				emitvector          = [[0.3, 0.7, 0.3]],
				gravity             = [[0, 0.06 r0.05, 0]],
				numparticles        = [[0.49 r0.60]],
				particlelife        = 24,
				particlelifespread  = 9,
				particlesize        = 18.4,
				particlesizespread  = 18.8,
				particlespeed       = 0.3,
				particlespeedspread = 0.6,
				rotParams           = [[-24 r48, -60 r120, -180 r360]],
				animParams          = [[8,8,40 r120]], --[xTiles, yTiles, animLength in game frames]
				pos                 = [[-2 r4, 32 r8, -2 r4]],
				sizegrowth          = [[1.7 r1.9]],
				sizemod             = 0.93,
				texture             = [[generated-anim]],
				drawOrder           = 0,
				castShadow          = true,
			},
		},
	},
}