--[[   Morph Definition File

Morph parameters description
local morphDefs = {		--beginig of morphDefs
	unitname = {		--unit being morphed
		into      = 'newunitname', --unit in that will morphing unit morph into
		time      = 12,            --time required to complete morph process (in seconds)
		--require = 'requnitname', --unit requnitname must be present in team for morphing to be enabled
		energy    = 10,            --required metal for morphing process     note: if you ommit M and/or E costs, morph costs the
		energy    = 10,            --required energy for morphing process		difference in costs between unitname and newunitname
		xp        = 0.07,          --required experience for morphing process (will be deduced from unit xp after morph, default=0)
		rank      = 1,             --required unit rank for morphing to be enabled,                               if ommited, morph doesn't require rank
		tech = 2,			--required tech level of a team for morphing to be enabled (1,2,3), if ommited, morph doesn't require tech
		cmdname = 'Ascend',      --if ommited will default to "Upgrade"
		texture = 'MyIcon.dds',  --if ommited will default to [newunitname] buildpic,         textures should be in "LuaRules/Images/Morph"
		text    = 'Description', --if ommited will default to "Upgrade into a [newunitname]", else it's "Description"
						--you may use "$$unitname" and "$$into" in 'text', both will be replaced with human readable unit names 
	},
}				--end of morphDefs
--]]
--------------------------------------------------------------------------------


local devolution = (-1 > 0)

-- With this equation, you are deciding the time that it takes to morph and how much energy it will cost per second while morphing. Cost is a calculation of time and rate. Frankly this is the best way to keep things uniform.
-- energycost = time * rate
-- time       = energycost / rate

-- To figure up how much energy something should cost when converting metal to energy just remember
-- Tech0 = metal cost * 1.5
-- Tech1 = metal cost * 3
-- Tech2 = metal cost * 6
-- Tech3 = metal cost * 12

-- So using the above values, if a unit costs 80 metal and is tech1, then we can just do metal * 3 and then * 2. THe reason for the *2 is because we need to add the unit's energy cost to the converted metal cost. So (80 * 3) * 2 = 480. So our unit's energy cost is 480, we still need to calculate time to plug into our formula. That part is easy following the guide below: 

-- Tech1 rate   = 10
-- Tech2 rate   = 25
-- Tech3 rate   = 50
-- "Tech4" rate = 100

-- So following that guide, we can just do 480 / tech1 rate which is 10. 480 / 10 = 48. So our time and rate would be 48 * 10. EzPz. It's a little tough to get at first, but it keeps everything uniform and fluid.

--Fed Commander Upgrades

local energyCost_fedcommander_up1  = 60 * 50
local timeToBuild_fedcommander_up1 = energyCost_fedcommander_up1 / 50

local energyCost_fedcommander_up2  = 180 * 100
local timeToBuild_fedcommander_up2 = energyCost_fedcommander_up2 / 100

local energyCost_fedcommander_up3  = 300 * 200
local timeToBuild_fedcommander_up3 = energyCost_fedcommander_up3 / 200

local energyCost_fedcommander_up4  = 480 * 400
local timeToBuild_fedcommander_up4 = energyCost_fedcommander_up4 / 400

--Loz Commander Upgrades

local energyCost_lozcommander_up1  = 60 * 50
local timeToBuild_lozcommander_up1 = energyCost_lozcommander_up1 / 50

local energyCost_lozcommander_up2  = 180 * 100
local timeToBuild_lozcommander_up2 = energyCost_lozcommander_up2 / 100

local energyCost_lozcommander_up3  = 300 * 200
local timeToBuild_lozcommander_up3 = energyCost_lozcommander_up3 / 200

local energyCost_lozcommander_up4  = 480 * 400
local timeToBuild_lozcommander_up4 = energyCost_lozcommander_up4 / 400

--

--Fed Engineer Upgrades

local energyCost_fedengineer_up1  = 20 * 25
local timeToBuild_fedengineer_up1 = energyCost_fedengineer_up1 / 25

local energyCost_fedengineer_up2  = 40 * 50
local timeToBuild_fedengineer_up2 = energyCost_fedengineer_up2 / 50

