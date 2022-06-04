local partsList = {
	"compressedtanks",
	"laserturret",
	"medtankturret",
	"nanopylon",
	"techdodad",
	"wheels",
	"backpack",
	"cloakhalfmast",
	"engine",
	"factoryarm",
	"factorypower",
	"gun",
	"leg",
	"levelerarm",
	"missilelauncher",
	"riotgun",
	"techpylon",
	"wheelassembly",
	"wings",
}

local parts = {}

for i = 1,#partsList do
	local objectname= partsList[i]
	local featureDef	=	{
		name			            = partsList[i],
		description				    = [[random part of dead unit]],
		object				        = "parts/" .. partsList[i] .. ".s3o",
		footprintx				    = 1,
		footprintz				    = 1,
		height				        = 2,
		blocking				    = false,
		hitdensity				    = 0,
		reclaimtime					= 5,
		damage				        = 10000,
		reclaimable				    = true,
		autoreclaimable				= true,
		indestructible		        = false,
		smokeTime			        = 0,
		upright				        = false,
	--	nodrawundergray				= "1.0",

		customParams = {
			provide_cover = 0,
		},

	} 
	parts[objectname] = featureDef

end
return lowerkeys(parts) 