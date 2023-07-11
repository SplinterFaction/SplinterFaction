local featureDef	=	{
	name				= "metal",
	blocking			= false,
	category			= "Metal Deposit",
	damage				= 100000,
	description			= "A Mineable Metal Deposit",


  energy = 0,
-- energy				= 20,
	flammable			= 0,
	footprintX			= 2,
	footprintZ			= 2,
	metal = 0,
--metal				= 0,
	object				= "features/smoth/metal.s3o",
	reclaimable			= false,
	autoreclaimable		= false, 	
	indestructible		= true,	
	world				= "All Worlds",
	customparams = { 
		 author 	 = "Smoth",
		 category 	 = "Metal Deposit",
		 set 		 = "Smoth Assets",
 
		randomrotate		= "true", 
	}, 
}
return lowerkeys({[featureDef.name] = featureDef})