--------------------------
-- DOCUMENTATION
-------------------------

-- SplinterFaction contains weapondefs in its unitdef files
-- Standalone weapondefs are only loaded by Spring after unitdefs are loaded
-- So, if we want to do post processing and include all the unit+weapon defs, and have the ability to bake these changes into files, we must do it after both have been loaded
-- That means, ALL UNIT AND WEAPON DEF POST PROCESSING IS DONE HERE

-- What happens:
-- unitdefs_post.lua calls the _Post functions for unitDefs and any weaponDefs that are contained in the unitdef files
-- unitdefs_post.lua writes the corresponding unitDefs to customparams (if wanted)
-- weapondefs_post.lua fetches any weapondefs from the unitdefs, 
-- weapondefs_post.lua fetches the standlaone weapondefs, calls the _post functions for them, writes them to customparams (if wanted)
-- strictly speaking, alldefs.lua is a misnomer since this file does not handle armordefs, featuredefs or movedefs

-- Switch for when we want to save defs into customparams as strings (so as a widget can then write them to file)
-- The widget to do so can be found in 'etc/Lua/bake_unitdefs_post'
SaveDefsToCustomParams = false

-------------------------
-- Process relevant modoptions and gamewide features first
-------------------------
unitHealthModifier = tonumber(Spring.GetModOptions().unithealthmodifier)
if unitHealthModifier == nil then
	unitHealthModifier = 100
end

unitHealthModifier = unitHealthModifier * 0.01

canAnyUnitsReclaim = true
useDefaultNanospray = true

-------------------------
-- DEFS POST PROCESSING
-------------------------

local function tobool(val)
	local t = type(val)
	if (t == 'nil') then
		return false
	elseif (t == 'boolean') then
		return val
	elseif (t == 'number') then
		return (val ~= 0)
	elseif (t == 'string') then
		return ((val ~= '0') and (val ~= 'false'))
	end
	return false
end

