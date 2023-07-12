--------------------------------------------------------------------------------
-- These represent both the area of effect and the camerashake amount as well as the light effect on the ground and surrounding units
local smallExplosion = 200
local smallExplosionImpulseFactor = 0
local mediumExplosion = 400
local mediumExplosionImpulseFactor = 0
local largeExplosion = 600
local largeExplosionImpulseFactor = 0
local hugeExplosion = 1000
local hugeExplosionImpulseFactor = 0

local smallExplosionTTL = 60
local mediumExplosionTTL = 120
local largeExplosionTTL = 180
local hugeExplosionTTL = 240

-- colors
local red = [[1 0 0]]
local green = [[0 1 0]]
local blue = [[0 0 1]]
local orange = [[1 0.5 0]]
local white = [[1 1 1]]
local purple = [[0.2 0 1]]

unitDeaths = {

--BUILDING DEATHS--

--Orange

	smallBuildingExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericbuildingexplosion-small",
		cameraShake=smallExplosion,
		customparams = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},

	mediumBuildingExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericbuildingexplosion-medium",
		cameraShake=mediumExplosion,
		customparams = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
	largeBuildingExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-large",
		cameraShake=largeExplosion,
		customparams = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},

	hugeBuildingExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-huge",
		cameraShake=hugeExplosion,
		customparams = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= hugeExplosion, -- In Elmos
			expl_light_life		= hugeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
--blue

	smallBuildingExplosionGenericBlue = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericbuildingexplosion-small",
		cameraShake=smallExplosion,
		customparams = {
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},

	mediumBuildingExplosionGenericBlue = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericbuildingexplosion-medium",
		cameraShake=mediumExplosion,
		customparams = {
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
	largeBuildingExplosionGenericBlue = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-large",
		cameraShake=largeExplosion,
		customparams = {
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},

	hugeBuildingExplosionGenericBlue = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-huge",
		cameraShake=hugeExplosion,
		customparams = {
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= hugeExplosion, -- In Elmos
			expl_light_life		= hugeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
--blue-emp

	smallBuildingExplosionGenericBlueEMP = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericbuildingexplosion-small",
		cameraShake=smallExplosion,
		customparams = {
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},

	mediumBuildingExplosionGenericBlueEMP = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericbuildingexplosion-medium",
		cameraShake=mediumExplosion,
		customparams = {
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
	largeBuildingExplosionGenericBlueEMP = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-large",
		cameraShake=largeExplosion,
		customparams = {
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},

	hugeBuildingExplosionGenericBlueEMP = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-huge",
		cameraShake=hugeExplosion,
		customparams = {
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= hugeExplosion, -- In Elmos
			expl_light_life		= hugeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
--green

	smallBuildingExplosionGenericGreen = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericbuildingexplosion-small",
		cameraShake=smallExplosion,
		customparams = {
			expl_light_color	= green, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},

	mediumBuildingExplosionGenericGreen = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericbuildingexplosion-medium",
		cameraShake=mediumExplosion,
		customparams = {
			expl_light_color	= green, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
	largeBuildingExplosionGenericGreen = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-large",
		cameraShake=largeExplosion,
		customparams = {
			expl_light_color	= green, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},

	hugeBuildingExplosionGenericGreen = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-huge",
		cameraShake=hugeExplosion,
		customparams = {
			expl_light_color	= green, -- As a string, RGB
			expl_light_radius	= hugeExplosion, -- In Elmos
			expl_light_life		= hugeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},

--purple

	smallBuildingExplosionGenericPurple = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericbuildingexplosion-small",
		cameraShake=smallExplosion,
		customparams = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},

	mediumBuildingExplosionGenericPurple = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericbuildingexplosion-medium",
		cameraShake=mediumExplosion,
		customparams = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
	largeBuildingExplosionGenericPurple = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-large",
		cameraShake=largeExplosion,
		customparams = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},

	hugeBuildingExplosionGenericPurple = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-huge",
		cameraShake=hugeExplosion,
		customparams = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= hugeExplosion, -- In Elmos
			expl_light_life		= hugeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
--red

	smallBuildingExplosionGenericRed = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericbuildingexplosion-small",
		cameraShake=smallExplosion,
		customparams = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},

	mediumBuildingExplosionGenericRed = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericbuildingexplosion-medium",
		cameraShake=mediumExplosion,
		customparams = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
	largeBuildingExplosionGenericRed = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-large",
		cameraShake=largeExplosion,
		customparams = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},

	hugeBuildingExplosionGenericRed = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-huge",
		cameraShake=hugeExplosion,
		customparams = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= hugeExplosion, -- In Elmos
			expl_light_life		= hugeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
--white

	smallBuildingExplosionGenericWhite = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericbuildingexplosion-small",
		cameraShake=smallExplosion,
		customparams = {
			expl_light_color	= white, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},

	mediumBuildingExplosionGenericWhite = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericbuildingexplosion-medium",
		cameraShake=mediumExplosion,
		customparams = {
			expl_light_color	= white, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
	largeBuildingExplosionGenericWhite = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-large",
		cameraShake=largeExplosion,
		customparams = {
			expl_light_color	= white, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},

	hugeBuildingExplosionGenericWhite = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-huge",
		cameraShake=hugeExplosion,
		customparams = {
			expl_light_color	= white, -- As a string, RGB
			expl_light_radius	= hugeExplosion, -- In Elmos
			expl_light_life		= hugeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
	
--UNIT DEATHS--

--Orange

	smallExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericunitexplosion-small",
		cameraShake=smallExplosion,
		customparams = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},

	mediumExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericunitexplosion-medium",
		cameraShake=mediumExplosion,
		customparams = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
	largeExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:nukedatbewmsmaller",
		cameraShake=largeExplosion,
		customparams = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
	hugeExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:nukedatbewmsmall",
		cameraShake=hugeExplosion,
		customparams = {
			expl_light_color	= orange, -- As a string, RGB
			expl_light_radius	= hugeExplosion, -- In Elmos
			expl_light_life		= hugeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},

	--byar
	bar_tinyExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:bar-genericunitexplosion-tiny",
		cameraShake=smallExplosion,
		damage = {
			default            = 0,
		},
	},

	bar_smallExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:bar-genericunitexplosion-small",
		cameraShake=smallExplosion,
		damage = {
			default            = 0,
		},
	},

	bar_mediumExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:bar-genericunitexplosion-medium",
		cameraShake=mediumExplosion,
		damage = {
			default            = 0,
		},
	},
	
	bar_largeExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:bar-genericunitexplosion-large",
		cameraShake=largeExplosion,
		damage = {
			default            = 0,
		},
	},
	
	bar_hugeExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:bar-genericunitexplosion-huge",
		cameraShake=hugeExplosion,
		damage = {
			default            = 0,
		},
	},
	bar_giganticExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:bar-genericunitexplosion-gigantic",
		cameraShake=hugeExplosion,
		damage = {
			default            = 0,
		},
	},
	
