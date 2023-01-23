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
	"randomdeadtank1",
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
		damage				        = 100,
		reclaimable				    = true,
		autoreclaimable				= true,
		indestructible		        = true,
		smokeTime			        = 0,
		upright				        = true, -- This MUST be set to true. Spring has a bug and without this set to true, spring will refuse to set direction OR rotate around the x and z axes. Direction and rotation will not work on any engine version prior to BAR engine version 1499.
	--	nodrawundergray				= "1.0",

		customParams = {
			provide_cover = 0,
		},

	} 
	parts[objectname] = featureDef

end
return lowerkeys(parts) 