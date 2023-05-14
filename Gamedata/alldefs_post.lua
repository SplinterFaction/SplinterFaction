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
local unitHealthModifier = tonumber(Spring.GetModOptions().unithealthmodifier)
if unitHealthModifier == nil then
	unitHealthModifier = 100
end

unitHealthModifier = unitHealthModifier * 0.01

local canFactoriesBeAssisted = true
local canAnyUnitsReclaim = true
local useDefaultNanospray = true

-------------------------
-- DEFS POST PROCESSING
-------------------------

function tobool(val)
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
	--Use DDS for Buildpics
	local buildpicfilename = uDef.unitname .. ".dds"
	uDef.buildpic = tostring(buildpicfilename)
	--Spring.Echo (buildpicfilename .. " <-> " .. uDef.buildpicname)


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
	--Spring.Echo(uDef.name)
	--Spring.Echo(uDef.sightdistance)
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

	if uDef.canfly then
		uDef.collide = false
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- Set building start sound for all builders
	--

	--if uDef.builder == true and uDef.sounds then
	--	uDef.sounds.build = "miscfx/Health Pickup 3.wav"
	--end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- Calculate mincloakdistance based on unit footprint size
	--
	--[[
	local sqrt = math.sqrt

	local fx = uDef.footprintx and tonumber(uDef.footprintx) or 1
	local fz = uDef.footprintz and tonumber(uDef.footprintz) or 1
	local radius = 8 * sqrt((fx * fx) + (fz * fz))
	if uDef.customparams and uDef.customparams.decloakradiusmodifier then
		uDef.mincloakdistance = (radius * uDef.customparams.decloakradiusmodifier)
	elseif uDef.customparams and uDef.customparams.decloakradiushalved then
		uDef.mincloakdistance = (radius * 1.5)
	else
		uDef.mincloakdistance = (radius * 2)
	end
	]]--

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- Spring Kludge Removal
	--
	uDef.activateWhenBuilt  = true

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------

	--Set reverse velocity automatically
	if uDef.maxreversevelocity then
		uDef.maxreversevelocity = uDef.maxvelocity * 0.85
	end

	--Override groundplate used
	if uDef.usegrounddecal == true and uDef.customparams and uDef.customparams.customgrounddecal ~= true then
		if uDef.customparams and uDef.customparams.factionname == "Neutral" or
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
	uDef.repairable = true

	-------------------------------------------------------------------------- ------
	--------------------------------------------------------------------------------
	-- Use per piece collision volumes
	-- !Potentially very expensive!
	-- I'm using this to save myself a boatload of time
	uDef.usePieceCollisionVolumes = false

	if uDef.turnrate ~= nil and uDef.canfly ~= true then

	elseif uDef.canfly == true and uDef.hoverattack == true then
		uDef.turnrate = 250
	end