-- process unitdef
function UnitDef_Post(name, uDef)

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- Utility
	--

	local function tobool(val)
	  local t = type(val)
	  if (t == 'nil') then
		return false
	  elseif (t == 'boolean') then
		return val
	  elseif (t == 'number') then
		return (val ~= 0)
	  elseif (t == 'string') then
		return ((val ~= '0') and (val ~= 'false'))
	  end
	  return false
	end


	local function disableunits(unitlist)
	  for name, ud in pairs(UnitDefs) do
		if (ud.buildoptions) then
		  for _, toremovename in ipairs(unitlist) do
			for index, unitname in pairs(ud.buildoptions) do
			  if (unitname == toremovename) then
				table.remove(ud.buildoptions, index)
			  end
			end
		  end
		end
	  end
	end
	
	-- Allow all unit to see planes high above
	-- This ties in with the global Cylinder Targetting
	-- Default airsightdistance is sightdistance * 1.5
	--uDef.airsightdistance = uDef.sightdistance * 2 --No longer needed
	if uDef.airsightdistance == uDef.sightdistance * 1.5 then
		uDef.airsightdistance = uDef.sightdistance
	end
	
	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- Set building Mask 0 for all mobile units
	--
	if uDef.customparams and uDef.customparams.unittype == "mobile" then
		uDef.buildingmask = 0
	end	
	
	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- 3dbuildrange for all non plane builders
	--
	--[[
	for name, ud in pairs(UnitDefs) do
	  if (tobool(ud.isBuilder) and not tobool(ud.canfly)) then
		ud.buildrange3d = true
	  end
	end
	--]]

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- turn off unit collision check for planes
	--

	if uDef.canfly and not uDef.istransport then
 		uDef.collide = false
  	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- Set building start sound for all builders
	--
	
	if uDef.builder == true and uDef.sounds then
		uDef.sounds.build = "miscfx/buildstart-nano.wav"
	end
	
	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- Calculate mincloakdistance based on unit footprint size
	--

	local sqrt = math.sqrt

	local fx = uDef.footprintx and tonumber(uDef.footprintx) or 1
	local fz = uDef.footprintz and tonumber(uDef.footprintz) or 1
	local radius = 8 * sqrt((fx * fx) + (fz * fz))
	if uDef.customparams and uDef.customparams.decloakradiusmodifier then
		uDef.mincloakdistance = (radius * uDef.customparams.decloakradiusmodifier)
	elseif uDef.customparams and uDef.customparams.decloakradiushalved then
		uDef.mincloakdistance = (radius * 3)
	else
		uDef.mincloakdistance = (radius * 6)
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- Spring Kludge Removal
	-- 
	uDef.activateWhenBuilt  = true 

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	
	--Set reverse velocity automatically
	if uDef.maxvelocity then
		uDef.maxreversevelocity = uDef.maxvelocity * 0.75
	end

	--Override groundplate used
	if uDef.usegrounddecal == true and uDef.customparams and uDef.customparams.customgrounddecal ~= true then
		if uDef.customparams and uDef.customparams.factionname == "ateran" or
			uDef.customparams and uDef.customparams.factionname == "Federation of Kala" or
			uDef.customparams and uDef.customparams.factionname == "Loz Alliance" then
			uDef.buildinggrounddecaltype = "groundplate.dds"
			--Make decals sizing easy
			if uDef.footprintx ~= nil and uDef.footprintz ~= nil then
				uDef.buildinggrounddecalsizex = uDef.footprintx + 2
				uDef.buildinggrounddecalsizey = uDef.footprintz + 2
				uDef.buildinggrounddecaldecayspeed = 0.9
			else
				Spring.Echo("[AllDefsPost] " .. uDef.name .. " Does not have it's footprint defined")
			end
		end
		if uDef.customparams and uDef.customparams.factionname == "zaal" then
			uDef.buildinggrounddecaltype = "zgroundtexture2.dds"
		end
		if uDef.customparams and uDef.customparams.factionname == "pattern" then
			uDef.buildinggrounddecaltype = "groundplate.dds"
		end
	end
	
	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- Turn on/off nanospray globally
	if useDefaultNanospray == true then
		if uDef.shownanospray == nil or uDef.shownanospray == false then
			uDef.shownanospray = true
		end
	else
		if uDef.shownanospray == nil or uDef.shownanospray == true then
			uDef.shownanospray = false
		end	
	end
	
	--------------------------------------------------------------------------------
	-------------------------------------------------------------------------------- Make units unable to be built in the water
	if uDef.maxwaterdepth then
		uDef.maxwaterdepth = 25
	end
	if uDef.floater then
		uDef.floater = false
	end
	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- Turn off Chicken Egg drops
	if uDef.corpse == "chicken_egg" then
		uDef.corpse = ""
	end
	
	if string.find(name, '_scav') then
		VFS.Include("gamedata/scavengers/unitdef_post.lua")
		uDef = scav_Udef_Post(name, uDef)
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- Implement idle autoheal for all units
	if uDef.idletime == nil then uDef.idletime = 0 end
	if uDef.idletime > 450 then
		uDef.idletime = 450
	end
	
	if uDef.idleautoheal == nil then uDef.idleautoheal = 0 end
	if uDef.idleautoheal < 1 then
		uDef.idleautoheal = 2.5
	end

	-------------------------------------------------------------------------- ------
	--------------------------------------------------------------------------------
	-- Make units unable to be repaired via nanolathe
	if uDef.repairable then
		uDef.repairable = false
	end

	-------------------------------------------------------------------------- ------
	--------------------------------------------------------------------------------
	-- Use per piece collision volumes
	-- !Potentially very expensive!
	-- I'm using this to save myself a boatload of time
	uDef.usePieceCollisionVolumes = false

