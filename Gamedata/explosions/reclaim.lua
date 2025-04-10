-- genericshellexplosion-small
-- genericshellexplosion
-- genericshellexplosion-medium
-- genericshellexplosion-large

return {
	["reclaim"] = {
		explosionspikes = {
			air                = true,
			class              = [[explspike]],
			count              = 7,
			ground             = true,
			water              = true,
			properties = {
				alpha              = 1,
				alphadecay         = 0.19,
				alwaysvisible      = false,
				color              = [[0.1, 0.6, 0.1]],
				dir                = [[-45 r90,-45 r90,-45 r90]],
				length             = 0.2,
				width              = 4,
			},
		},
		poof01 = {
			air                = true,
			class              = [[CSimpleParticleSystem]],
			count              = 1,
			ground             = true,
			properties = {
				airdrag            = 0.2,
				alwaysvisible      = false,
				colormap           = [[1.0 1.0 1.0 0.04	0.5 1.0 0.5 0.01	0.1 0.1 0.1 0.01]],
				directional        = false,
				emitrot            = 45,
				emitrotspread      = 32,
				emitvector         = [[0, 1, 0]],
				gravity            = [[0, 0.5, 0]],
				numparticles       = 8,
				particlelife       = 5,
				particlelifespread = 16,
				particlesize       = 20,
				particlesizespread = 0,
				particlespeed      = 16,
				particlespeedspread = 1,
				pos                = [[0, 2, 0]],
				sizegrowth         = 0.8,
				sizemod            = 1.0,
				texture            = [[randomdots]],
				useairlos          = false,
			},
		},
		pop1 = {
			air                = true,
			class              = [[heatcloud]],
			count              = 1,
			ground             = true,
			water              = true,
			properties = {
				alwaysvisible      = false,
				heat               = 10,
				heatfalloff        = 1.8,
				maxheat            = 10,
				pos                = [[r-2 r2, 5, r-2 r2]],
				size               = 1,
				sizegrowth         = 16,
				speed              = [[0, 0, 0]],
				texture            = [[greennovaexplo]],
			},
		},
	},

}

