return {
	["scannersweep"] = {
		scan = {
			alwaysvisible      = true,
			air                = true,
			class              = [[CBitmapMuzzleFlame]],
			count              = 1,
			ground             = true,
			underwater         = true,
			water              = true,
			properties = {
				colormap            = [[0.25 0.25 0.25 0.1   0.25 0.25 0.25 0.1   0.25 0.25 0.25 0.1   0.25 0.25 0.25 0.1   0 0 0 0]],
				dir                = [[0, 1, 0]],
				--gravity            = [[0.0, 0.1, 0.0]],
				frontoffset        = 0,
				fronttexture       = [[scannersweep]],
				length             = 40,
				sidetexture        = [[none]],
				size               = 820,
				sizegrowth         = 0,
				ttl                = 300,
				pos                = [[0, 3, 0]],
				rotParams          = [[0, -100,0]],
				drawOrder          = 0,
			},
		},
	}
}