--------------------------------------------------------------------------------
-- featuredefs_post.lua
-- Dynamically generate corpse features based on unitDefs
--------------------------------------------------------------------------------

return function(featureDefs, unitDefs)

	-- STEP 1: Dynamically create corpse features
	for unitName, ud in pairs(unitDefs) do
		local corpseName = unitName .. "_dead"

		if not featureDefs[corpseName] then
			local metal = math.floor((ud.buildCostMetal or 0) * 0.5)
			local health = math.floor((ud.maxdamage or 1000) * 0.5)

			featureDefs[corpseName] = {
				blocking     = false,
				category     = "corpses",
				damage       = health,
				description  = (ud.name or unitName) .. " Wreckage",
				energy       = 0,
				--featureDead  = "",
				footprintX   = ud.footprintX or 2,
				footprintZ   = ud.footprintZ or 2,
				height       = 20,
				hitdensity   = 100,
				metal        = metal,
				object       = ud.objectname or "",
				reclaimable  = true,
				indestructible = true,
				customParams = {
					auto_generated = "true",
				}
			}
		end
	end

	-- STEP 2: Additional post-processing for *all* features
	local function isbool(x)   return (type(x) == 'boolean') end
	local function istable(x)  return (type(x) == 'table')   end
	local function isnumber(x) return (type(x) == 'number')  end
	local function isstring(x) return (type(x) == 'string')  end

	for name, fd in pairs(featureDefs) do

		--Cascading statements to catch any screwups
		if fd.metal then
			fd.mass = fd.metal
			if fd.energy then
				local totalFeatureValueInMetal
				local energyMetalWorth = 10
				totalFeatureValueInMetal = fd.metal + (fd.energy / energyMetalWorth)
				fd.mass = totalFeatureValueInMetal
			end
		end

		-- Ensure footprints are sane
		if fd.footprintZ == 0 or fd.footprintZ == nil then
			fd.footprintZ = 1
		end
		if fd.footprintX == 0 or fd.footprintX == nil then
			fd.footprintX = 1
		end

		-- Auto-unblock small features and vegetation
		if fd.footprintX <= 8 or fd.footprintZ <= 8 then
			local cat = string.lower(fd.category or "")
			if cat == "vegitation" or cat == "vegetation" then
				fd.blocking = false
				fd.customParams = fd.customParams or {}
				-- Optionally: fd.customParams.provide_cover = 1
			end
		end

		-- Default reclaim values if missing
		fd.metal  = tonumber(fd.metal)  or 1
		fd.energy = tonumber(fd.energy) or 1

		if fd.metal >= fd.energy then
			fd.reclaimTime = fd.metal * 0.25
		else
			fd.reclaimTime = fd.energy * 0.25
		end
	end
end