--[[
	if uDef.name == "Crane" then
		Spring.Echo(uDef.name)

		Spring.Echo("AirHoverfactor " .. tostring(uDef.airhoverfactor))
		Spring.Echo("BankingAllowed " .. tostring(uDef.bankingallowed))
		Spring.Echo("WingDrag " .. tostring(uDef.wingdrag))
		Spring.Echo("WingAngle " .. tostring(uDef.wingangle))
		Spring.Echo("FrontToSpeed " .. tostring(uDef.fronttospeed))
		Spring.Echo("SpeedToFront " .. tostring(uDef.speedtofront))
		Spring.Echo("CrashDrag " .. tostring(uDef.crashdrag))
		Spring.Echo("MaxBank " .. tostring(uDef.maxbank))
		Spring.Echo("MaxPitch " .. tostring(uDef.maxpitch))
		Spring.Echo("TurnRadius " .. tostring(uDef.turnradius))
		Spring.Echo("VerticalSpeed " .. tostring(uDef.verticalspeed))
		Spring.Echo("MaxAileron " .. tostring(uDef.maxaileron))
		Spring.Echo("MaxElevator " .. tostring(uDef.maxelevator))
		Spring.Echo("MaxRudder " .. tostring(uDef.maxrudder))
		Spring.Echo("MaxACC " .. tostring(uDef.maxacc))
		Spring.Echo("AttackSafetyDistance " .. tostring(uDef.attacksafetydistance))
		Spring.Echo("TurnRate " .. tostring(uDef.turnrate))
	end
]]--
	if uDef.name == nil then
		uDef.name = uDef.unitname
		Spring.Echo("[AllDefs Post] Unit " .. uDef.name .. " Does not have a human name defined")
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- Limit Commander units to one per team
	if uDef.customparams and uDef.customparams.unitrole and uDef.customparams.unitrole == "Commander" then
		uDef.unitrestricted = 1
	end
	
	if uDef.sounds then
		if uDef.sounds.ok then
			uDef.sounds.ok = nil
		end
	end

	if uDef.sounds then
		if uDef.sounds.select then
			uDef.sounds.select = nil
		end
	end

	if uDef.sounds then
		if uDef.sounds.activate then
			uDef.sounds.activate = nil
		end
		if uDef.sounds.deactivate then
			uDef.sounds.deactivate = nil
		end
		if uDef.sounds.build then
			uDef.sounds.build = nil
		end
	end
	
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- process weapondef
function WeaponDef_Post(name, wDef)

	-- Cylinder Targeting and infinite vertical range for everything
	--wDef.cylindertargeting = 128
	--wDef.heightmod = 1

	--[[
	if wDef.weapontype then
		if wDef.areaofeffect then
			if wDef.name == nil then
				wDef.name = wDef.weapontype
				Spring.Echo(wDef.name .. " " .. wDef.areaofeffect)
			else
				Spring.Echo(wDef.name .. " " .. wDef.areaofeffect)
			end
		end
	end
	]]--

	--Use targetborderoverride in weapondef customparams to override this global setting
	--Controls whether the weapon aims for the center or the edge of its target's collision volume. Clamped between -1.0 - target the far border, and 1.0 - target the near border.
	if wDef.customparams and wDef.customparams.targetborderoverride == nil then
		wDef.targetborder = 0.75 --Aim for just inside the hitsphere
	elseif wDef.customparams and wDef.customparams.targetborderoverride ~= nil then
		wDef.targetborder = tonumber(wDef.customparams.targetborderoverride)
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

	--------------------------------------------------------------------------------
	-------------------------------------------------------------------------------- Turn off waterweapons
	--[[
	if wDef.waterweapon then
		wDef.waterweapon = false
	end
	]]--
	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- Disable Friendly Fire Completely
	if wDef.customparams and wDef.customparams.friendlyfireexception == nil then
		wDef.customparams.nofriendlyfire = true
	end

	if string.find(name, '_scav') then
		VFS.Include("gamedata/scavengers/weapondef_post.lua")
		wDef = scav_Wdef_Post(name, wDef)
	end

	if wDef.weapontype == "Cannon" then
		if wDef.cegtag == nil then
			wDef.cegTag = "plasmacannontrail"
		end
		if wDef.stages == nil then
			wDef.stages = 20
			wDef.alphadecay = 1 - ((1/wDef.stages)/1.5)
			wDef.sizedecay = 0.4 / wDef.stages
			wDef.separation = 1
		end
	end

	if wDef.name == nil then
		wDef.name = wDef.weapontype .. [[ <-- Weapontype - Damage --> ]] .. wDef.damage.default
	end

	-- True will prevent a unit's own weapon from hurting itself
	if wDef.noselfdamage == nil then
		wDef.noselfdamage = true
	end

	wDef.soundhit = "impact-29439"
	wDef.soundhitwet = "subhitbomb"
end