end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- process weapondef
function WeaponDef_Post(name, wDef)
	
	-- Cylinder Targeting and infinite vertical range for everything
	--wDef.cylindertargeting = 128
	--wDef.heightmod = 1
	
	wDef.name = wDef.weapontype
	
	--Use targetborderoverride in weapondef customparams to override this global setting
	--Controls whether the weapon aims for the center or the edge of its target's collision volume. Clamped between -1.0 - target the far border, and 1.0 - target the near border.
	if wDef.customparams and wDef.customparams.targetborderoverride == nil then
		wDef.targetborder = 0.75 --Aim for just inside the hitsphere
	elseif wDef.customparams and wDef.customparams.targetborderoverride ~= nil then
		wDef.targetborder = tonumber(wDef.customparams.targetborderoverride)
	end
	
	-- weapon reloadTime and stockpileTime were separated in 77b1
	if (tobool(wDef.stockpile) and (wDef.stockpiletime==nil)) then
		wDef.stockpiletime = wDef.reloadtime
		--wDef.reloadtime    = 2             -- 2 seconds
	end
	
	if (tobool(wDef.ballistic) or tobool(wDef.dropped)) then
		wDef.gravityaffected = true
	end
	
	--Potentially fix times when weapons explode without doing damage
	if tonumber(wDef.areaofeffect) ~= nil and tonumber(wDef.areaofeffect) <= 10 then
		if wDef.customparams and wDef.customparams.aoeoverride == true then
			wDef.areaofeffect = wDef.areaofeffect
		else
			wDef.areaofeffect = 10
		end
	end
	if tonumber(wDef.areaofeffect) ~= nil and tonumber(wDef.areaofeffect) <= 10 then
		if wDef.customparams and wDef.customparams.edgeeffectiveness == true then
			wDef.edgeeffectiveness = wDef.edgeeffectiveness
		else
			wDef.edgeeffectiveness = 1
		end
	end
	
	--Override map gravity for all weapons
	wDef.mygravity = 0.14
	
	--------------------------------------------------------------------------------
	-------------------------------------------------------------------------------- Turn off waterweapons
	if wDef.waterweapon then
		wDef.waterweapon = false
	end
	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- Disable Friendly Fire Completely
	if wDef.customparams and wDef.customparams.friendlyfireexception == nil then
		wDef.customparams.nofriendlyfire = 1
	end
	
	if string.find(name, '_scav') then
		VFS.Include("gamedata/scavengers/weapondef_post.lua")
		wDef = scav_Wdef_Post(name, wDef)
	end
	
end


--------------------------
-- MODOPTIONS
-------------------------

