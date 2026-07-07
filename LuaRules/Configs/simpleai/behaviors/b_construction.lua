--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    luarules/configs/simpleai/behaviors/b_construction.lua
--  brief:   Construction behavior for the SimpleAI gadget (stage 4 of the
--           modular split). Owns the entire economy-building brain: the
--           priority-chain project selector, factory queues, constructor
--           self-preservation, and every related tunable.
--
--           Registers services.SelectConstructionProject so other behaviors
--           (the commander) can request "build something sensible here" —
--           this module must therefore appear BEFORE b_commander in the
--           core's BEHAVIOR_FILES manifest.
--
--           Owns ctx state: ctx.pacing.factoryDelay / constructorDelay /
--           lastConStart / lastFacStart; increments ctx.counters.converters
--           optimistically on order.
--
--  license: GNU GPL, v2 or later
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return function(ctx, lib, cfg, services)

	--------------------------------------------------------------------------
	-- Tunables (owned by this behavior)
	--------------------------------------------------------------------------
	-- Constructor caps
	local CONSTRUCTOR_MAX         = 4   -- max constructors for normal AI teams
	local CONSTRUCTOR_MAX_CON_AI  = 12  -- higher cap for dedicated SimpleConstructorAI teams
	-- Minimum frames between STARTING any new constructor on a team. Because every
	-- factory on a team is evaluated in the same GameFrame tick, without this they
	-- all read the same stale count and queue a constructor at once. This rate-limit
	-- lets the count catch up so the hard cap is actually respected.
	local CON_BUILD_SPACING      = 150  -- ~5s at 30Hz

	-- Higher-tier preference. Per-unit build weight scales with (techTier+1)^bias,
	-- so advanced units/factories are chosen far more often while lower tiers still appear.
	local TECH_UNIT_BIAS    = 1.8    -- combat unit tech preference
	local TECH_FAC_BIAS     = 2.4    -- factory tech preference (want advanced plants to unlock advanced units)

	-- Turret demand model
	local TURRET_BASE        = 2     -- always want at least this many turrets once a factory exists
	local TURRET_PER_FAC     = 1     -- + this many wanted per factory
	local TURRET_PER_MEX_DIV = 3     -- + 1 wanted per this many mexes
	local TURRET_CAP         = 20    -- absolute max turrets to build per team

	local MEX_TARGET_EARLY  = 2      -- grab this many mexes before anything else
	local MEX_TARGET_MID    = 8      -- expand to this many once economy is running
	local MEX_RANGE_EARLY   = 2000   -- mex search radius before base established
	local MEX_RANGE_MID     = 5000   -- mex search radius once we have 2+ factories
	local CONVERTER_MAX     = 3      -- max energy converters per team
	local FACTORY_MAX       = 12     -- max factories per team
	local LAND_FAC_MIN      = 3      -- build at least this many land factories before any air/sea
	-- Factory build pacing. A flat frame-based limiter (like the constructor one),
	-- so the Nth factory is no slower to start than the 2nd. When resources are
	-- overflowing we build them much faster, since extra production capacity is
	-- the best sink for a surplus.
	local FACTORY_SPACING       = 90   -- normal min frames between starting factories (~3s)
	local FACTORY_SPACING_FLOOD = 45   -- min frames when overflowing (~1.5s)

	-- Income targets required to trigger each tech upgrade.
	-- Key = current tech level. Values are the income thresholds to AIM for.
	local TECH_INCOME_GOALS = {
		[0] = { m = 10,  e = 170  },
		[1] = { m = 20,  e = 560  },
		[2] = { m = 40,  e = 1040 },
		[3] = { m = 80,  e = 3120 },
	}

	-- How strongly to bias toward economy when below the tech threshold.
	-- 0.5 = balanced: economy prioritised but army still builds.
	local TECH_ECONOMY_BIAS = 0.5

	--------------------------------------------------------------------------
	-- Shared state / config
	--------------------------------------------------------------------------
	local mapsizeX          = cfg.mapsizeX
	local mapsizeZ          = cfg.mapsizeZ
	local FACTORY_OVERFLOW  = cfg.FACTORY_OVERFLOW
	local AIR_FACTORY_NAMES = cfg.AIR_FACTORY_NAMES
	local SEA_FACTORY_NAMES = cfg.SEA_FACTORY_NAMES

	local IsFactory     = ctx.IsFactory
	local IsConstructor = ctx.IsConstructor

	local SimpleFactoriesCount   = ctx.counters.factories
	local SimpleT1Mexes          = ctx.counters.mexes
	local SimpleConstructorCount = ctx.counters.constructors
	local SimpleConverterCount   = ctx.counters.converters
	local SimpleTurretCount      = ctx.counters.turrets
	local SimpleLandFacCount     = ctx.counters.landFactories
	local SimpleFactoryDelay     = ctx.pacing.factoryDelay
	local SimpleConstructorDelay = ctx.pacing.constructorDelay
	local SimpleLastConStart     = ctx.pacing.lastConStart
	local SimpleLastFacStart     = ctx.pacing.lastFacStart
	local SimpleUnderAttack      = ctx.intel.underAttack
	local SimpleEnemyBasePos     = ctx.intel.enemyBase
	local TeamTechLevel          = ctx.techLevel
	local SimpleCommanderDefs    = ctx.commanderDefs

	local GetBuildable            = lib.GetBuildable
	local GetBuildableTechBiased  = lib.GetBuildableTechBiased
	local GetWeightedBuildable    = lib.GetWeightedBuildable
	local CombatRoleWeight        = lib.CombatRoleWeight
	local SimpleGetClosestMexSpot = lib.GetClosestMexSpot
	local SimpleBuildOrder        = lib.BuildOrder

	local B = { name = "construction", order = 40 }

	function B.TeamInit(teamID)
		SimpleFactoryDelay[teamID]     = 0
		SimpleConstructorDelay[teamID] = 0
		-- Negative seeds so the very first constructor/factory are not gated
		-- by the spacing limiters at game start.
		SimpleLastConStart[teamID]     = -CON_BUILD_SPACING
		SimpleLastFacStart[teamID]     = -FACTORY_SPACING
	end

	--------------------------------------------------------------------------
	-- CONSTRUCTION PROJECT SELECTION
	-- The shared "build something sensible" engine, used by constructors and
	-- factories here and by the commander via the services registry.
	--------------------------------------------------------------------------
	local function SimpleConstructionProjectSelection(
			unitID, unitDefID, unitTeam, allyTeamID, units, allunits, buildType)

		local success = false

		local nowFrame   = Spring.GetGameFrame()
		-- True only if enough frames have passed since this team last STARTED a
		-- constructor. Shared by every factory/builder so the whole team starts at
		-- most one constructor per CON_BUILD_SPACING, letting the count catch up.
		local conSpacingOk = (nowFrame - (SimpleLastConStart[unitTeam] or 0)) >= CON_BUILD_SPACING

		local supplyUsed = math.round(Spring.GetTeamRulesParam(unitTeam, "supplyUsed") or 0)
		local supplyMax  = math.round(Spring.GetTeamRulesParam(unitTeam, "supplyMax")  or 0)
		local mcurrent, mstorage, _, mincome = Spring.GetTeamResources(unitTeam, "metal")
		local ecurrent, estorage, _, eincome = Spring.GetTeamResources(unitTeam, "energy")
		local unitposx, unitposy, unitposz   = Spring.GetUnitPosition(unitID)
		local buildOptions = UnitDefs[unitDefID].buildOptions
		local techLevel    = TeamTechLevel[unitTeam] or 1

		-- Factory pacing: a single per-team frame limiter (no escalating delay), so
		-- factory #8 starts as readily as factory #2. When both metal and energy are
		-- piling up we drop to the faster "flood" spacing and pour the surplus into
		-- new production lines.
		local overflowing  = mstorage > 0 and estorage > 0
				and mcurrent > mstorage * FACTORY_OVERFLOW
				and ecurrent > estorage * FACTORY_OVERFLOW
		local facSpacing   = overflowing and FACTORY_SPACING_FLOOD or FACTORY_SPACING
		local facSpacingOk = (nowFrame - (SimpleLastFacStart[unitTeam] or 0)) >= facSpacing

		-- econPressure: 0 = at target, approaches 1 when far below next tech threshold
		local goal = TECH_INCOME_GOALS[techLevel]
		local econPressure = 0
		if goal and techLevel < 4 then
			local mRatio = (goal.m > 0) and math.min(1, mincome / goal.m) or 1
			local eRatio = (goal.e > 0) and math.min(1, eincome / goal.e) or 1
			econPressure = TECH_ECONOMY_BIAS * (1 - math.min(mRatio, eRatio))
		end

		-- TryBuild: find first unit from defList that is in our build options,
		-- shuffle so we don't always pick the same one.
		local function TryBuild(defList, orderFn)
			if not defList or #defList == 0 then return false end
			local shuffled = {}
			for _, v in ipairs(defList) do shuffled[#shuffled + 1] = v end
			for d = #shuffled, 2, -1 do
				local j = math.random(1, d)
				shuffled[d], shuffled[j] = shuffled[j], shuffled[d]
			end
			for _, project in ipairs(shuffled) do
				for i2 = 1, #buildOptions do
					if buildOptions[i2] == project then
						orderFn(project)
						return true
					end
				end
			end
			return false
		end

		-- Weighted-random variant: takes {id=,w=} pairs (from GetWeightedBuildable),
		-- filters to what this builder/factory can actually make, and picks one with
		-- probability proportional to weight. Used for combat composition control.
		local function TryBuildWeighted(weighted, orderFn)
			if not weighted or #weighted == 0 then return false end
			local cands, total = {}, 0
			for _, e in ipairs(weighted) do
				for i2 = 1, #buildOptions do
					if buildOptions[i2] == e.id then
						cands[#cands + 1] = e
						total = total + e.w
						break
					end
				end
			end
			if total <= 0 then return false end
			local roll, acc = math.random() * total, 0
			for _, e in ipairs(cands) do
				acc = acc + e.w
				if roll <= acc then
					orderFn(e.id)
					return true
				end
			end
			orderFn(cands[#cands].id)   -- float-rounding fallback
			return true
		end

		local function NearMe(project)
			local x, y, z = Spring.GetUnitPosition(unitID)
			-- Use a larger offset so we don't place inside the caller's own footprint.
			-- Also nudge away from map edges.
			local ox = math.random(-256, 256)
			local oz = math.random(-256, 256)
			if x + ox < 256 then ox = math.abs(ox) end
			if x + ox > mapsizeX - 256 then ox = -math.abs(ox) end
			if z + oz < 256 then oz = math.abs(oz) end
			if z + oz > mapsizeZ - 256 then oz = -math.abs(oz) end
			local bx, bz = x + ox, z + oz
			local by = Spring.GetGroundHeight(bx, bz)
			local facing = math.random(0, 3)
			local testpos = Spring.TestBuildOrder(project, bx, by, bz, facing)
			if testpos == 2 then
				Spring.GiveOrderToUnit(unitID, -project, { bx, by, bz, facing }, 0)
			else
				-- Fall back to SimpleBuildOrder if direct placement failed
				SimpleBuildOrder(unitID, project)
			end
		end

		local function AtMex(project, spot)
			Spring.GiveOrderToUnit(unitID, -project,
			                       { spot.x, spot.y, spot.z, 0 }, { "shift" })
		end

		SimpleFactoryDelay[unitTeam]     = SimpleFactoryDelay[unitTeam] - 1
		SimpleConstructorDelay[unitTeam] = SimpleConstructorDelay[unitTeam] - 1

		local r = math.random(0, 20)

		-- Dynamic mex search range: cast a wide net once we have factories running
		local mexRange  = (SimpleFactoriesCount[unitTeam] >= 2) and MEX_RANGE_MID or MEX_RANGE_EARLY
		local mexspot   = SimpleGetClosestMexSpot(unitposx, unitposz, mexRange)
		-- Also look globally for any unclaimed mex (no range limit) for roaming decisions
		local mexAny    = SimpleGetClosestMexSpot(unitposx, unitposz, nil)

		-- Fetch current tech-appropriate lists
		local extractors   = GetBuildable(unitTeam, "extractor")
		local generators   = GetBuildable(unitTeam, "generator")
		local converters   = GetBuildable(unitTeam, "converter")
		local turrets      = GetBuildable(unitTeam, "turret")
		local supplies     = GetBuildable(unitTeam, "supply")
		local storages     = GetBuildable(unitTeam, "storage")
		local factories    = GetBuildableTechBiased(unitTeam, "factory", TECH_FAC_BIAS)
		local constructors = GetBuildable(unitTeam, "constructor")
		local combats      = GetWeightedBuildable(unitTeam, "combat", TECH_UNIT_BIAS, CombatRoleWeight)
		local buildings    = GetBuildable(unitTeam, "building")

		-- Split factories: only offer air/sea once we have enough land factories
		local landFacCount  = SimpleLandFacCount[unitTeam] or 0
		local landFactories = {}
		local extraFactories = {}
		for _, id in ipairs(factories) do
			if AIR_FACTORY_NAMES[UnitDefs[id] and UnitDefs[id].name]
					or SEA_FACTORY_NAMES[UnitDefs[id] and UnitDefs[id].name] then
				extraFactories[#extraFactories + 1] = id
			else
				landFactories[#landFactories + 1] = id
			end
		end
		-- Before LAND_FAC_MIN land factories, only offer land factories
		if landFacCount < LAND_FAC_MIN then
			factories = landFactories
		end

		local turretCount  = SimpleTurretCount[unitTeam] or 0
		local belowTurretCap = turretCount < TURRET_CAP
		-- How many turrets this base actually wants, scaled to its size.
		local desiredTurrets = math.min(TURRET_CAP,
			TURRET_BASE
			+ (SimpleFactoriesCount[unitTeam] or 0) * TURRET_PER_FAC
			+ math.floor((SimpleT1Mexes[unitTeam] or 0) / TURRET_PER_MEX_DIV))
		local underDefended = (SimpleFactoriesCount[unitTeam] or 0) > 0
			and turretCount < desiredTurrets and belowTurretCap
		local canAffordTurret = ecurrent > estorage * 0.20 and mcurrent > mstorage * 0.15

		-- -------------------------------------------------------
		-- BUILDER / COMMANDER priority chain
		-- -------------------------------------------------------
		if buildType == "Builder" or buildType == "Commander" then

			-- PRIORITY 1: early mexes (always grab the first few immediately)
			if mexspot and SimpleT1Mexes[unitTeam] < MEX_TARGET_EARLY then
				success = TryBuild(extractors, function(p) AtMex(p, mexspot) end)

				-- PRIORITY 2: energy - urgent if low or econ pressure is high
			elseif ecurrent < estorage * 0.40 or eincome <= 80
					or (econPressure > 0.5 and goal and eincome < goal.e * 0.6) then
				if mcurrent > mstorage * 0.60 and SimpleConverterCount[unitTeam] < CONVERTER_MAX then
					if TryBuild(converters, function(p) SimpleBuildOrder(unitID, p) end) then
						SimpleConverterCount[unitTeam] = SimpleConverterCount[unitTeam] + 1
						success = true
					end
				end
				if not success then
					success = TryBuild(generators, function(p) SimpleBuildOrder(unitID, p) end)
				end

				-- PRIORITY 3: metal income low and econ pressure high — grab more mexes
			elseif econPressure > 0.5 and goal and mincome < goal.m * 0.6
					and mexspot and SimpleT1Mexes[unitTeam] < MEX_TARGET_MID then
				success = TryBuild(extractors, function(p) AtMex(p, mexspot) end)

				-- PRIORITY 4: supply if running short
			elseif SimpleFactoriesCount[unitTeam] > 0
					and ((supplyUsed > supplyMax * 0.55 and supplyMax < 950) or supplyMax < 20) then
				success = TryBuild(supplies, function(p) SimpleBuildOrder(unitID, p) end)

				-- PRIORITY 5: build first factory
			elseif SimpleFactoriesCount[unitTeam] == 0 and SimpleFactoryDelay[unitTeam] <= 0 then
				if TryBuild(factories, function(p) SimpleBuildOrder(unitID, p) end) then
					SimpleFactoryDelay[unitTeam] = 120
					SimpleLastFacStart[unitTeam] = nowFrame
					success = true
				end

				-- PRIORITY 5b: REACTIVE defense — if the base is under attack and we
				-- are under-defended, throw up a turret immediately (jumps the queue).
			elseif SimpleUnderAttack[unitTeam] and underDefended and canAffordTurret
					and buildType ~= "Commander" then
				success = TryBuild(turrets, function(p) SimpleBuildOrder(unitID, p) end)

				-- PRIORITY 5c: OVERFLOW → production. If resources are piling up, the
				-- single best thing to do is add a factory. This jumps ahead of mex
				-- expansion / generators / constructors / roaming so a surplus turns
				-- into production capacity fast instead of sitting in storage.
			elseif overflowing and SimpleFactoriesCount[unitTeam] > 0
					and SimpleFactoriesCount[unitTeam] < FACTORY_MAX
					and facSpacingOk then
				if TryBuild(factories, function(p) SimpleBuildOrder(unitID, p) end) then
					SimpleLastFacStart[unitTeam] = nowFrame
					success = true
				end

				-- PRIORITY 6: mid-game mex expansion (factory exists, energy healthy)
			elseif mexspot and SimpleT1Mexes[unitTeam] < MEX_TARGET_MID
					and SimpleFactoriesCount[unitTeam] > 0
					and ecurrent > estorage * 0.30 then
				success = TryBuild(extractors, function(p) AtMex(p, mexspot) end)

				-- PRIORITY 6b: STEADY defense — keep building toward the desired turret
				-- count. Gated by a coin-flip so it interleaves with expansion rather
				-- than monopolising the builder. (Builders only; commander keeps teching.)
			elseif underDefended and canAffordTurret and buildType ~= "Commander"
					and math.random(0, 1) == 0 then
				success = TryBuild(turrets, function(p) SimpleBuildOrder(unitID, p) end)

				-- PRIORITY 7: econ-biased generator building (to hit tech income target)
			elseif econPressure > 0.3 and goal and eincome < goal.e then
				success = TryBuild(generators, function(p) SimpleBuildOrder(unitID, p) end)

				-- PRIORITY 8: expand constructors
			elseif ecurrent > estorage * 0.50 and mcurrent > mstorage * 0.45
					and conSpacingOk
					and SimpleConstructorCount[unitTeam] < CONSTRUCTOR_MAX
					and supplyUsed < supplyMax - 5 then

				-- A commander may occasionally assist-build another commander; that
				-- does not count against the constructor rate limit.
				if buildType == "Commander" and math.random(0, 2) == 0 then
					success = TryBuild(SimpleCommanderDefs, function(p) NearMe(p) end)
				end
				if not success then
					local builtCon = TryBuild(constructors, function(p) NearMe(p) end)
					if builtCon then
						SimpleLastConStart[unitTeam] = nowFrame
						success = true
					end
				end

				-- PRIORITY 9: more factories (steady expansion when resources allow)
			elseif ecurrent > estorage * 0.50 and mcurrent > mstorage * 0.50
					and SimpleFactoriesCount[unitTeam] < FACTORY_MAX
					and facSpacingOk then
				if TryBuild(factories, function(p) SimpleBuildOrder(unitID, p) end) then
					SimpleLastFacStart[unitTeam] = nowFrame
					success = true
				end

				-- PRIORITY 10: storage when overflowing
			elseif ecurrent > estorage * 0.88 and mcurrent > mstorage * 0.88 then
				success = TryBuild(storages, function(p) SimpleBuildOrder(unitID, p) end)

				-- PRIORITY 11: roam to any unclaimed mex on the map (builders only)
				-- This fires before turrets so expansion always beats defense building.
			elseif mexAny and buildType ~= "Commander"
					and SimpleFactoriesCount[unitTeam] > 0 then
				success = TryBuild(extractors, function(p) AtMex(p, mexAny) end)

				-- PRIORITY 12: reclaim — send builders out to grab metal from wrecks.
				-- Fires on r <= 4 (5/21 chance) so it happens regularly but not constantly.
			elseif r <= 4 and buildType ~= "Commander" then
				local enemyBase = SimpleEnemyBasePos[unitTeam]
				if enemyBase then
					Spring.GiveOrderToUnit(unitID, CMD.RECLAIM,
					                       { enemyBase.x + math.random(-400, 400), enemyBase.y,
					                         enemyBase.z + math.random(-400, 400), 1500 }, 0)
				else
					-- Roam toward map center to reclaim neutral wrecks
					local cx, cz = mapsizeX / 2, mapsizeZ / 2
					Spring.GiveOrderToUnit(unitID, CMD.RECLAIM,
					                       { cx + math.random(-300, 300), Spring.GetGroundHeight(cx, cz),
					                         cz + math.random(-300, 300),
					                         math.ceil(math.sqrt(mapsizeX * mapsizeX + mapsizeZ * mapsizeZ)) }, 0)
				end
				success = true

				-- PRIORITY 13: extra defense only if still under the desired count
				-- (steady/reactive slots above are the primary defense builders).
				-- (There is no repair in SF, so the old area-repair slot is gone;
				-- r == 7 now falls through to the fallback below.)
			elseif (r == 5 or r == 6) and underDefended and canAffordTurret then
				success = TryBuild(turrets, function(p) SimpleBuildOrder(unitID, p) end)

				-- FALLBACK: misc buildings only — no extra turret roll here
			else
				if #buildings > 0 and math.random(0, 1) == 0 then
					success = TryBuild(buildings, function(p) SimpleBuildOrder(unitID, p) end)
				end
				-- If still no success and there are unclaimed mexes, go get one
				if not success and mexAny then
					success = TryBuild(extractors, function(p) AtMex(p, mexAny) end)
				end
			end

			-- -------------------------------------------------------
			-- FACTORY queue
			-- -------------------------------------------------------
		elseif buildType == "Factory" then
			if #Spring.GetFullBuildQueue(unitID, 0) < 10 and supplyUsed < supplyMax * 0.95 then
				local luaAI = Spring.GetTeamLuaAI(unitTeam)
				local isConAI = string.sub(luaAI, 1, 19) == 'SimpleConstructorAI'
				local conCap  = isConAI and CONSTRUCTOR_MAX_CON_AI or CONSTRUCTOR_MAX
				-- Two-part guard against worker floods:
				--   1. Hard cap: never exceed conCap live constructors.
				--   2. Spacing: only ONE constructor may START per team per window.
				-- Without (2) every factory evaluates in the same tick, all see the
				-- same stale count, and all queue a constructor at once. Dedicated
				-- SimpleConstructorAI teams skip the spacing (it's their whole job)
				-- but are still bounded by the higher cap.
				local haveConRoom = (SimpleConstructorCount[unitTeam] or 0) < conCap
				local wantConstructor = haveConRoom
						and (isConAI or conSpacingOk)
						and (
							isConAI
							or math.random(0, 5) == 0
							or supplyUsed > supplyMax * 0.85
							or econPressure > 0.4 )

				if wantConstructor then
					success = TryBuild(constructors, function(p)
						local x, y, z = Spring.GetUnitPosition(unitID)
						Spring.GiveOrderToUnit(unitID, -p, { x, y, z, 0 }, 0)
					end)
					if success then SimpleLastConStart[unitTeam] = nowFrame end
				end
				if not success then
					success = TryBuildWeighted(combats, function(p)
						local x, y, z = Spring.GetUnitPosition(unitID)
						Spring.GiveOrderToUnit(unitID, -p, { x, y, z, 0 }, 0)
					end)
				end
			else
				success = true
			end
		end

		return success
	end

	-- Shared service: the commander behavior builds through this too.
	services.SelectConstructionProject = SimpleConstructionProjectSelection

	--------------------------------------------------------------------------
	-- Ownership: constructors and factories.
	--------------------------------------------------------------------------
	function B.unitFilter(unitDefID)
		return IsConstructor[unitDefID] == true or IsFactory[unitDefID] == true
	end

	--------------------------------------------------------------------------
	-- Per-unit orders for constructors and factories.
	--------------------------------------------------------------------------
	function B.UnitTick(tick, unitID, unitDefID, hpRatio, ux, uy, uz, unitCmds)
		local teamID     = tick.teamID
		local allyTeamID = tick.allyTeamID
		local units      = tick.units
		local allunits   = tick.allUnits

		-- ======== CONSTRUCTORS ========
		if IsConstructor[unitDefID] then

			local nearEnemy = Spring.GetUnitNearestEnemy(unitID, 600, true)

			if nearEnemy and hpRatio > 0.85 then
				Spring.GiveOrderToUnit(unitID, CMD.RECLAIM, { nearEnemy }, 0)

			elseif nearEnemy then
				for x = 1, 50 do
					local candidate = units[math.random(1, #units)]
					local cDefID    = Spring.GetUnitDefID(candidate)
					if cDefID and UnitDefs[cDefID].isBuilding then
						local tx, ty, tz = Spring.GetUnitPosition(candidate)
						Spring.GiveOrderToUnit(unitID, CMD.MOVE,
						                       { tx + math.random(-100, 100), ty,
						                         tz + math.random(-100, 100) }, 0)
						break
					end
				end

			elseif unitCmds == 0 then
				-- Check if we are very close to a factory (within its footprint).
				-- If so, walk away first before trying to build anything,
				-- otherwise SimpleBuildOrder will always fail.
				local tooClose = false
				for fi = 1, #units do
					local candidate = units[fi]
					if candidate ~= unitID then
						local cDefID = Spring.GetUnitDefID(candidate)
						if cDefID and IsFactory[cDefID] then
							local fx, _, fz = Spring.GetUnitPosition(candidate)
							local fdx, fdz = ux - fx, uz - fz
							local ffoot = math.max(
									UnitDefs[cDefID].xsize,
									UnitDefs[cDefID].zsize) * 8 + 200
							if fdx * fdx + fdz * fdz < ffoot * ffoot then
								tooClose = true
								-- Walk in a random direction away from the factory
								local angle = math.random() * 6.28
								local dist  = ffoot + math.random(200, 500)
								local wx = fx + math.cos(angle) * dist
								local wz = fz + math.sin(angle) * dist
								wx = math.max(256, math.min(mapsizeX - 256, wx))
								wz = math.max(256, math.min(mapsizeZ - 256, wz))
								local wy = Spring.GetGroundHeight(wx, wz)
								Spring.GiveOrderToUnit(unitID, CMD.MOVE, { wx, wy, wz }, 0)
								break
							end
						end
					end
				end

				if not tooClose then
					SimpleConstructionProjectSelection(
							unitID, unitDefID, teamID, allyTeamID,
							units, allunits, "Builder")
				end
			end

			-- ======== FACTORIES ========
		else
			if unitCmds == 0 then
				SimpleConstructionProjectSelection(
						unitID, unitDefID, teamID, allyTeamID,
						units, allunits, "Factory")
			end
		end
	end

	return B
end