--------------------------
-- MODOPTIONS
-------------------------
--[[
Sprung — 2/20/2023 at 5:27 PM PST
Balance? It's simple really.
unit cost = (pwn - fail) * baw
]]--

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
				-- Set Rules for Neutral race
				if unitDef.customparams and unitDef.customparams.factionname == "Neutral"
						or unitDef.customparams and unitDef.customparams.factionname == "Federation of Kala"
						or unitDef.customparams and unitDef.customparams.factionname == "Loz Alliance" then

					if unitDef.customparams then

						if unitDef.customparams and unitDef.customparams.requiretech == "tech0" or unitDef.customparams and unitDef.customparams.techlevel == "tech0" then
							if unitDef.customparams.unittype == "mobile" then
								unitDef.buildcostenergy = unitDef.buildcostmetal * 1.5
							end

							if unitDef.customparams.unittype == "air" then
								unitDef.buildcostmetal = unitDef.buildcostenergy / 30
							end

							if unitDef.customparams.unittype == "ship" then
								unitDef.buildcostenergy = unitDef.buildcostmetal * 1.5
							end

							if unitDef.customparams.unittype == "building" then
								unitDef.buildcostenergy = unitDef.buildcostmetal * 1.5
							end
						end

						if unitDef.customparams and unitDef.customparams.requiretech == "tech1" or unitDef.customparams and unitDef.customparams.techlevel == "tech1" then
							if unitDef.customparams.unittype == "mobile" then
								unitDef.buildcostenergy = unitDef.buildcostmetal * 3
							end

							if unitDef.customparams.unittype == "air" then
								unitDef.buildcostmetal = unitDef.buildcostenergy / 30
							end

							if unitDef.customparams.unittype == "ship" then
								unitDef.buildcostenergy = unitDef.buildcostmetal * 3
							end

							if unitDef.customparams.unittype == "building" then
								unitDef.buildcostenergy = unitDef.buildcostmetal * 3
							end
						end

						if unitDef.customparams and unitDef.customparams.requiretech == "tech2" or unitDef.customparams and unitDef.customparams.techlevel == "tech2" then
							if unitDef.customparams.unittype == "mobile" then
								unitDef.buildcostenergy = unitDef.buildcostmetal * 6
							end

							if unitDef.customparams.unittype == "air" then
								unitDef.buildcostmetal = unitDef.buildcostenergy / 30
							end

							if unitDef.customparams.unittype == "ship" then
								unitDef.buildcostenergy = unitDef.buildcostmetal * 6
							end

							if unitDef.customparams.unittype == "building" then
								unitDef.buildcostenergy = unitDef.buildcostmetal * 6
							end
						end

						if unitDef.customparams and unitDef.customparams.requiretech == "tech3" or unitDef.customparams and unitDef.customparams.techlevel == "tech3" then
							if unitDef.customparams.unittype == "mobile" then
								unitDef.buildcostenergy = unitDef.buildcostmetal * 12
							end

							if unitDef.customparams.unittype == "air" then
								unitDef.buildcostmetal = unitDef.buildcostenergy / 30
							end

							if unitDef.customparams.unittype == "ship" then
								unitDef.buildcostenergy = unitDef.buildcostmetal * 12
							end

							if unitDef.customparams.unittype == "building" then
								unitDef.buildcostenergy = unitDef.buildcostmetal * 12
							end
						end

						if unitDef.customparams and unitDef.customparams.requiretech == "tech4" or unitDef.customparams and unitDef.customparams.techlevel == "tech4" then
							if unitDef.customparams.unittype == "mobile" then
								unitDef.buildcostenergy = unitDef.buildcostmetal * 15
							end

							if unitDef.customparams.unittype == "air" then
								unitDef.buildcostmetal = unitDef.buildcostenergy / 30
							end

							if unitDef.customparams.unittype == "ship" then
								unitDef.buildcostenergy = unitDef.buildcostmetal * 15
							end

							if unitDef.customparams.unittype == "building" then
								unitDef.buildcostenergy = unitDef.buildcostmetal * 15
							end
						end

						if unitDef.customparams and unitDef.customparams.noenergycost == true then
							unitDef.buildcostenergy = 0
						end
						if unitDef.customparams and unitDef.customparams.nometalcost == true then
							unitDef.buildcostmetal = 0
						end
						if unitDef.customparams and unitDef.customparams.buildcostenergyoverride ~= nil then
							unitDef.buildcostenergy = unitDef.customparams.buildcostenergyoverride
						end
						if unitDef.customparams and unitDef.customparams.buildcostmetaloverride ~= nil then
							unitDef.buildcostmetal = unitDef.customparams.buildcostmetaloverride
						end

					end
				end

				-- This is a catchall for units that don't have a factionname declared
				if unitDef.customparams and unitDef.customparams.factionname == nil then
					unitDef.buildcostmetal  = 518181518
					unitDef.buildcostenergy = 518181518
				end

				-- Lets remove any funky decimal values
				unitDef.buildcostmetal  = math.floor(unitDef.buildcostmetal + 0.5)
				unitDef.buildcostenergy = math.floor(unitDef.buildcostenergy + 0.5)

			end


			-- Set reclaimspeed to be a multiple of workertime. This relies on max defaults set in featuredefs post. Without some max defaults there, this will be a funny result.
			-- unitDef.reclaimspeed = unitDef.workertime

			if canAnyUnitsReclaim == false then
				if unitDef.canreclaim == true then
					unitDef.canreclaim = false
				end
			else
				if unitDef.canreclaim == false then
					unitDef.canreclaim = true
				end
			end

			if unitDef.customparams and unitDef.customparams.unitrole == "Factory" then
				if canFactoriesBeAssisted == false then
					unitDef.canbeassisted = false
				else
					unitDef.canbeassisted = true
				end
			end

			--[[
			--------------------------------------------------------------------------------
			-- Radar Negation and Sight Distance Maximums -- !!!! THIS SECTION IS VERY IMPORTANT !!!!
			--------------------------------------------------------------------------------

			if unitDef.customparams and unitDef.sightdistance then
				-- Maximum Sightdistance for all units barring exceptions
				if unitDef.sightdistance >= 500 and unitDef.customparams.sightdistanceoverride ~= true then
					unitDef.sightdistance = 500
				end

				-- Minimum Sightdistance for buildings
				if unitDef.sightdistance >= 350 and unitDef.customparams.unittype == "building" and unitDef.customparams.sightdistanceoverride ~= true then
					unitDef.sightdistance = 350
				end
			end

			if unitDef.customparams and unitDef.sonardistance then
				if unitDef.sonardistance >= 1 and  unitDef.customparams.sonardistanceoverride ~= true then
					unitDef.sonardistance = 0
				end
			end

			if unitDef.customparams and unitDef.radardistance then
				if unitDef.radardistance >= 1 and  unitDef.customparams.radardistanceoverride ~= true then
					unitDef.radardistance = 0
				end
			end
			]]--

			--------------------------------------------------------------------------------
			-- Raise emitheight for all ground units and add seismic sensors to everything
			--------------------------------------------------------------------------------

			if unitDef.customparams.unittype == "mobile" then
				unitDef.losemitheight = 300
				unitDef.seismicsignature = 1
				unitDef.seismicdistance = 1
				if unitDef.sightdistance <= 850 then
					unitDef.seismicdistance = unitDef.sightdistance + 150
				end
				if unitDef.seismicdistance > 1000 then
					unitDef.seismicdistance = 1000
				end
			end


			--------------------------------------------------------------------------------
			-- Metal and Role Based Finalized HP -- !!!! THIS SECTION IS VERY IMPORTANT !!!!
			--------------------------------------------------------------------------------

			-- Set Base Unit Hitpoints

			if unitDef.customparams and unitDef.customparams.factionname == "Neutral" then
				if unitDef.customparams then
					if unitDef.customparams.unittype == "mobile" then
						unitDef.maxdamage = unitDef.buildcostmetal * 2.5
					end
					if unitDef.customparams.unittype == "air" then
						unitDef.maxdamage = unitDef.buildcostenergy * 0.077
					end
					if unitDef.customparams.unittype == "ship" then
						unitDef.maxdamage = unitDef.buildcostmetal * 10
					end
					if unitDef.customparams.unittype == "building" then
						unitDef.maxdamage = unitDef.buildcostmetal * 5
					end
				end
			end

			if unitDef.customparams and unitDef.customparams.factionname == "Federation of Kala" then
				if unitDef.customparams then
					if unitDef.customparams.unittype == "mobile" then
						unitDef.maxdamage = unitDef.buildcostmetal * 2.5
					end
					if unitDef.customparams.unittype == "air" then
						unitDef.maxdamage = unitDef.buildcostenergy * 0.077
					end
					if unitDef.customparams.unittype == "ship" then
						unitDef.maxdamage = unitDef.buildcostmetal * 10
					end
					if unitDef.customparams.unittype == "building" then
						unitDef.maxdamage = unitDef.buildcostmetal * 5
					end
				end
			end

			if unitDef.customparams and unitDef.customparams.factionname == "Loz Alliance" then
				if unitDef.customparams then
					if unitDef.customparams.unittype == "mobile" then
						unitDef.maxdamage = unitDef.buildcostmetal * 2.5
					end
					if unitDef.customparams.unittype == "air" then
						unitDef.maxdamage = unitDef.buildcostenergy * 0.077
					end
					if unitDef.customparams.unittype == "ship" then
						unitDef.maxdamage = unitDef.buildcostmetal * 10
					end
					if unitDef.customparams.unittype == "building" then
						unitDef.maxdamage = unitDef.buildcostmetal * 5
					end
				end
			end

			-- Add a modifier for unit HP based upon role
			-- Mobile Ground Units
			if unitDef.customparams.unitrole == "Factory" then
				unitDef.maxdamage = unitDef.maxdamage * 5
			end
			if unitDef.customparams.unitrole == "Construction Stub" then
				unitDef.maxdamage = unitDef.maxdamage * 5
			end
			if unitDef.customparams.unitrole == "Builder" then
				unitDef.maxdamage = unitDef.maxdamage * 3
			end
			if unitDef.customparams.unitrole == "Main Battle Tank" then
				unitDef.maxdamage = unitDef.maxdamage * 1
			end
			if unitDef.customparams.unitrole == "Main Battle Tank - Tech 2" then
				unitDef.maxdamage = unitDef.maxdamage * 2
			end
			if unitDef.customparams.unitrole == "Main Battle Tank - Tech 3" then
				unitDef.maxdamage = unitDef.maxdamage * 1.4
			end
			if unitDef.customparams.unitrole == "Scout" then
				unitDef.maxdamage = unitDef.maxdamage * 0.4
			end
			if unitDef.customparams.unitrole == "Artillery" then
				unitDef.maxdamage = unitDef.maxdamage * 0.3
			end
			if unitDef.customparams.unitrole == "Artillery - Tech 2" then
				unitDef.maxdamage = unitDef.maxdamage * 1
			end
			if unitDef.customparams.unitrole == "Anti-Air" then
				unitDef.maxdamage = unitDef.maxdamage * 0.5
			end
			if unitDef.customparams.unitrole == "Anti-Air - Tech 2" then
				unitDef.maxdamage = unitDef.maxdamage * 1.2
			end
			if unitDef.customparams.unitrole == "Short Range Anti-Air" then
				unitDef.maxdamage = unitDef.maxdamage * 0.7
			end
			if unitDef.customparams.unitrole == "Medium Range Anti-Air" then
				unitDef.maxdamage = unitDef.maxdamage * 1
			end
			if unitDef.customparams.unitrole == "Direct Fire Support" then
				unitDef.maxdamage = unitDef.maxdamage * 0.5
			end
			if unitDef.customparams.unitrole == "Direct Fire Support - Tech 2" then
				unitDef.maxdamage = unitDef.maxdamage * 1.2
			end
			if unitDef.customparams.unitrole == "Support" then
				unitDef.maxdamage = unitDef.maxdamage * 0.7
			end
			if unitDef.customparams.unitrole == "Indirect Fire Support" then
				unitDef.maxdamage = unitDef.maxdamage * 0.6
			end
			if unitDef.customparams.unitrole == "Assault" then
				unitDef.maxdamage = unitDef.maxdamage * 2
			end
			if unitDef.customparams.unitrole == "Assault - Tech 2" then
				unitDef.maxdamage = unitDef.maxdamage * 2
			end

			-- Aircraft
			if unitDef.customparams.unitrole == "Air Scout" then
				unitDef.maxdamage = unitDef.maxdamage * 0.4
			end
			if unitDef.customparams.unitrole == "Interceptor" then
				unitDef.maxdamage = unitDef.maxdamage * 1
			end
			if unitDef.customparams.unitrole == "Assault Bomber" then
				unitDef.maxdamage = unitDef.maxdamage * 0.6
			end
			if unitDef.customparams.unitrole == "Strike Fighter" then
				unitDef.maxdamage = unitDef.maxdamage * 0.8
			end
			if unitDef.customparams.unitrole == "Basic Transport" then
				unitDef.maxdamage = unitDef.maxdamage * 0.5
			end
			if unitDef.customparams.unitrole == "Combat Transport" then
				unitDef.maxdamage = unitDef.maxdamage * 0.8
			end
			if unitDef.customparams.unitrole == "Heavy Bomber" then
				unitDef.maxdamage = unitDef.maxdamage * 1.3
			end
			if unitDef.customparams.unitrole == "Strategic Bomber" then
				unitDef.maxdamage = unitDef.maxdamage * 0.5
			end


			--Naval Units
			if unitDef.customparams.unitrole == "Submarine" then
				unitDef.maxdamage = unitDef.maxdamage * 0.3
			end
			if unitDef.customparams.unitrole == "Frigate" then
				unitDef.maxdamage = unitDef.maxdamage * 0.3
			end
			if unitDef.customparams.unitrole == "Destroyer" then
				unitDef.maxdamage = unitDef.maxdamage * 0.5
			end
			if unitDef.customparams.unitrole == "Light Cruiser" then
				unitDef.maxdamage = unitDef.maxdamage * 0.6
			end
			if unitDef.customparams.unitrole == "Heavy Cruiser" then
				unitDef.maxdamage = unitDef.maxdamage * 0.7
			end

			-- Turrets
			if unitDef.customparams.unitrole == "Light Turret" then
				unitDef.maxdamage = unitDef.maxdamage * 0.7
			end
			if unitDef.customparams.unitrole == "Medium Turret" then
				unitDef.maxdamage = unitDef.maxdamage * 1
			end
			if unitDef.customparams.unitrole == "Heavy Turret" then
				unitDef.maxdamage = unitDef.maxdamage * 1.2
			end
			if unitDef.customparams.unitrole == "Artillery Turret" then
				unitDef.maxdamage = unitDef.maxdamage * 0.1
			end
			if unitDef.customparams.unitrole == "Special Turret" then
				unitDef.maxdamage = unitDef.maxdamage * 0.8
			end
			if unitDef.customparams.unitrole == "Mine" then
				unitDef.maxdamage = unitDef.maxdamage * 0.1
			end
			if unitDef.customparams.unitrole == "Shield" then
				unitDef.maxdamage = unitDef.maxdamage * 0.2
			end
			if unitDef.customparams.unitrole == "Support Building" then
				unitDef.maxdamage = unitDef.maxdamage * 0.2
			end
			if unitDef.customparams.unitrole == "Anti-Swarm Turret" then
				unitDef.maxdamage = unitDef.maxdamage * 1
			end
			if unitDef.customparams.unitrole == "Single-Target Turret" then
				unitDef.maxdamage = unitDef.maxdamage * 0.8
			end

			if unitDef.customparams and unitDef.customparams.hpmodifieroverridepercentage then
				unitDef.maxdamage = unitDef.maxdamage * unitDef.customparams.hpmodifieroverridepercentage
			elseif unitDef.customparams and unitDef.customparams.hpoverride then
				unitDef.maxdamage = unitDef.customparams.hpoverride
			end

			-- Lets get rid of any funky decimal places
			unitDef.maxdamage = math.floor(unitDef.maxdamage + 0.5)


			--------------------------------------------------------------------------------
			-- Automatically Calculating Buildtime -- !!!! THIS SECTION IS VERY IMPORTANT !!!!
			--------------------------------------------------------------------------------
			--[[
			--CALCULATE BUILDTIME--
			The point of this is to take energy cost into account when calculating buildtime. This essentially controls how fast energy will be spent, because energy is almost always higher than metal.

			Here is an example:

			Example 1:
			energyMetalWorth = 100
			Unit cost = 100m / 1000e
			1000 / 100 = 10
			100 + 10 = 110 total buildtime


			Example 2:
			energyMetalWorth = 50
			Unit cost = 100m / 1000e
			1000 / 50 = 20
			100 + 10 = 120 total buildtime


			Example 3:
			energyMetalWorth = 10
			Unit cost = 100m / 1000e
			1000 / 10 = 100
			100 + 10 = 200 total buildtime

			As you can see, energyMetalWorth has a very pronounced effect not only on buildtimes, but by extension, outflow of resources.
			
			Remember, as of 2/19/23, factories cannot be assisted, so this has a very pronounced effect on unit build rates.
			]]--
			local totalValueInMetal
			local energyMetalWorth = 10
			if unitDef.buildcostenergy == nil or unitDef.buildcostenergy < energyMetalWorth then
				totalValueInMetal = unitDef.buildcostmetal
			else
				totalValueInMetal = unitDef.buildcostmetal + (unitDef.buildcostenergy / energyMetalWorth)
			end
			unitDef.buildtime = math.floor(totalValueInMetal + 0.5)


			-- Set Supply Costs
			if unitDef.customparams and unitDef.customparams.requiretech == "tech1" then
				if unitDef.customparams and unitDef.customparams.supply_cost then
					local supplycost = totalValueInMetal * 0.01
					unitDef.customparams.supply_cost = math.floor(supplycost + 0.5)
				end
			end
			if unitDef.customparams and unitDef.customparams.requiretech == "tech2" then
				if unitDef.customparams and unitDef.customparams.supply_cost then
					local supplycost = totalValueInMetal * 0.01
					unitDef.customparams.supply_cost = math.floor(supplycost + 0.5)
				end
			end
			if unitDef.customparams and unitDef.customparams.requiretech == "tech3" then
				if unitDef.customparams and unitDef.customparams.supply_cost then
					local supplycost = totalValueInMetal * 0.0065
					unitDef.customparams.supply_cost = math.floor(supplycost + 0.5)
				end
			end
			if unitDef.customparams and unitDef.customparams.requiretech == "tech4" then
				if unitDef.customparams and unitDef.customparams.supply_cost then
					local supplycost = totalValueInMetal * 0.005
					unitDef.customparams.supply_cost = math.floor(supplycost + 0.5)
				end
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