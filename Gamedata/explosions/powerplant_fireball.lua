-- mex-fireball / powerplant-fireball (all sizes, all colors)
-- Programmatically generated: edit the tables below, not the output.

-- Per-color values. The only thing color changes is the burst texture.
-- Add/remove a color here and every type/size combo for it is emitted automatically.
local colors = {
	blue   = { tex = [[generated-burst-blue]]   },
	orange = { tex = [[generated-burst-orange]] },
	red    = { tex = [[generated-burst-red]]    },
	yellow = { tex = [[generated-burst-yellow]] },
	green  = { tex = [[generated-burst-green]]  },
	purple = { tex = [[generated-burst-purple]] },
}

-- Per-type, per-size scaling. `size` drives both particlesize (flame) and size (flare).
-- Each explosion type keeps its own numbers for the same size tier.
local types = {
	["mex-fireball"] = {
		small  = { size = 40  },
		medium = { size = 60  },
		large  = { size = 100 },
	},
	["powerplant-fireball"] = {
		small  = { size = 50  },
		medium = { size = 75  },
		large  = { size = 100 },
	},
}

-- s = size params, c = color params
local function makeExplosion(s, c)
	return {
		flame = {
			air        = true,
			class      = [[CSimpleParticleSystem]],
			count      = 1,
			ground     = true,
			underwater = true,
			properties = {
				airdrag             = 0.97,
				colormap            = [[0 0 0 0     1 1 1 1   0 0 0 0]],
				directional         = false,
				emitrot             = 0,
				emitrotspread       = 0,
				emitvector          = [[0,0,0]],
				gravity             = [[0,0,0]],
				numparticles        = [[1]],
				particlelife        = 64,
				particlelifespread  = 0,
				particlesize        = s.size,
				particlesizespread  = 0,
				particlespeed       = 0,
				particlespeedspread = 0,
				sizegrowth          = 0,
				sizemod             = 1,
				--rotParams           = [[-24 r48, -60 r120, -180 r360]],
				animParams          = [[8,4,16]], --[xTiles, yTiles, animLength in game frames]
				pos                 = [[0,4,0]],
				texture             = c.tex,
				drawOrder           = 0,
			},
		},

		flare = {
			air                = true,
			class              = [[CBitmapMuzzleFlame]],
			count              = 1,
			ground             = true,
			underwater         = true,
			water              = true,
			properties = {
				colormap            = [[0.5 0.5 0.5 0.1   0.5 0.5 0.5 0.1   0.5 0.5 0.5 0.1   0.5 0.5 0.5 0.1   0 0 0 0]],
				dir                = [[0, 1, 0]],
				--gravity            = [[0.0, 0.1, 0.0]],
				frontoffset        = 0,
				animParams          = [[8,4,16]], --[xTiles, yTiles, animLength in game frames]
				fronttexture       = c.tex,
				length             = 40,
				sidetexture        = [[none]],
				size               = s.size,
				sizegrowth         = 0,
				ttl                = 64,
				pos                = [[0, 0, 0]],
				--rotParams          = [[-10 r20, -20 r40, -180 r360]],
				drawOrder          = 0,
			},
		},
	}
end

-- Build and return the final table.
-- Keys stay identical to the old per-entry files: <type>-<size>-<color>
local result = {}
for typeName, sizeSet in pairs(types) do
	for sizeName, s in pairs(sizeSet) do
		for colorName, c in pairs(colors) do
			result[typeName .. "-" .. sizeName .. "-" .. colorName] = makeExplosion(s, c)
		end
	end
end
return result