-- process modoptions (last, because they should not get baked)
function ModOptions_Post (UnitDefs, WeaponDefs)
	if (Spring.GetModOptions) then
	local modOptions = Spring.GetModOptions()
	
		for id,unitDef in pairs(UnitDefs) do
			
			--Disabled due to boxcollector cpu costs
			-- if unitDef.customparams.corpse == "energycore" then
				-- unitDef.corpse = "ammobox"
			-- end
			
			--Shield handling
			if unitDef.weapondefs then
				for _, weaponDef in pairs(unitDef.weapondefs) do
					if weaponDef.weapontype == "Shield" then
						unitDef.customparams.shield_radius = weaponDef.shieldradius
						unitDef.customparams.shield_power = weaponDef.shieldpower
						unitDef.customparams.shield_rate = (weaponDef.customparams or {}).shield_rate or weaponDef.shieldpowerregen
						break
					end
				end
			end
		end

		-- Make sure that land based defense weapons and turrets are scaled up to match
		-- for id,wDef in pairs(WeaponDefs) do
			-- if wDef.customparams and wDef.customparams.effectedbyunithealthmodifier == true then
				-- if wDef.damage.default then
					-- wDef.damage.default = wDef.damage.default * (unitHealthModifier * 0.33)
				-- end
				-- --Spring.Echo(wDef.damage.default)
			-- end
		-- end
	
		--------------------------------------------------------------------------------
		-- Process Upgrades --
		--------------------------------------------------------------------------------
	--
		-- for id,uDef in pairs(UnitDefs) do
		-- 	-- Handle upgraded units HP and Max Speed
		-- 	if uDef.customparams and uDef.customparams.isupgraded == "1" then
		-- 		uDef.maxdamage = uDef.maxdamage * 1.20
		-- 		if uDef.maxvelocity then
		-- 			uDef.maxvelocity = uDef.maxvelocity * 0.95
		-- 		end
		-- 	end
		-- 	if uDef.customparams and uDef.customparams.isupgraded == "2" then
		-- 		uDef.maxdamage = uDef.maxdamage * 1.35
		-- 		if uDef.maxvelocity then
		-- 			uDef.maxvelocity = uDef.maxvelocity * 0.90
		-- 		end
		-- 	end
		-- 	if uDef.customparams and uDef.customparams.isupgraded == "3" then
		-- 		uDef.maxdamage = uDef.maxdamage * 1.50
		-- 		if uDef.maxvelocity then
		-- 			uDef.maxvelocity = uDef.maxvelocity * 0.85
		-- 		end
		-- 	end
		-- 	if uDef.customparams and uDef.customparams.isupgraded == "boss" then
		-- 		uDef.maxdamage = uDef.maxdamage * 2.50
		-- 		if uDef.maxvelocity then
		-- 			uDef.maxvelocity = uDef.maxvelocity * 0.75
		-- 		end
		-- 	end
		-- end
	--
		for id,wDef in pairs(WeaponDefs) do
		-- 	-- Handle upgraded units weapon reload times
		-- 	if wDef.customparams and wDef.customparams.isupgraded == "1" then
		-- 		if wDef.reloadtime then
		-- 			wDef.reloadtime = wDef.reloadtime * 0.85
		-- 		end
		-- 		wDef.damage.default = wDef.damage.default * 1.20
		-- 		if wDef.exteriorshield == true and wDef.shieldpower < 0 then
		-- 			wDef.shieldpower = wDef.shieldpower * 1.20
		-- 		end
		-- 	end
		-- 	if wDef.customparams and wDef.customparams.isupgraded == "2" then
		-- 		if wDef.reloadtime then
		-- 			wDef.reloadtime = wDef.reloadtime * 0.70
		-- 		end
		-- 		wDef.damage.default = wDef.damage.default * 1.35
		-- 		if wDef.exteriorshield == true and wDef.shieldpower < 0 then
		-- 			wDef.shieldpower = wDef.shieldpower * 1.35
		-- 		end
		-- 	end
		-- 	if wDef.customparams and wDef.customparams.isupgraded == "3" then
		-- 		if wDef.reloadtime then
		-- 			wDef.reloadtime = wDef.reloadtime * 0.65
		-- 		end
		-- 		wDef.damage.default = wDef.damage.default * 1.50
		-- 		if wDef.exteriorshield == true and wDef.shieldpower < 0 then
		-- 			wDef.shieldpower = wDef.shieldpower * 1.50
		-- 		end
		-- 	end
		-- 	if wDef.customparams and wDef.customparams.isupgraded == "boss" then
		-- 		if wDef.reloadtime then
		-- 			wDef.reloadtime = wDef.reloadtime * 0.5
		-- 		end
		-- 		wDef.damage.default = wDef.damage.default * 10
		-- 		if wDef.exteriorshield == true and wDef.shieldpower < 0 then
		-- 			wDef.shieldpower = wDef.shieldpower * 2.50
		-- 		end
		-- 	end
		--
		-- 	--Handle Shields
		-- 	if wDef.customparams and wDef.customparams.isshieldupgraded == "1" then
		-- 		if wDef.exteriorshield == true then
		-- 			wDef.shieldpower = wDef.shieldpower * 1.20
		-- 		end
		-- 	end
		-- 	if wDef.customparams and wDef.customparams.isshieldupgraded == "2" then
		-- 		if wDef.exteriorshield == true then
		-- 			wDef.shieldpower = wDef.shieldpower * 1.35
		-- 		end
		-- 	end
		-- 	if wDef.customparams and wDef.customparams.isshieldupgraded == "3" then
		-- 		if wDef.exteriorshield == true then
		-- 			wDef.shieldpower = wDef.shieldpower * 1.50
		-- 		end
		-- 	end
		-- 	if wDef.customparams and wDef.customparams.isshieldupgraded == "boss" then
		-- 		if wDef.exteriorshield == true then
		-- 			wDef.shieldpower = wDef.shieldpower * 2.50
		-- 		end
		-- 	end
	
		--------------------------------------------------------------------------------
		--------------------------------------------------------------------------------
		
		--------------------------------------------------------------------------------
		-- Process Armortypes --
		--------------------------------------------------------------------------------
		
			local damageClasses		= VFS.Include("gamedata/configs/damageTypes.lua")
			local damageTypes		= damageClasses.damageTypes
			local defaultClass		= damageClasses.default
			
			weapondamage = tonumber(wDef.damage.default)
			if (weapondamage > 0) then
				if (wDef.customparams) then
					local damagetypelower
					if wDef.customparams.damagetype ~=nil then
						damagetypelower = string.lower(wDef.customparams.damagetype)
					end
					if damagetypelower == '' or damagetypelower == nil then
						damagetypelower = defaultClass
					end
					--Spring.Echo(damagetypelower)	
					--Spring.Echo(" ")	
					if damageTypes[damagetypelower]	then
						for armorClass, armorMultiplier in pairs(damageTypes[damagetypelower]) do	
							--Spring.Echo(wd.name, armorClass, weapondamage*armorMultiplier )
							wDef.damage[armorClass] = weapondamage*armorMultiplier
						end
					else
						Spring.Echo("!!WARNING!! Invalid damagetype: " .. damagetypelower)	
					end
				end
			end
			
			--------------------------------------------------------------------------------
			--------------------------------------------------------------------------------
			-- Set energy cost to fire automatically
			-- There are 2 weapondef customparams used to control this
			-- oldcosttofireformula = true, will result in the original formula that did not account for weapon range to be used
			-- nocosttofire == true, will result in cost to fire being set at 0
			-- local weaponDefaultDamage = wDef.damage.default
			-- local weaponAreaOfEffect = wDef.areaofeffect or 0
			-- local weaponRange = wDef.range or 0
			-- local weaponProjectiles = wDef.projectiles or 1
			-- local weaponBurst = wDef.burst or 1
			-- if wDef.customparams and wDef.customparams.nocosttofire == true then
			-- 	wDef.energypershot = 0
			-- else
			-- 	wDef.energypershot = 0
			-- end
			
			--Here is the rest of the function for units using energy to fire their weapons
