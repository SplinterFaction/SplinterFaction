return {
	["napalm"] = {
		useDefaultExplosions = false,
		fireball = {
			class      = [[CSimpleParticleSystem]],
			count      = 1,
			air        = true,
			ground     = true,
			water      = true,
			underwater = true,
			properties = {
				airdrag             = 0.87,
				colormap            = [[1 1 1 0.1   1 1 1 0.1   1 1 1 0.1   1 1 1 0.1   0 0 0 0   0 0 0 0]],
				directional        = false,
				emitrot            = 0,
				emitrotspread      = 0,
				emitvector         = [[0, 0, 0]],
				gravity            = [[0, 0.1, 0]],
				numparticles       = 1,
				particlelife       = 150,
				particlelifespread = 30,
				particlesize       = 120,
				particlesizespread = 1,
				particlespeed      = 2,
				particlespeedspread = 6,
				pos                = [[0, 1, 0]],
				rotParams           = [[1, 1, 1]],
				animParams          = [[6,6,60]], --[xTiles, yTiles, animLength in game frames]
				sizegrowth          = 0.1,
				sizemod             = 1,
				texture             = [[generated-furnace]],
				drawOrder           = 0,
			},
		},
	},
}

