--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    featuredefs_post.lua
--  brief:   featureDef post processing
--  author:  Dave Rodgers
--
--  Copyright (C) 2008.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Per-unitDef featureDefs
--

local function isbool(x)   return (type(x) == 'boolean') end
local function istable(x)  return (type(x) == 'table')   end
local function isnumber(x) return (type(x) == 'number')  end
local function isstring(x) return (type(x) == 'string')  end
local spGetModOptions   = Spring.GetModOptions
--------------------------------------------------------------------------------

if spGetModOptions then

for name, fd in pairs(FeatureDefs) do
	
	if fd["footprintz"] == 0 or fd["footprintz"] == nil then
		fd["footprintz"] = 1
	end
	if fd["footprintx"] == 0 or fd["footprintx"] == nil then
		fd["footprintx"] = 1
	end
	
	if fd["footprintz"] ~= nil and fd["footprintx"] ~= nil then
		if tonumber(fd["footprintz"]) <= 8 
		or tonumber(fd["footprintx"]) <= 8 
		or string.lower(fd["category"]) == "vegitation" 
		or string.lower(fd["category"]) == "vegetation" then

			fd["blocking"] = false
			if (not fd.customparams) then 
				fd.customparams = {}
			end
			
			-- if (not fd.customparams.provide_cover) then
			 -- fd.customparams.provide_cover = 1
			-- end   
		end
	end

	if tonumber(fd["metal"]) == nil then
		fd.metal = 1
	end

	if tonumber(fd["energy"]) == nil then
		fd.energy = 1
	end

	if tonumber(fd["metal"]) >= tonumber(fd["energy"]) then
		fd.reclaimtime = fd.metal * 0.25
		-- Spring.Echo("Based off of metal")
		-- Spring.Echo(fd.name)
		-- Spring.Echo(fd.reclaimtime)

	else
		fd.reclaimtime = fd.energy * 0.25
		-- Spring.Echo("Based off of energy")
		-- Spring.Echo(fd.name)
		-- Spring.Echo(fd.reclaimtime)
	end
	
	
	-- Reset maximum feature values
	-- if tonumber(fd["metal"]) == nil or tonumber(fd["metal"]) == 0 then
		-- fd.metal = 100
	-- end
	-- if tonumber(fd["metal"]) > 100 then
		-- fd.metal =  100
	-- end
	-- if tonumber(fd["energy"]) == nil or tonumber(fd["energy"]) == 0 then
		-- fd.energy = 100
	-- end
	-- if tonumber(fd["energy"]) > 1 then
		-- fd.energy = 100
	-- end
end


end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