--[[			elseif wDef.customparams and wDef.customparams.oldcosttofireforumula == true then
				local energycosttofire = math.floor(weaponDefaultDamage * 0.1 * weaponProjectiles * ((weaponAreaOfEffect * 0.001) + 1)*10 + 0.5)*0.1
				wDef.energypershot = energycosttofire * weaponBurst
			else
			--energycosttofire = weaponDefaultDamage * 0.05 * weaponProjectiles * ((weaponAreaOfEffect * 0.001)  + 1) * weaponRange^0.5 * 0.1
				local energycosttofire = math.floor(weaponDefaultDamage * 0.05 * weaponProjectiles * ((weaponAreaOfEffect * 0.001)  + 1) * weaponRange^0.25 * 0.5*10 + 0.5)*0.1
				wDef.energypershot = energycosttofire * weaponBurst
			end
]]--			
			--Set shield energy cost to recharge
--[[			if wDef.exteriorshield == true then
				if wDef.customparams and wDef.customparams.nocosttofire == true then
					wDef.shieldpowerregenenergy = 0
				else
					--wDef.shieldpowerregenenergy = math.floor(wDef.shieldpowerregen * 0.05 * wDef.shieldradius^0.25 * 0.5 * 10 + 0.5) * 0.1
					--Spring.Echo("Energy usage is " .. wDef.shieldpowerregenenergy)
					wDef.shieldpowerregenenergy = wDef.shieldpowerregen / 10
				end		
			end
]]--
		end
		
		--------------------------------------------------------------------------------
		-- Gameplay Costs --
		--------------------------------------------------------------------------------

		for id,unitDef in pairs(UnitDefs) do

			if unitDef.customparams and unitDef.customparams.unitdefbuildtime == nil then
				-- Set Rules for Ateran race
				if unitDef.customparams and unitDef.customparams.factionname == "ateran"
				or unitDef.customparams and unitDef.customparams.factionname == "Federation of Kala"
				or unitDef.customparams and unitDef.customparams.factionname == "Loz Alliance" then
					unitDef.buildtime = unitDef.buildcostmetal / 4
					unitDef.buildcostenergy = unitDef.buildcostmetal * 1.5
					if unitDef.customparams and unitDef.customparams.requiretech == "tech1" or unitDef.customparams and unitDef.customparams.isupgraded == "1" then
						unitDef.buildcostenergy = unitDef.buildcostmetal * 3
					end
					if unitDef.customparams and unitDef.customparams.requiretech == "tech2" or unitDef.customparams and unitDef.customparams.isupgraded == "2" then
						unitDef.buildcostenergy = unitDef.buildcostmetal * 6
					end
					if unitDef.customparams and unitDef.customparams.requiretech == "tech3" or unitDef.customparams and unitDef.customparams.isupgraded == "3" then
						unitDef.buildcostenergy = unitDef.buildcostmetal * 12
					end
					if unitDef.customparams and unitDef.customparams.noenergycost == true then
						unitDef.buildcostenergy = 0
					end
					if unitDef.customparams and unitDef.customparams.buildcostenergyoverride ~= nil then
						unitDef.buildcostenergy = unitDef.customparams.buildcostenergyoverride
					end
				end

				-- Set Rules for Zaal race
				if unitDef.customparams and unitDef.customparams.factionname == "zaal" then
					unitDef.buildtime = unitDef.buildcostmetal / 4
					unitDef.buildcostenergy = unitDef.buildcostmetal * 5
					if unitDef.customparams and unitDef.customparams.requiretech == "tech1" or unitDef.customparams and unitDef.customparams.isupgraded == "1" then
						unitDef.buildcostenergy = unitDef.buildcostmetal * 7.5
					end
					if unitDef.customparams and unitDef.customparams.requiretech == "tech2" or unitDef.customparams and unitDef.customparams.isupgraded == "2" then
						unitDef.buildcostenergy = unitDef.buildcostmetal * 10
					end
					if unitDef.customparams and unitDef.customparams.requiretech == "tech3" or unitDef.customparams and unitDef.customparams.isupgraded == "3" then
						unitDef.buildcostenergy = unitDef.buildcostmetal * 12.5
					end
					if unitDef.customparams and unitDef.customparams.noenergycost == true then
						unitDef.buildcostenergy = 0
					end
					if unitDef.customparams and unitDef.customparams.buildcostenergyoverride ~= nil then
						unitDef.buildcostenergy = unitDef.customparams.buildcostenergyoverride
					end
				end

				-- This is a catchall for units that don't have a factionname declared
				if unitDef.customparams and unitDef.customparams.factionname == nil then
					unitDef.buildtime = unitDef.buildcostmetal / 4
					unitDef.buildcostenergy = unitDef.buildcostmetal * 0.25
				end

				if unitDef.customparams and unitDef.customparams.supply_cost then
					local supplycost = unitDef.buildcostmetal * 0.1
					unitDef.customparams.supply_cost = math.floor(supplycost + 0.5)
				end

			end

			-- Set reclaimspeed to be a multiple of workertime. This relies on max defaults set in featuredefs post. Without some max defaults there, this will be a funny result.
			unitDef.reclaimspeed = unitDef.workertime

			if canAnyUnitsReclaim == false then
				if unitDef.canreclaim == true then
					unitDef.canreclaim = false
				end
				else
				if unitDef.canreclaim == false then
					unitDef.canreclaim = true
				end
			end

			--------------------------------------------------------------------------------
			-- Metal and Role Based Finalized HP -- !!!! THIS SECTION IS VERY IMPORTANT !!!!
			--------------------------------------------------------------------------------

			-- Set Base Unit Hitpoints
			if unitDef.customparams and unitDef.customparams.factionname == "ateran"
					or unitDef.customparams and unitDef.customparams.factionname == "Federation of Kala"
					or unitDef.customparams and unitDef.customparams.factionname == "Loz Alliance" then
				if unitDef.customparams then
					if unitDef.customparams.unittype == "mobile" then
						unitDef.maxdamage = unitDef.buildcostmetal * 2.5
					end
					if unitDef.customparams.unittype == "building" then
						unitDef.maxdamage = unitDef.buildcostmetal * 5
					end
				end
			end

			-- Add a modifier for unit HP based upon role
			if unitDef.customparams.unitrole == "mbt" then
				unitDef.maxdamage = unitDef.maxdamage * 1
			end
			if unitDef.customparams.unitrole == "scout" then
				unitDef.maxdamage = unitDef.maxdamage * 0.2
			end
			if unitDef.customparams.unitrole == "artillery" then
				unitDef.maxdamage = unitDef.maxdamage * 0.3
			end
			if unitDef.customparams.unitrole == "aa" then
				unitDef.maxdamage = unitDef.maxdamage * 0.3
			end
			if unitDef.customparams.unitrole == "directfiresupport" then
				unitDef.maxdamage = unitDef.maxdamage * 0.5
			end
			if unitDef.customparams.unitrole == "indirectfiresupport" then
				unitDef.maxdamage = unitDef.maxdamage * 0.6
			end

			-- Allow Hitpoints to be globally Controlled via Modotions
			if unitDef.maxdamage then
				--Spring.Echo(uDef.name)
				--Spring.Echo(uDef.maxdamage)
				unitDef.maxdamage = unitDef.maxdamage * unitHealthModifier --Look in the top of this file for default health modifier
				--Spring.Echo(uDef.name)
				--Spring.Echo(uDef.maxdamage)
			end
		end
	end
end