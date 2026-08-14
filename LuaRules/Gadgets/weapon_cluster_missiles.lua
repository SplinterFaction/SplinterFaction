function gadget:GetInfo()
	return {
		name      = "TEK2 Configurable Cluster Missiles",
		desc      = "Splits configured weapon projectiles into optional cluster, MIRV, airburst and recursive sub-missiles",
		author    = "", --Thanks to Jerry Lee for sharing!
		date      = "2026-08-04",
		license   = "GPL v2 or later",
		layer     = 0,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

--------------------------------------------------------------------------------
-- Scroll all the way to the end of this file for extensive documentation
-- Configuration is read from WeaponDef customParams.
--
-- Required:
--   cluster_missile      = 1
--   cluster_child_weapon = "SUBMISSILE"
--
-- Main options:
--   cluster_count            = "8" or "3,3"
--   cluster_levels           = 1
--   cluster_trigger          = "time", "target_distance", "travel_distance",
--                              "altitude", "airburst", "apex", or combinations
--   cluster_trigger_logic    = "any" or "all"
--   cluster_delay            = "1.0" or "1.0,0.55" seconds
--   cluster_target_distance  = 350
--   cluster_travel_distance  = 600
--   cluster_altitude         = 220
--   cluster_altitude_mode    = "above" or "below"
--   cluster_pattern          = "random", "cone", "ring", "star", "fan", "forward"
--   cluster_target_mode      = "original", "scatter", "mirv", "mirv_scatter"
--
-- Lists use one value per split generation. The final value is reused when a
-- later generation has no explicit value.
--------------------------------------------------------------------------------

local GAME_SPEED = Game.gameSpeed or 30
local TWO_PI = math.pi * 2
local BYTE_G = string.byte("g")
local BYTE_U = string.byte("u")
local BYTE_F = string.byte("f")
local BYTE_P = string.byte("p")

local MAX_LEVELS = 5
local MAX_CHILDREN_PER_SPLIT = 64
local MAX_ACTIVE_PROJECTILES = 4096

local spGetGameFrame          = Spring.GetGameFrame
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spGetProjectileTarget   = Spring.GetProjectileTarget
local spGetProjectileDefID    = Spring.GetProjectileDefID
local spGetProjectileTeamID   = Spring.GetProjectileTeamID
local spGetProjectileOwnerID  = Spring.GetProjectileOwnerID
local spGetUnitPosition       = Spring.GetUnitPosition
local spGetFeaturePosition    = Spring.GetFeaturePosition
local spGetUnitTeam           = Spring.GetUnitTeam
local spGetUnitDefID          = Spring.GetUnitDefID
local spGetUnitIsDead         = Spring.GetUnitIsDead
local spGetUnitNeutral        = Spring.GetUnitNeutral
local spGetUnitsInSphere      = Spring.GetUnitsInSphere
local spAreTeamsAllied        = Spring.AreTeamsAllied
local spGetGroundHeight       = Spring.GetGroundHeight
local spSpawnProjectile       = Spring.SpawnProjectile
local spDeleteProjectile      = Spring.DeleteProjectile
local spSetProjectileTarget   = Spring.SetProjectileTarget
local spSpawnCEG              = Spring.SpawnCEG
local spEcho                  = Spring.Echo

local active = {}
local activeCount = 0
local configs = {}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function clamp(value, low, high)
	if value < low then
		return low
	elseif value > high then
		return high
	end
	return value
end

local function trim(value)
	return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function truthy(value)
	if value == true or value == 1 then
		return true
	end
	if value == nil or value == false or value == 0 then
		return false
	end
	local text = string.lower(trim(value))
	return text == "1" or text == "true" or text == "yes" or text == "on"
end

local function getParam(cp, ...)
	for i = 1, select("#", ...) do
		local key = select(i, ...)
		local value = cp[key]
		if value ~= nil then
			return value
		end
	end
	return nil
end

local function splitList(value)
	local result = {}
	if value == nil then
		return result
	end

	local text = tostring(value)
	for token in string.gmatch(text, "[^,;|]+") do
		token = trim(token)
		if token ~= "" then
			result[#result + 1] = token
		end
	end

	if #result == 0 and trim(text) ~= "" then
		result[1] = trim(text)
	end
	return result
end

local function numberList(value, defaultValue)
	local raw = splitList(value)
	local result = {}
	for i = 1, #raw do
		local number = tonumber(raw[i])
		if number ~= nil then
			result[#result + 1] = number
		end
	end
	if #result == 0 and defaultValue ~= nil then
		result[1] = defaultValue
	end
	return result
end

local function listValue(list, level, defaultValue)
	if not list or #list == 0 then
		return defaultValue
	end
	local index = math.min(level, #list)
	local value = list[index]
	if value == nil then
		return defaultValue
	end
	return value
end

local function parseTriggerSet(value)
	local result = {}
	local text = string.lower(tostring(value or "time"))
	text = string.gsub(text, "[,+;|/]", " ")
	for token in string.gmatch(text, "[%w_]+") do
		result[token] = true
	end
	if next(result) == nil then
		result.time = true
	end
	return result
end

local function normalize(x, y, z, fallbackX, fallbackY, fallbackZ)
	local length = math.sqrt(x * x + y * y + z * z)
	if length < 0.000001 then
		return fallbackX or 0, fallbackY or 1, fallbackZ or 0, 0
	end
	return x / length, y / length, z / length, length
end

local function distanceSquared(ax, ay, az, bx, by, bz)
	local dx = ax - bx
	local dy = ay - by
	local dz = az - bz
	return dx * dx + dy * dy + dz * dz
end

local function copyTarget(target)
	if not target then
		return nil
	end
	if target.type == BYTE_G then
		return {
			type = BYTE_G,
			x = target.x,
			y = target.y,
			z = target.z,
		}
	end
	return {
		type = target.type,
		id = target.id,
		x = target.x,
		y = target.y,
		z = target.z,
	}
end

-- Park-Miller PRNG step. It avoids math.random and keeps synced decisions local.
local function random01(seed)
	seed = math.floor(math.abs(seed or 1)) % 2147483647
	if seed == 0 then
		seed = 1
	end
	seed = (seed * 48271) % 2147483647
	return seed / 2147483647, seed
end

local function resolveWeaponDefID(nameOrID)
	if nameOrID == nil then
		return nil
	end

	local numericID = tonumber(nameOrID)
	if numericID and WeaponDefs[numericID] then
		return numericID
	end

	local wanted = string.lower(trim(nameOrID))
	if wanted == "" then
		return nil
	end

	local direct = WeaponDefNames[wanted] or WeaponDefNames[trim(nameOrID)]
	if direct then
		return direct.id
	end

	local suffix = "_" .. wanted
	local foundID
	for weaponName, weaponDef in pairs(WeaponDefNames) do
		local lowerName = string.lower(weaponName)
		local isSuffix = string.sub(lowerName, -#suffix) == suffix
		local displayMatch = weaponDef.name and string.lower(weaponDef.name) == wanted
		if lowerName == wanted or isSuffix or displayMatch then
			if foundID and foundID ~= weaponDef.id then
				spEcho("[ClusterMissile] Ambiguous child weapon name: " .. tostring(nameOrID))
				return nil
			end
			foundID = weaponDef.id
		end
	end

	return foundID
end

local function targetFromProjectile(projectileID)
	local targetType, targetData = spGetProjectileTarget(projectileID)
	if not targetType then
		return nil
	end

	if targetType == BYTE_G and type(targetData) == "table" then
		return {
			type = BYTE_G,
			x = targetData[1],
			y = targetData[2],
			z = targetData[3],
		}
	elseif type(targetData) == "number" then
		return {
			type = targetType,
			id = targetData,
		}
	end

	return nil
end

local function getTargetPosition(target)
	if not target then
		return nil
	end

	local x, y, z
	if target.type == BYTE_U and target.id then
		x, y, z = spGetUnitPosition(target.id)
	elseif target.type == BYTE_F and target.id then
		x, y, z = spGetFeaturePosition(target.id)
	elseif target.type == BYTE_P and target.id then
		x, y, z = spGetProjectilePosition(target.id)
	elseif target.type == BYTE_G then
		x, y, z = target.x, target.y, target.z
	end

	if x then
		target.x, target.y, target.z = x, y, z
		return x, y, z
	end

	if target.x then
		return target.x, target.y, target.z
	end
	return nil
end

local function setProjectileTarget(projectileID, target)
	if not target then
		return false
	end

	if target.type == BYTE_U or target.type == BYTE_F or target.type == BYTE_P then
		if target.id then
			return spSetProjectileTarget(projectileID, target.id, target.type)
		end
	elseif target.type == BYTE_G and target.x then
		return spSetProjectileTarget(projectileID, target.x, target.y, target.z)
	end

	return false
end

local function addActive(projectileID, entry)
	if active[projectileID] then
		active[projectileID] = entry
		return true
	end
	if activeCount >= MAX_ACTIVE_PROJECTILES then
		spEcho("[ClusterMissile] Active projectile safety limit reached.")
		return false
	end
	active[projectileID] = entry
	activeCount = activeCount + 1
	return true
end

local function removeActive(projectileID)
	if active[projectileID] then
		active[projectileID] = nil
		activeCount = math.max(0, activeCount - 1)
	end
end

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local function buildConfig(weaponDefID)
	local weaponDef = WeaponDefs[weaponDefID]
	local cp = weaponDef and weaponDef.customParams
	if not cp or not truthy(getParam(cp, "cluster_missile", "clustermissile")) then
		return nil
	end

	local childNames = splitList(getParam(cp, "cluster_child_weapon", "cluster_childweapon"))
	local childIDs = {}
	for i = 1, #childNames do
		local childID = resolveWeaponDefID(childNames[i])
		if childID then
			childIDs[#childIDs + 1] = childID
		else
			spEcho("[ClusterMissile] Unable to resolve child weapon '" .. tostring(childNames[i])
				.. "' for WeaponDef " .. tostring(weaponDefID))
		end
	end

	if #childIDs == 0 then
		spEcho("[ClusterMissile] WeaponDef " .. tostring(weaponDefID)
			.. " has cluster_missile=1 but no valid cluster_child_weapon.")
		return nil
	end

	local levels = math.floor(tonumber(getParam(cp, "cluster_levels")) or 1)
	levels = clamp(levels, 1, MAX_LEVELS)

	local config = {
		weaponDefID = weaponDefID,
		childIDs = childIDs,
		counts = numberList(getParam(cp, "cluster_count"), 6),
		levels = levels,

		triggers = parseTriggerSet(getParam(cp, "cluster_trigger")),
		triggerLogic = string.lower(trim(getParam(cp, "cluster_trigger_logic") or "any")),
		delays = numberList(getParam(cp, "cluster_delay"), 1.0),
		minAges = numberList(getParam(cp, "cluster_min_age"), 0.05),
		targetDistances = numberList(getParam(cp, "cluster_target_distance"), 350),
		travelDistances = numberList(getParam(cp, "cluster_travel_distance"), 500),
		altitudes = numberList(getParam(cp, "cluster_altitude"), 200),
		altitudeMode = string.lower(trim(getParam(cp, "cluster_altitude_mode") or "above")),
		checkRate = math.max(1, math.floor(tonumber(getParam(cp, "cluster_check_rate")) or 1)),

		pattern = string.lower(trim(getParam(cp, "cluster_pattern") or "random")),
		spreads = numberList(getParam(cp, "cluster_spread"), 0.25),
		coneAngles = numberList(getParam(cp, "cluster_cone_angle"), 24),
		verticalSpreads = numberList(getParam(cp, "cluster_vertical_spread"), 1.0),
		inheritVelocity = numberList(getParam(cp, "cluster_inherit_velocity"), 0.15),
		childSpeeds = numberList(getParam(cp, "cluster_child_speed"), nil),
		childTTLs = numberList(getParam(cp, "cluster_child_ttl"), nil),
		childGravity = numberList(getParam(cp, "cluster_child_gravity"), nil),

		targetMode = string.lower(trim(getParam(cp, "cluster_target_mode") or "original")),
		searchRadii = numberList(getParam(cp, "cluster_search_radius"), 650),
		scatterRadii = numberList(getParam(cp, "cluster_scatter_radius"), 220),
		scatterPattern = string.lower(trim(getParam(cp, "cluster_scatter_pattern") or "ring")),
		scatterHeight = tonumber(getParam(cp, "cluster_scatter_height")) or 8,
		mirvFallback = string.lower(trim(getParam(cp, "cluster_mirv_fallback") or "scatter")),
		targetOnly = string.lower(trim(getParam(cp, "cluster_target_only") or "all")),
		allowNeutral = truthy(getParam(cp, "cluster_allow_neutral")),

		splitCEG = trim(getParam(cp, "cluster_split_ceg") or ""),
		keepParent = truthy(getParam(cp, "cluster_keep_parent")),
		debug = truthy(getParam(cp, "cluster_debug")),
	}

	if config.triggerLogic ~= "all" then
		config.triggerLogic = "any"
	end

	return config
end

--------------------------------------------------------------------------------
-- Target selection
--------------------------------------------------------------------------------

local function makeGroundScatterTarget(baseX, baseY, baseZ, radius, pattern, index, count, seed, extraHeight)
	local angle
	local distance

	if pattern == "random" then
		local r1
		r1, seed = random01(seed + index * 17)
		local r2
		r2, seed = random01(seed + index * 31)
		angle = r1 * TWO_PI
		distance = math.sqrt(r2) * radius
	elseif pattern == "star" then
		angle = ((index - 1) / math.max(1, count)) * TWO_PI
		distance = radius * ((index % 2 == 0) and 0.45 or 1.0)
	else
		angle = ((index - 1) / math.max(1, count)) * TWO_PI
		distance = radius
	end

	local x = clamp(baseX + math.cos(angle) * distance, 1, Game.mapSizeX - 1)
	local z = clamp(baseZ + math.sin(angle) * distance, 1, Game.mapSizeZ - 1)
	local groundY = spGetGroundHeight(x, z)
	local y = groundY + extraHeight

	return {
		type = BYTE_G,
		x = x,
		y = y,
		z = z,
	}
end

local function getEnemyCandidates(teamID, centerX, centerY, centerZ, radius, targetOnly, allowNeutral)
	local units = spGetUnitsInSphere(centerX, centerY, centerZ, radius) or {}
	local candidates = {}

	for i = 1, #units do
		local unitID = units[i]
		local unitTeam = spGetUnitTeam(unitID)
		if unitTeam and not spAreTeamsAllied(teamID, unitTeam) and not spGetUnitIsDead(unitID) then
			local neutral = spGetUnitNeutral(unitID)
			if allowNeutral or not neutral then
				local unitDefID = spGetUnitDefID(unitID)
				local unitDef = unitDefID and UnitDefs[unitDefID]
				local isAir = unitDef and unitDef.canFly
				local accepted = targetOnly == "all"
					or (targetOnly == "air" and isAir)
					or (targetOnly == "ground" and not isAir)

				if accepted then
					local x, y, z = spGetUnitPosition(unitID)
					if x then
						candidates[#candidates + 1] = {
							id = unitID,
							x = x,
							y = y,
							z = z,
							distance = distanceSquared(x, y, z, centerX, centerY, centerZ),
						}
					end
				end
			end
		end
	end

	table.sort(candidates, function(a, b)
		if a.distance == b.distance then
			return a.id < b.id
		end
		return a.distance < b.distance
	end)

	return candidates
end

local function buildChildTargets(entry, count, splitX, splitY, splitZ)
	local config = entry.config
	local level = entry.level
	local baseTarget = copyTarget(entry.target)
	local baseX, baseY, baseZ = getTargetPosition(baseTarget)

	if not baseX then
		baseX, baseY, baseZ = splitX, splitY, splitZ
		baseTarget = {
			type = BYTE_G,
			x = baseX,
			y = baseY,
			z = baseZ,
		}
	end

	local mode = config.targetMode
	if mode == "ground" or mode == "ground_spread" or mode == "cluster" then
		mode = "scatter"
	elseif mode == "multi" or mode == "multitarget" then
		mode = "mirv"
	end

	local targets = {}
	local scatterRadius = listValue(config.scatterRadii, level, 220)
	local searchRadius = listValue(config.searchRadii, level, 650)
	local seed = entry.projectileID * 131 + entry.birthFrame * 17 + level * 1009

	local candidates
	if mode == "mirv" or mode == "mirv_scatter" then
		candidates = getEnemyCandidates(
			entry.teamID,
			baseX, baseY, baseZ,
			searchRadius,
			config.targetOnly,
			config.allowNeutral
		)
	end

	for i = 1, count do
		local target

		if mode == "original" then
			target = copyTarget(baseTarget)

		elseif mode == "scatter" then
			target = makeGroundScatterTarget(
				baseX, baseY, baseZ,
				scatterRadius,
				config.scatterPattern,
				i, count,
				seed,
				config.scatterHeight
			)

		elseif mode == "mirv" or mode == "mirv_scatter" then
			local candidate = candidates and candidates[i]
			if candidate then
				target = {
					type = BYTE_U,
					id = candidate.id,
					x = candidate.x,
					y = candidate.y,
					z = candidate.z,
				}
			elseif mode == "mirv_scatter" or config.mirvFallback == "scatter" then
				target = makeGroundScatterTarget(
					baseX, baseY, baseZ,
					scatterRadius,
					config.scatterPattern,
					i, count,
					seed,
					config.scatterHeight
				)
			else
				target = copyTarget(baseTarget)
			end

		else
			target = copyTarget(baseTarget)
		end

		targets[i] = target
	end

	return targets
end

--------------------------------------------------------------------------------
-- Direction patterns
--------------------------------------------------------------------------------

local function makeBasis(forwardX, forwardY, forwardZ)
	local rightX, rightY, rightZ = -forwardZ, 0, forwardX
	rightX, rightY, rightZ = normalize(rightX, rightY, rightZ, 1, 0, 0)

	local upX = rightY * forwardZ - rightZ * forwardY
	local upY = rightZ * forwardX - rightX * forwardZ
	local upZ = rightX * forwardY - rightY * forwardX
	upX, upY, upZ = normalize(upX, upY, upZ, 0, 1, 0)

	return rightX, rightY, rightZ, upX, upY, upZ
end

local function getPatternDirection(pattern, index, count, seed, forwardX, forwardY, forwardZ, spread, coneAngle, verticalSpread)
	local rightX, rightY, rightZ, upX, upY, upZ = makeBasis(forwardX, forwardY, forwardZ)
	local lateralRight = 0
	local lateralUp = 0

	if pattern == "forward" then
		-- No lateral offset.

	elseif pattern == "fan" then
		local t = 0
		if count > 1 then
			t = ((index - 1) / (count - 1)) * 2 - 1
		end
		lateralRight = math.tan(math.rad(coneAngle)) * t

	elseif pattern == "cone" then
		local angle = (index - 1) * 2.399963229728653
		local radius = math.sqrt((index - 0.5) / math.max(1, count))
			* math.tan(math.rad(coneAngle))
		lateralRight = math.cos(angle) * radius
		lateralUp = math.sin(angle) * radius * verticalSpread

	elseif pattern == "ring" or pattern == "star" then
		local angle = ((index - 1) / math.max(1, count)) * TWO_PI
		local radius = spread
		if pattern == "star" and index % 2 == 0 then
			radius = radius * 0.45
		end
		lateralRight = math.cos(angle) * radius
		lateralUp = math.sin(angle) * radius * verticalSpread

	else
		local r1
		r1, seed = random01(seed + index * 47)
		local r2
		r2, seed = random01(seed + index * 83)
		local angle = r1 * TWO_PI
		local radius = math.sqrt(r2) * spread
		lateralRight = math.cos(angle) * radius
		lateralUp = math.sin(angle) * radius * verticalSpread
	end

	local x = forwardX + rightX * lateralRight + upX * lateralUp
	local y = forwardY + rightY * lateralRight + upY * lateralUp
	local z = forwardZ + rightZ * lateralRight + upZ * lateralUp
	return normalize(x, y, z, forwardX, forwardY, forwardZ)
end

--------------------------------------------------------------------------------
-- Trigger evaluation
--------------------------------------------------------------------------------

local function evaluateTrigger(entry, frame, x, y, z, vx, vy, vz)
	local config = entry.config
	local level = entry.level
	local ageFrames = frame - entry.birthFrame
	local minAgeFrames = listValue(config.minAges, level, 0.05) * GAME_SPEED

	if ageFrames < minAgeFrames then
		return false
	end

	if vy > 0.01 then
		entry.sawRise = true
	end

	local targetX, targetY, targetZ = getTargetPosition(entry.target)
	local targetDistance
	if targetX then
		targetDistance = math.sqrt(distanceSquared(x, y, z, targetX, targetY, targetZ))
	end

	local groundY = spGetGroundHeight(x, z)
	local altitude = y - groundY

	local checks = {}
	local triggerCount = 0

	local function addCheck(name, value)
		if config.triggers[name] then
			triggerCount = triggerCount + 1
			checks[triggerCount] = value
		end
	end

	addCheck("time",
		ageFrames >= listValue(config.delays, level, 1.0) * GAME_SPEED)

	addCheck("target_distance",
		targetDistance ~= nil
		and targetDistance <= listValue(config.targetDistances, level, 350))

	addCheck("proximity",
		targetDistance ~= nil
		and targetDistance <= listValue(config.targetDistances, level, 350))

	addCheck("travel_distance",
		entry.traveled >= listValue(config.travelDistances, level, 500))

	addCheck("distance",
		entry.traveled >= listValue(config.travelDistances, level, 500))

	local altitudeThreshold = listValue(config.altitudes, level, 200)
	local altitudeResult
	if config.altitudeMode == "below" then
		altitudeResult = altitude <= altitudeThreshold
	else
		altitudeResult = altitude >= altitudeThreshold
	end
	addCheck("altitude", altitudeResult)

	addCheck("airburst",
		entry.sawRise
		and vy <= 0
		and altitude <= altitudeThreshold)

	addCheck("apex",
		entry.sawRise and vy <= 0)

	addCheck("always", true)

	if triggerCount == 0 then
		return ageFrames >= listValue(config.delays, level, 1.0) * GAME_SPEED
	end

	if config.triggerLogic == "all" then
		for i = 1, triggerCount do
			if not checks[i] then
				return false
			end
		end
		return true
	end

	for i = 1, triggerCount do
		if checks[i] then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- Splitting
--------------------------------------------------------------------------------

local function makeEntry(projectileID, config, level, birthFrame, x, y, z, target, ownerID, teamID)
	return {
		projectileID = projectileID,
		config = config,
		level = level,
		birthFrame = birthFrame,
		startX = x,
		startY = y,
		startZ = z,
		lastX = x,
		lastY = y,
		lastZ = z,
		traveled = 0,
		sawRise = false,
		target = copyTarget(target),
		ownerID = ownerID,
		teamID = teamID,
	}
end

local function splitProjectile(projectileID, entry, frame, x, y, z, vx, vy, vz)
	local config = entry.config
	local level = entry.level
	local count = math.floor(listValue(config.counts, level, 6))
	count = clamp(count, 1, MAX_CHILDREN_PER_SPLIT)

	local childDefID = listValue(config.childIDs, level, config.childIDs[#config.childIDs])
	local childDef = childDefID and WeaponDefs[childDefID]
	if not childDef then
		removeActive(projectileID)
		return
	end

	removeActive(projectileID)

	local parentDirX, parentDirY, parentDirZ, parentSpeed = normalize(vx, vy, vz, 0, 1, 0)
	local childSpeed = listValue(config.childSpeeds, level, nil)
	if childSpeed then
		childSpeed = childSpeed / GAME_SPEED
	else
		childSpeed = childDef.projectilespeed or childDef.projectileSpeed or parentSpeed
		if not childSpeed or childSpeed <= 0 then
			childSpeed = math.max(parentSpeed, 1)
		end
	end

	local customChildTTL = listValue(config.childTTLs, level, nil)
	local childTTL
	if customChildTTL then
		childTTL = math.max(1, math.floor(customChildTTL * GAME_SPEED))
	else
		childTTL = math.max(1, childDef.flightTime or (10 * GAME_SPEED))
	end
	local spread = listValue(config.spreads, level, 0.25)
	local coneAngle = listValue(config.coneAngles, level, 24)
	local verticalSpread = listValue(config.verticalSpreads, level, 1.0)
	local inheritVelocity = listValue(config.inheritVelocity, level, 0.15)
	local childGravity = listValue(config.childGravity, level, nil)
	local childTargets = buildChildTargets(entry, count, x, y, z)
	local seed = projectileID * 971 + frame * 37 + level * 7919

	if config.splitCEG ~= "" then
		spSpawnCEG(config.splitCEG, x, y, z, parentDirX, parentDirY, parentDirZ)
	end

	for i = 1, count do
		local dirX, dirY, dirZ = getPatternDirection(
			config.pattern,
			i, count,
			seed,
			parentDirX, parentDirY, parentDirZ,
			spread,
			coneAngle,
			verticalSpread
		)

		local speedX = dirX * childSpeed + vx * inheritVelocity
		local speedY = dirY * childSpeed + vy * inheritVelocity
		local speedZ = dirZ * childSpeed + vz * inheritVelocity
		local target = childTargets[i]

		local targetX, targetY, targetZ = getTargetPosition(target)
		if not targetX then
			targetX = x + dirX * 500
			targetY = y + dirY * 500
			targetZ = z + dirZ * 500
			target = {
				type = BYTE_G,
				x = targetX,
				y = targetY,
				z = targetZ,
			}
		end

		local params = {
			pos = {x, y, z},
			speed = {speedX, speedY, speedZ},
			["end"] = {targetX, targetY, targetZ},
			owner = entry.ownerID or -1,
			team = entry.teamID,
			ttl = childTTL,
		}

		if childGravity ~= nil then
			params.gravity = childGravity
		end

		local childProjectileID = spSpawnProjectile(childDefID, params)
		if childProjectileID and childProjectileID >= 0 then
			setProjectileTarget(childProjectileID, target)

			if level < config.levels then
				local childEntry = makeEntry(
					childProjectileID,
					config,
					level + 1,
					frame,
					x, y, z,
					target,
					entry.ownerID,
					entry.teamID
				)
				addActive(childProjectileID, childEntry)
			end
		end
	end

	if not config.keepParent then
		spDeleteProjectile(projectileID)
	end

	if config.debug then
		spEcho("[ClusterMissile] Split projectile " .. projectileID
			.. " level=" .. level
			.. " children=" .. count
			.. " mode=" .. config.targetMode
			.. " pattern=" .. config.pattern)
	end
end

--------------------------------------------------------------------------------
-- Call-ins
--------------------------------------------------------------------------------

function gadget:Initialize()
	for weaponDefID in pairs(WeaponDefs) do
		local config = buildConfig(weaponDefID)
		if config then
			configs[weaponDefID] = config
			if Script.SetWatchProjectile then
				Script.SetWatchProjectile(weaponDefID, true)
			elseif Script.SetWatchWeapon then
				Script.SetWatchWeapon(weaponDefID, true)
			end
		end
	end

	-- Optional compatibility support for /luarules reload while configured
	-- missiles are already flying. Spring.GetAllProjectiles is unavailable in
	-- some Recoil builds (including 2025.04.10), so never call it unguarded.
	if Spring.GetAllProjectiles then
		local projectiles = Spring.GetAllProjectiles() or {}
		local frame = spGetGameFrame()
		for i = 1, #projectiles do
			local projectileID = projectiles[i]
			local weaponDefID = spGetProjectileDefID(projectileID)
			local config = weaponDefID and configs[weaponDefID]
			if config then
				local x, y, z = spGetProjectilePosition(projectileID)
				if x then
					local entry = makeEntry(
						projectileID,
						config,
						1,
						frame,
						x, y, z,
						targetFromProjectile(projectileID),
						spGetProjectileOwnerID(projectileID),
						spGetProjectileTeamID(projectileID)
					)
					addActive(projectileID, entry)
				end
			end
		end
	end
end

function gadget:ProjectileCreated(projectileID, ownerID, weaponDefID)
	if not weaponDefID or weaponDefID < 0 then
		weaponDefID = spGetProjectileDefID(projectileID)
	end

	local config = weaponDefID and configs[weaponDefID]
	if not config then
		return
	end

	local x, y, z = spGetProjectilePosition(projectileID)
	if not x then
		return
	end

	local frame = spGetGameFrame()
	local teamID = spGetProjectileTeamID(projectileID)
	local target = targetFromProjectile(projectileID)
	local entry = makeEntry(
		projectileID,
		config,
		1,
		frame,
		x, y, z,
		target,
		ownerID and ownerID >= 0 and ownerID or spGetProjectileOwnerID(projectileID),
		teamID
	)
	addActive(projectileID, entry)
end

function gadget:ProjectileDestroyed(projectileID)
	removeActive(projectileID)
end

function gadget:GameFrame(frame)
	local toSplit = {}
	local splitCount = 0

	for projectileID, entry in pairs(active) do
		local config = entry.config
		if frame % config.checkRate == projectileID % config.checkRate then
			local x, y, z = spGetProjectilePosition(projectileID)
			if not x then
				removeActive(projectileID)
			else
				local vx, vy, vz = spGetProjectileVelocity(projectileID)
				if not vx then
					removeActive(projectileID)
				else
					entry.traveled = entry.traveled
						+ math.sqrt(distanceSquared(x, y, z, entry.lastX, entry.lastY, entry.lastZ))
					entry.lastX, entry.lastY, entry.lastZ = x, y, z

					if evaluateTrigger(entry, frame, x, y, z, vx, vy, vz) then
						splitCount = splitCount + 1
						toSplit[splitCount] = {
							projectileID = projectileID,
							entry = entry,
							x = x,
							y = y,
							z = z,
							vx = vx,
							vy = vy,
							vz = vz,
						}
					end
				end
			end
		end
	end

	for i = 1, splitCount do
		local data = toSplit[i]
		-- It may have been destroyed by another event before this loop.
		if active[data.projectileID] == data.entry then
			splitProjectile(
				data.projectileID,
				data.entry,
				frame,
				data.x, data.y, data.z,
				data.vx, data.vy, data.vz
			)
		end
	end
end

--------------------------
---Cluster Missile Presets
--------------------------

--[[
# TEK2 CLUSTER MISSILES — customParams PRESETS

Always keep these two lines:

```
cluster_missile      = 1,
cluster_child_weapon = "SUBMISSILE",
```

1. SIMPLE CLUSTER — impacts scattered across the ground

---

```
cluster_count          = 8,
cluster_trigger        = "time",
cluster_delay          = 1.2,
cluster_pattern        = "random",
cluster_spread         = 0.30,
cluster_target_mode    = "scatter",
cluster_scatter_radius = 240,
cluster_child_ttl      = 7,
```

## 2) MIRV — one different enemy target per missile

```
cluster_count           = 8,
cluster_trigger         = "target_distance",
cluster_target_distance = 450,
cluster_pattern         = "ring",
cluster_spread          = 0.24,
cluster_target_mode     = "mirv",
cluster_search_radius   = 700,
cluster_mirv_fallback   = "original",
cluster_child_ttl       = 8,
```

## 3) MIRV + ground dispersion when there are not enough targets

```
cluster_count          = 10,
cluster_trigger        = "target_distance",
cluster_target_distance = 500,
cluster_pattern        = "star",
cluster_target_mode    = "mirv_scatter",
cluster_search_radius  = 800,
cluster_scatter_radius = 260,
cluster_child_ttl      = 8,
```

## 4) AIRBURST — separation during descent

```
cluster_count          = 12,
cluster_trigger        = "airburst",
cluster_altitude       = 230,
cluster_pattern        = "cone",
cluster_cone_angle     = 32,
cluster_target_mode    = "scatter",
cluster_scatter_radius = 300,
cluster_child_ttl      = 6,
```

## 5) ALTITUDE — separation as soon as the missile climbs high enough

```
cluster_count         = 6,
cluster_trigger       = "altitude",
cluster_altitude      = 300,
cluster_altitude_mode = "above",
cluster_pattern       = "ring",
cluster_target_mode   = "original",
```

## 6) PROXIMITY — separation near the target

```
cluster_count           = 6,
cluster_trigger         = "proximity",
cluster_target_distance = 300,
cluster_pattern         = "cone",
cluster_target_mode     = "original",
```

## 7) TRAVEL DISTANCE

```
cluster_count           = 7,
cluster_trigger         = "travel_distance",
cluster_travel_distance = 650,
cluster_pattern         = "star",
cluster_target_mode     = "scatter",
```

## 8) TRAJECTORY APEX

```
cluster_count       = 8,
cluster_trigger     = "apex",
cluster_pattern     = "ring",
cluster_target_mode = "mirv_scatter",
```

## 9) DOUBLE SEPARATION — 1 becomes 3, then each missile becomes 3

```
cluster_child_weapon = "SUBMISSILE,SUBMISSILE",
cluster_count        = "3,3",
cluster_levels       = 2,
cluster_trigger      = "time",
cluster_delay        = "1.0,0.55",
cluster_pattern      = "cone",
cluster_cone_angle   = "18,28",
cluster_target_mode  = "mirv_scatter",
cluster_child_ttl    = "6,5",
```

Maximum result: 3 x 3 = 9 final missiles.

10. THREE STAGES — 1 becomes 2, then 3, then 3

---

```
cluster_child_weapon = "SUBMISSILE,SUBMISSILE,SUBMISSILE",
cluster_count        = "2,3,3",
cluster_levels       = 3,
cluster_trigger      = "time",
cluster_delay        = "0.9,0.55,0.40",
cluster_pattern      = "cone",
cluster_cone_angle   = "12,20,30",
cluster_target_mode  = "mirv_scatter",
cluster_child_ttl    = "7,6,5",
```

Maximum result: 2 x 3 x 3 = 18 final missiles.

11. TRIGGER COMBINATIONS

---

Separate as soon as ANY condition is true:

```
cluster_trigger         = "time,target_distance",
cluster_trigger_logic   = "any",
cluster_delay           = 2.0,
cluster_target_distance = 350,
```

Separate only when ALL conditions are true:

```
cluster_trigger       = "time,altitude",
cluster_trigger_logic = "all",
cluster_delay         = 0.8,
cluster_altitude      = 220,
```

## 12) HORIZONTAL FAN

```
cluster_count       = 7,
cluster_pattern     = "fan",
cluster_cone_angle  = 40,
cluster_target_mode = "scatter",
```

## 13) KEEP THE PARENT MISSILE

```
cluster_keep_parent = 1,
```

By default, the parent missile is silently removed when separation occurs.

Keeping it means that the parent missile continues along its trajectory in
addition to the spawned submissiles.

14. MIRV TARGET FILTERING

---

```
cluster_target_only = "all",     -- default
cluster_target_only = "ground",
cluster_target_only = "air",
```

# BUILT-IN SAFETY LIMITS

* Maximum of 5 levels.
* Maximum of 64 child missiles per separation.
* Maximum of 4096 simultaneously tracked cluster projectiles.
]]--

---------------------
---WEAPONDEFS EXAMPLE
---------------------


--[[
-- EXEMPLE À ADAPTER DANS LE weaponDefs DE TON UNITDEF.
-- Le gadget accepte le nom complet du WeaponDef, son ID, ou un suffixe unique.
-- Donc "SUBMISSILE" fonctionne si le WeaponDef généré finit par "_submissile".

local weaponDefs = {
	CLUSTER_CARRIER = {
		name                    = "IND Cluster Carrier",
		weaponType              = "MissileLauncher",
		range                   = 1200,
		reloadtime              = 8,
		flighttime              = 8,
		weaponVelocity          = 420,
		weaponAcceleration      = 90,
		tracks                  = true,
		turnrate                = 12000,
		tolerance               = 4000,
		model                   = "missile.s3o",
		smokeTrail              = true,
		cegTag                  = "missiletrailmedium",
		explosionGenerator      = "custom:NONE",
		areaOfEffect            = 8,
		avoidFriendly           = false,
		collideFriendly         = false,

		-- Le missile principal ne cause normalement aucun dégât.
		damage = {
			default = 0,
		},

		customParams = {
			cluster_missile      = 1,
			cluster_child_weapon = "SUBMISSILE",

			-- Exemple actif : 8 missiles en cône, séparation à 350 de la cible.
			cluster_count           = 8,
			cluster_levels          = 1,
			cluster_trigger         = "target_distance",
			cluster_target_distance = 350,
			cluster_pattern         = "cone",
			cluster_cone_angle      = 26,
			cluster_target_mode     = "scatter",
			cluster_scatter_radius  = 240,
			cluster_child_ttl       = 7,
			cluster_split_ceg       = "cluster_split_orange",
		},
	},

	SUBMISSILE = {
		name                    = "IND Cluster Sub-Missile",
		weaponType              = "MissileLauncher",
		range                   = 900,
		reloadtime              = 10,
		flighttime              = 7,
		weaponVelocity          = 520,
		weaponAcceleration      = 180,
		tracks                  = true,
		turnrate                = 18000,
		tolerance               = 4000,
		model                   = "missile.s3o",
		smokeTrail              = true,
		cegTag                  = "missiletrailsmall",
		explosionGenerator      = "custom:genericshellexplosion-medium",
		areaOfEffect            = 80,
		edgeEffectiveness       = 0.6,
		avoidFriendly           = false,
		collideFriendly         = false,

		damage = {
			default = 180,
		},
	},
}

return weaponDefs
]]--