local energyCost_fedengineer_up3  = 60 * 100
local timeToBuild_fedengineer_up3 = energyCost_fedengineer_up3 / 100

--

--Loz Engineer Upgrades

local energyCost_lozengineer_up1  = 20 * 25
local timeToBuild_lozengineer_up1 = energyCost_lozengineer_up1 / 25

local energyCost_lozengineer_up2  = 40 * 50
local timeToBuild_lozengineer_up2 = energyCost_lozengineer_up2 / 50

local energyCost_lozengineer_up3  = 60 * 100
local timeToBuild_lozengineer_up3 = energyCost_lozengineer_up3 / 100

--

local energyCost_metalextractor_up1  = 20 * 35
local timeToBuild_metalextractor_up1 = energyCost_metalextractor_up1 / 35

local energyCost_metalextractor_up2  = 40 * 75
local timeToBuild_metalextractor_up2 = energyCost_metalextractor_up2 / 75

local energyCost_metalextractor_up3  = 60 * 150
local timeToBuild_metalextractor_up3 = energyCost_metalextractor_up3 / 150

local morphDefs = {

--fedcommander

	fedcommander = {
		{
		into    = 'fedcommander_up1',
		time    = timeToBuild_fedcommander_up1,
		cmdname = [[Tech 1
Upgrade]],
		energy  = energyCost_fedcommander_up1,
		metal   = 0,
		text    = 'Upgrade to Tech 1 with upgraded weapons and armor',
		},
	},
	
	fedcommander_up1 = {
		{
		into    = 'fedcommander_up2',
		time    = timeToBuild_fedcommander_up2,
		cmdname = [[Tech 2
Upgrade]],
		energy  = energyCost_fedcommander_up2,
		metal   = 0,
		text    = 'Upgrade to Tech 2 with upgraded weapons and armor',
		require = [[tech1]],
		},
	},
		
	fedcommander_up2 = {
		{
		into    = 'fedcommander_up3',
		time    = timeToBuild_fedcommander_up3,
		cmdname = [[Tech 3
Upgrade]],
		energy  = energyCost_fedcommander_up3,
		metal   = 0,
		text    = 'Upgrade to Tech 3 with upgraded weapons and armor',
		require = [[tech2]],
		},
	},
		
	fedcommander_up3 = {
		{
		into    = 'fedcommander_up4',
		time    = timeToBuild_fedcommander_up4,
		cmdname = [[Tech 4
Upgrade]],
		energy  = energyCost_fedcommander_up4,
		metal   = 0,
		text    = 'Upgrade into a Tech 4 BattleMech with Devestating weapons and armor',
		require = [[tech3]],
		},
	},

--

--lozcommander

	lozcommander = {
		{
		into    = 'lozcommander_up1',
		time    = timeToBuild_lozcommander_up1,
		cmdname = [[Tech 1
Upgrade]],
		energy  = energyCost_lozcommander_up1,
		metal   = 0,
		text    = 'Upgrade to Tech 1 with upgraded weapons and armor',
		},
	},

	lozcommander_up1 = {
		{
		into    = 'lozcommander_up2',
		time    = timeToBuild_lozcommander_up2,
		cmdname = [[Tech 2
Upgrade]],
		energy  = energyCost_lozcommander_up2,
		metal   = 0,
		text    = 'Upgrade to Tech 2 with upgraded weapons and armor',
		require = [[tech1]],
		},
	},

	lozcommander_up2 = {
		{
		into    = 'lozcommander_up3',
		time    = timeToBuild_lozcommander_up3,
		cmdname = [[Tech 3
Upgrade]],
		energy  = energyCost_lozcommander_up3,
		metal   = 0,
		text    = 'Upgrade to Tech 3 with upgraded weapons and armor',
		require = [[tech2]],
		},
	},

	lozcommander_up3 = {
		{
		into    = 'lozcommander_up4',
		time    = timeToBuild_lozcommander_up4,
		cmdname = [[Tech 4
Upgrade]],
		energy  = energyCost_lozcommander_up4,
		metal   = 0,
		text    = 'Upgrade to a Tech 4 BattleMech with Devestating weapons and armor',
		require = [[tech3]],
		},
	},

--

	lozengineer = {
		{
		into    = 'lozengineer_up1',
		time    = timeToBuild_lozengineer_up1,
		cmdname = [[Tech 1
Upgrade]],
		energy  = energyCost_lozengineer_up1,
		metal   = 0,
		text    = 'Upgrade to Tech 1 Engineer',
		require = [[tech1]],
		},
	},

	lozengineer_up1 = {
		{
		into    = 'lozengineer_up2',
		time    = timeToBuild_lozengineer_up2,
		cmdname = [[Tech 2
Upgrade]],
		energy  = energyCost_lozengineer_up2,
		metal   = 0,
		text    = 'Upgrade to Tech 2 Engineer',
		require = [[tech2]],
		},
	},

	lozengineer_up2 = {
		{
		into    = 'lozengineer_up3',
		time    = timeToBuild_lozengineer_up3,
		cmdname = [[Tech 3
Upgrade]],
		energy  = energyCost_lozengineer_up3,
		metal   = 0,
		text    = 'Upgrade to Tech 3 Engineer',
		require = [[tech3]],
		},
	},


	fedengineer = {
		{
		into    = 'fedengineer_up1',
		time    = timeToBuild_fedengineer_up1,
		cmdname = [[Tech 1
Upgrade]],
		energy  = energyCost_fedengineer_up1,
		metal   = 0,
		text    = 'Upgrade to Tech 1 Engineer',
		require = [[tech1]],
		},
	},

	fedengineer_up1 = {
		{
		into    = 'fedengineer_up2',
		time    = timeToBuild_fedengineer_up2,
		cmdname = [[Tech 2
Upgrade]],
		energy  = energyCost_fedengineer_up2,
		metal   = 0,
		text    = 'Upgrade to Tech 2 Engineer',
		require = [[tech2]],
		},
	},

	fedengineer_up2 = {
		{
		into    = 'fedengineer_up3',
		time    = timeToBuild_fedengineer_up3,
		cmdname = [[Tech 3
Upgrade]],
		energy  = energyCost_fedengineer_up3,
		metal   = 0,
		text    = 'Upgrade to Tech 3 Engineer',
		require = [[tech3]],
		},
	},
	
----------------------------------------------------------
----------------------------------------------------------
--Economy
	
	metalextractor = 	{
		{
			into      = 'metalextractor_up1',
			--require = 'etech2',
			time      = timeToBuild_metalextractor_up1,
			cmdname   = [[Tech 1
			Upgrade]],
			energy    = energyCost_metalextractor_up1,
			metal     = 0,
			text      = [[x2 Metal Extraction rate]],
			require   = [[tech1]],
		},
	},
	metalextractor_up1 = 	{
		{
			into      = 'metalextractor_up2',
			--require = 'etech2',
			time      = timeToBuild_metalextractor_up2,
			cmdname   = [[Tech 2
			Upgrade]],
			energy    = energyCost_metalextractor_up2,
			metal     = 0,
			text      = [[x4 Metal Extraction rate]],
			require   = [[tech2]],
		},
	},
	metalextractor_up2 = 	{
		{
			into      = 'metalextractor_up3',
			--require = 'etech2',
			time      = timeToBuild_metalextractor_up3,
			cmdname   = [[Tech 3
			Upgrade]],
			energy    = energyCost_metalextractor_up3,
			metal     = 0,
			text      = [[x8 Metal Extraction rate]],
			require   = [[tech3]],
		},
	},
}

--
-- Here's an example of why active configuration
-- scripts are better then static TDF files...
--

--
-- devolution, babe  (useful for testing)
--
if (devolution) then
  local devoDefs = {}
  for src,data in pairs(morphDefs) do
    devoDefs[data.into] = { into = src, time = 10, energy = 1, energy = 1 }
  end
  for src,data in pairs(devoDefs) do
    morphDefs[src] = data
  end
end


return morphDefs

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
