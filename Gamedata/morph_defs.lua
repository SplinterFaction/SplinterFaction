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

local morphDefs = {

--fedcommander

	fedcommander = {
		{
		into    = 'fedcommander_up1',
		time    = 30,
		cmdname = [[Tech 1]] .. string.char(10) .. [[Upgrade]],
		-- energy  = energyCost_fedcommander_up1,
		-- metal   = 0,
		text    = 'Upgrade to Tech 1 with upgraded weapons and armor',
		},
	},
	
	fedcommander_up1 = {
		{
		into    = 'fedcommander_up2',
		time    = 60,
		cmdname = [[Tech 2]] .. string.char(10) .. [[Upgrade]],
		-- energy  = energyCost_fedcommander_up2,
		-- metal   = 0,
		text    = 'Upgrade to Tech 2 with upgraded weapons and armor',
		require = [[tech1]],
		},
	},
		
	fedcommander_up2 = {
		{
		into    = 'fedcommander_up3',
		time    = 120,
		cmdname = [[Tech 3]] .. string.char(10) .. [[Upgrade]],
		-- energy  = energyCost_fedcommander_up3,
		-- metal   = 0,
		text    = 'Upgrade to Tech 3 with upgraded weapons and armor',
		require = [[tech2]],
		},
	},
		
	fedcommander_up3 = {
		{
		into    = 'fedcommander_up4',
		time    = 300,
		cmdname = [[Tech 4]] .. string.char(10) .. [[Upgrade]],
		-- energy  = energyCost_fedcommander_up4,
		-- metal   = 0,
		text    = 'Upgrade into a Tech 4 BattleMech with Devestating weapons and armor',
		require = [[tech3]],
		},
	},

--

--lozcommander

	lozcommander = {
		{
		into    = 'lozcommander_up1',
		time    = 30,
		cmdname = [[Tech 1]] .. string.char(10) .. [[Upgrade]],
		-- energy  = energyCost_lozcommander_up1,
		-- metal   = 450, -- Assuming metal drain of 15/s
		text    = 'Upgrade to Tech 1 with upgraded weapons and armor',
		},
	},

	lozcommander_up1 = {
		{
		into    = 'lozcommander_up2',
		time    = 60,
		cmdname = [[Tech 2]] .. string.char(10) .. [[Upgrade]],
		-- energy  = energyCost_lozcommander_up2,
		-- metal   = 1200, -- Assuming metal drain of 20/s
		text    = 'Upgrade to Tech 2 with upgraded weapons and armor',
		require = [[tech1]],
		},
	},

	lozcommander_up2 = {
		{
		into    = 'lozcommander_up3',
		time    = 120,
		cmdname = [[Tech 3]] .. string.char(10) .. [[Upgrade]],
		-- energy  = energyCost_lozcommander_up3,
		-- metal   = 3000, -- Assuming metal drain of 25/s
		text    = 'Upgrade to Tech 3 with upgraded weapons and armor',
		require = [[tech2]],
		},
	},

	lozcommander_up3 = {
		{
		into    = 'lozcommander_up4',
		time    = 300,
		cmdname = [[Tech 4]] .. string.char(10) .. [[Upgrade]],
		-- energy  = energyCost_lozcommander_up4,
		-- metal   = 9000, -- Assuming metal drain of 30/s
		text    = 'Upgrade to a Tech 4 BattleMech with Devestating weapons and armor',
		require = [[tech3]],
		},
	},

--

	lozengineer = {
		{
		into    = 'lozengineer_up1',
		time    = timeToBuild_lozengineer_up1,
		cmdname = [[Tech 1]] .. string.char(10) .. [[Upgrade]],
		energy  = energyCost_lozengineer_up1,
		metal   = 0,
		text    = 'Upgrade to Tech 1 Engineer',
		require = [[tech1]],
		},
	},

--	lozengineer_up1 = {
--		{
--		into    = 'lozengineer_up2',
--		time    = timeToBuild_lozengineer_up2,
--		cmdname = [[Tech 2]] .. string.char(10) .. [[Upgrade]],
--		energy  = energyCost_lozengineer_up2,
--		metal   = 0,
--		text    = 'Upgrade to Tech 2 Engineer',
--		require = [[tech2]],
--		},
--	},

	lozengineer_up2 = {
		{
		into    = 'lozengineer_up3',
		time    = timeToBuild_lozengineer_up3,
		cmdname = [[Tech 3]] .. string.char(10) .. [[Upgrade]],
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
		cmdname = [[Tech 1]] .. string.char(10) .. [[Upgrade]],
		energy  = energyCost_fedengineer_up1,
		metal   = 0,
		text    = 'Upgrade to Tech 1 Engineer',
		require = [[tech1]],
		},
	},

--	fedengineer_up1 = {
--		{
--		into    = 'fedengineer_up2',
--		time    = timeToBuild_fedengineer_up2,
--		cmdname = [[Tech 2]] .. string.char(10) .. [[Upgrade]],
--		energy  = energyCost_fedengineer_up2,
--		metal   = 0,
--		text    = 'Upgrade to Tech 2 Engineer',
--		require = [[tech2]],
--		},
--	},

	fedengineer_up2 = {
		{
		into    = 'fedengineer_up3',
		time    = timeToBuild_fedengineer_up3,
		cmdname = [[Tech 3]] .. string.char(10) .. [[Upgrade]],
		energy  = energyCost_fedengineer_up3,
		metal   = 0,
		text    = 'Upgrade to Tech 3 Engineer',
		require = [[tech3]],
		},
	},
	
----------------------------------------------------------
----------------------------------------------------------
--Economy

	----------------------------------------------------------
	---Fed Metal Extractors
	----------------------------------------------------------
	
	fedmetalextractor = 	{
		{
			into      = 'fedmetalextractor_up1',
			--require = 'etech2',
			time      = 15,
			cmdname   = [[Tech 1]],
			-- energy    = energyCost_metalextractor_up1,
			-- metal     = 0,
			text      = [[Upgrade to Tech 1, x2 Metal Extraction rate]],
			require   = [[tech1]],
		},
		{
			into      = 'fedmetalextractor_stripmine_up1',
			--require = 'etech2',
			time      = 15,
			cmdname   = [[Tech 1]] .. string.char(10) .. [[Stripmine]],
			-- energy    = energyCost_metalextractor_up1,
			-- metal     = 0,
			text      = [[Upgrade to Tech 1 Stripmining, x2 + 50% Metal Extraction rate]],
			require   = [[tech1]],
		},
		{
			into      = 'fedmetalextractor_cloak_up1',
			--require = 'etech2',
			time      = 30,
			cmdname   = [[Tech 1]] .. string.char(10) .. [[Cloak]],
			-- energy    = energyCost_metalextractor_up1,
			-- metal     = 0,
			text      = [[Upgrade to Tech 1 with Area Cloak]],
			require   = [[tech1]],
		},
	},
	fedmetalextractor_up1 = 	{
		{
			into      = 'fedmetalextractor_up2',
			--require = 'etech2',
			time      = 30,
			cmdname   = [[Tech 2]],
			-- energy    = energyCost_metalextractor_up2,
			-- metal     = 0,
			text      = [[Upgrade to Tech 2, x4 Metal Extraction rate]],
			require   = [[tech2]],
		},
		{
			into      = 'fedmetalextractor_stripmine_up2',
			--require = 'etech2',
			time      = 30,
			cmdname   = [[Tech 2]] .. string.char(10) .. [[Stripmine]],
			-- energy    = energyCost_metalextractor_up1,
			-- metal     = 0,
			text      = [[Upgrade to Tech 2 Stripmining, x4 + 50% Metal Extraction rate]],
			require   = [[tech2]],
		},
		{
			into      = 'fedmetalextractor_cloak_up2',
			--require = 'etech2',
			time      = 60,
			cmdname   = [[Tech 2]] .. string.char(10) .. [[Cloak]],
			-- energy    = energyCost_metalextractor_up1,
			-- metal     = 0,
			text      = [[Upgrade to Tech 2 with Area Cloak]],
			require   = [[tech2]],
		},
	},
	fedmetalextractor_up2 = 	{
		{
			into      = 'fedmetalextractor_up3',
			--require = 'etech2',
			time      = 60,
			cmdname   = [[Tech 3]],
			-- energy    = energyCost_metalextractor_up3,
			-- metal     = 0,
			text      = [[Upgrade to Tech 3, x8 Metal Extraction rate]],
			require   = [[tech3]],
		},
		{
			into      = 'fedmetalextractor_stripmine_up3',
			--require = 'etech2',
			time      = 60,
			cmdname   = [[Tech 3]] .. string.char(10) .. [[Stripmine]],
			-- energy    = energyCost_metalextractor_up1,
			-- metal     = 0,
			text      = [[Upgrade to Tech 3 Stripmining, x8 + 50% Metal Extraction rate]],
			require   = [[tech3]],
		},
		{
			into      = 'fedmetalextractor_cloak_up3',
			--require = 'etech2',
			time      = 120,
			cmdname   = [[Tech 3]] .. string.char(10) .. [[Cloak]],
			-- energy    = energyCost_metalextractor_up1,
			-- metal     = 0,
			text      = [[Upgrade to Tech 3 with Area Cloak]],
			require   = [[tech3]],
		},
	},

	---Fed Specialty Metal Extractors

	fedmetalextractor_stripmine_up1 = 	{
		{
			into      = 'fedmetalextractor_stripmine_up2',
			--require = 'etech2',
			time      = 15,
			cmdname   = [[Tech 2]] .. string.char(10) .. [[Stripmine]],
			-- energy    = energyCost_metalextractor_up1,
			-- metal     = 0,
			text      = [[Upgrade to Tech 2 Stripmining, x4 + 50% Metal Extraction rate]],
			require   = [[tech2]],
		},
	},
	fedmetalextractor_stripmine_up2 = 	{
		{
			into      = 'fedmetalextractor_stripmine_up3',
			--require = 'etech2',
			time      = 15,
			cmdname   = [[Tech 3]] .. string.char(10) .. [[Stripmine]],
			-- energy    = energyCost_metalextractor_up1,
			-- metal     = 0,
			text      = [[Upgrade to Tech 3 Stripmining, x8 + 50% Metal Extraction rate]],
			require   = [[tech3]],
		},
	},
	fedmetalextractor_cloak_up1 = 	{
		{
			into      = 'fedmetalextractor_cloak_up2',
			--require = 'etech2',
			time      = 60,
			cmdname   = [[Tech 2]] .. string.char(10) .. [[Cloak]],
			-- energy    = energyCost_metalextractor_up1,
			-- metal     = 0,
			text      = [[Upgrade to Tech 2 with Area Cloak]],
			require   = [[tech2]],
		},
	},
	fedmetalextractor_cloak_up2 = 	{
		{
			into      = 'fedmetalextractor_cloak_up3',
			--require = 'etech2',
			time      = 120,
			cmdname   = [[Tech 3]] .. string.char(10) .. [[Cloak]],
			-- energy    = energyCost_metalextractor_up1,
			-- metal     = 0,
			text      = [[Upgrade to Tech 3 with Area Cloak]],
			require   = [[tech3]],
		},
	},



	----------------------------------------------------------
	---Loz Metal Extractors
	----------------------------------------------------------
	lozmetalextractor = 	{
		{
			into      = 'lozmetalextractor_up1',
			--require = 'etech2',
			time      = 15,
			cmdname   = [[Tech 1]],
			-- energy    = energyCost_metalextractor_up1,
			-- metal     = 0,
			text      = [[Upgrade to Tech 1, x2 Metal Extraction rate]],
			require   = [[tech1]],
		},
		{
			into      = 'lozmetalextractor_armed_up1',
			--require = 'etech2',
			time      = 60,
			cmdname   = [[Tech 1]] .. string.char(10) .. [[Armed]],
			-- energy    = energyCost_metalextractor_up1,
			-- metal     = 0,
			text      = [[Upgrade to Tech 1, x2 Metal Extraction rate with 2 Gamma Ray Turrets]],
			require   = [[tech1]],
		},
		{
			into      = 'lozmetalextractor_shield_up1',
			--require = 'etech2',
			time      = 60,
			cmdname   = [[Tech 1]] .. string.char(10) .. [[Shielded]],
			-- energy    = energyCost_metalextractor_up1,
			-- metal     = 0,
			text      = [[Upgrade to Tech 1, x2 Metal Extraction rate with an Area Shield]],
			require   = [[tech1]],
		},
	},
	lozmetalextractor_up1 = 	{
		{
			into      = 'lozmetalextractor_up2',
			--require = 'etech2',
			time      = 30,
			cmdname   = [[Tech 2]],
			-- energy    = energyCost_metalextractor_up2,
			-- metal     = 0,
			text      = [[Upgrade to Tech 2, x4 Metal Extraction rate]],
			require   = [[tech2]],
		},
		{
			into      = 'lozmetalextractor_armed_up2',
			--require = 'etech2',
			time      = 90,
			cmdname   = [[Tech 2]] .. string.char(10) .. [[Armed]],
			-- energy    = energyCost_metalextractor_up1,
			-- metal     = 0,
			text      = [[Upgrade to Tech 2, x4 Metal Extraction rate with 2 Gamma Ray Turrets and 1 Neutron Beam Turret]],
			require   = [[tech2]],
		},
		{
			into      = 'lozmetalextractor_shield_up2',
			--require = 'etech2',
			time      = 90,
			cmdname   = [[Tech 2]] .. string.char(10) .. [[Shielded]],
			-- energy    = energyCost_metalextractor_up1,
			-- metal     = 0,
			text      = [[Upgrade to Tech 2, x4 Metal Extraction rate with an Area Shield]],
			require   = [[tech2]],
		},
	},
	lozmetalextractor_up2 = 	{
		{
			into      = 'lozmetalextractor_up3',
			--require = 'etech2',
			time      = 60,
			cmdname   = [[Tech 3]],
			-- energy    = energyCost_metalextractor_up3,
			-- metal     = 0,
			text      = [[Upgrade to Tech 3, x8 Metal Extraction rate]],
			require   = [[tech3]],
		},
		{
			into      = 'lozmetalextractor_armed_up3',
			--require = 'etech2',
			time      = 150,
			cmdname   = [[Tech 3]] .. string.char(10) .. [[Armed]],
			-- energy    = energyCost_metalextractor_up1,
			-- metal     = 0,
			text      = [[Upgrade to Tech 3, x8 Metal Extraction rate with 2 Gamma Ray Turrets and 2 Neutron Beam Turrets]],
			require   = [[tech3]],
		},
		{
			into      = 'lozmetalextractor_shield_up3',
			--require = 'etech2',
			time      = 150,
			cmdname   = [[Tech 3]] .. string.char(10) .. [[Shielded]],
			-- energy    = energyCost_metalextractor_up1,
			-- metal     = 0,
			text      = [[Upgrade to Tech 3, x8 Metal Extraction rate with an Area Shield]],
			require   = [[tech3]],
		},
	},


	---loz Specialty Metal Extractors
	lozmetalextractor_armed_up1 = 	{
		{
			into      = 'lozmetalextractor_armed_up2',
			--require = 'etech2',
			time      = 90,
			cmdname   = [[Tech 2]] .. string.char(10) .. [[Armed]],
			-- energy    = energyCost_metalextractor_up1,
			-- metal     = 0,
			text      = [[Upgrade to Tech 2, x4 Metal Extraction rate with 2 Gamma Ray Turrets and 1 Neutron Beam Turret]],
			require   = [[tech2]],
		},
	},
	lozmetalextractor_armed_up2 = 	{
		{
			into      = 'lozmetalextractor_armed_up3',
			--require = 'etech2',
			time      = 150,
			cmdname   = [[Tech 3]] .. string.char(10) .. [[Armed]],
			-- energy    = energyCost_metalextractor_up1,
			-- metal     = 0,
			text      = [[Upgrade to Tech 3, x8 Metal Extraction rate with 2 Gamma Ray Turrets and 2 Neutron Beam Turrets]],
			require   = [[tech3]],
		},
	},
	lozmetalextractor_shield_up1 = 	{

		{
			into      = 'lozmetalextractor_shield_up2',
			--require = 'etech2',
			time      = 90,
			cmdname   = [[Tech 2]] .. string.char(10) .. [[Shielded]],
			-- energy    = energyCost_metalextractor_up1,
			-- metal     = 0,
			text      = [[Upgrade to Tech 2, x4 Metal Extraction rate with an Area Shield]],
			require   = [[tech2]],
		},
	},
	lozmetalextractor_shield_up2 = 	{
		{
			into      = 'lozmetalextractor_shield_up3',
			--require = 'etech2',
			time      = 150,
			cmdname   = [[Tech 3]] .. string.char(10) .. [[Shielded]],
			-- energy    = energyCost_metalextractor_up1,
			-- metal     = 0,
			text      = [[Upgrade to Tech 3, x8 Metal Extraction rate with an Area Shield]],
			require   = [[tech3]],
		},
	},


	----------------------------------------------------------
	---GeoStubs
	----------------------------------------------------------

	fedgeostub = 	{
		{
			into      = 'fedguardian',
			--require = 'etech2',
			time      = 180,
			cmdname   = [[Guardian]],
			text      = [[Guardian Defense Turret]],
			require   = [[tech3]],
		},
	},

	lozgeostub = 	{
		{
			into      = 'lozannihilator',
			--require = 'etech2',
			time      = 180,
			cmdname   = [[Annihilator]],
			text      = [[Annihilator Defense Turret]],
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