--Blue

	smallExplosionGenericBlue = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericunitexplosion-small",
		cameraShake=smallExplosion,
		customparams = {
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},

	mediumExplosionGenericBlue = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericunitexplosion-medium",
		cameraShake=mediumExplosion,
		customparams = {
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
	largeExplosionGenericBlue = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:nukedatbewmsmaller",
		cameraShake=largeExplosion,
		customparams = {
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
	hugeExplosionGenericBlue = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:nukedatbewmsmall",
		cameraShake=hugeExplosion,
		customparams = {
			expl_light_color	= blue, -- As a string, RGB
			expl_light_radius	= hugeExplosion, -- In Elmos
			expl_light_life		= hugeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
--Green

	smallExplosionGenericGreen = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericunitexplosion-small",
		cameraShake=smallExplosion,
		customparams = {
			expl_light_color	= green, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},

	mediumExplosionGenericGreen = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericunitexplosion-medium",
		cameraShake=mediumExplosion,
		customparams = {
			expl_light_color	= green, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
	largeExplosionGenericGreen = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:nukedatbewmsmaller",
		cameraShake=largeExplosion,
		customparams = {
			expl_light_color	= green, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
	hugeExplosionGenericGreen = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:nukedatbewmsmall",
		cameraShake=hugeExplosion,
		customparams = {
			expl_light_color	= green, -- As a string, RGB
			expl_light_radius	= hugeExplosion, -- In Elmos
			expl_light_life		= hugeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
--Purple

	smallExplosionGenericPurple = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericunitexplosion-small",
		cameraShake=smallExplosion,
		customparams = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},

	mediumExplosionGenericPurple = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericunitexplosion-medium",
		cameraShake=mediumExplosion,
		customparams = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
	largeExplosionGenericPurple = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:nukedatbewmsmaller",
		cameraShake=largeExplosion,
		customparams = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
	hugeExplosionGenericPurple = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:nukedatbewmsmall",
		cameraShake=hugeExplosion,
		customparams = {
			expl_light_color	= purple, -- As a string, RGB
			expl_light_radius	= hugeExplosion, -- In Elmos
			expl_light_life		= hugeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
	
--Red

	smallExplosionGenericRed = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosionGenerator="custom:genericunitexplosion-small",
		cameraShake=smallExplosion,
		customparams = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},

	mediumExplosionGenericRed = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericunitexplosion-medium",
		cameraShake=mediumExplosion,
		customparams = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
	largeExplosionGenericRed = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:nukedatbewmsmaller",
		cameraShake=largeExplosion,
		customparams = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
	hugeExplosionGenericRed = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:nukedatbewmsmall",
		cameraShake=hugeExplosion,
		customparams = {
			expl_light_color	= red, -- As a string, RGB
			expl_light_radius	= hugeExplosion, -- In Elmos
			expl_light_life		= hugeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
	
--White

	smallExplosionGenericWhite = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericunitexplosion-small",
		cameraShake=smallExplosion,
		customparams = {
			expl_light_color	= white, -- As a string, RGB
			expl_light_radius	= smallExplosion, -- In Elmos
			expl_light_life		= smallExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},

	mediumExplosionGenericWhite = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericunitexplosion-medium",
		cameraShake=mediumExplosion,
		customparams = {
			expl_light_color	= white, -- As a string, RGB
			expl_light_radius	= mediumExplosion, -- In Elmos
			expl_light_life		= mediumExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
	largeExplosionGenericWhite = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:nukedatbewmsmaller",
		cameraShake=largeExplosion,
		customparams = {
			expl_light_color	= white, -- As a string, RGB
			expl_light_radius	= largeExplosion, -- In Elmos
			expl_light_life		= largeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
	
	hugeExplosionGenericWhite = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:nukedatbewmsmall",
		cameraShake=hugeExplosion,
		customparams = {
			expl_light_color	= white, -- As a string, RGB
			expl_light_radius	= hugeExplosion, -- In Elmos
			expl_light_life		= hugeExplosionTTL, -- In frames I.E. 30 frames = 1 second
		},
		damage = {
			default            = 0,
		},
	},
}

return lowerkeys(unitDeaths)
