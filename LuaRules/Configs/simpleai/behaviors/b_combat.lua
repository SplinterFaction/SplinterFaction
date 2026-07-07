--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    luarules/configs/simpleai/behaviors/b_combat.lua
--  brief:   Combat behavior for the SimpleAI gadget (stage 3 of the modular
--           split). Owns everything about fielding an army: the muster point,
--           the ground census, squad state transitions and wave launches,
--           per-unit retreat hysteresis, and air/ground unit orders.
--
--           Owns ctx state: ctx.squad.*, ctx.pacing.lastLaunch,
--           ctx.pacing.lastTargetScan, ctx.retreat.
--           Reads (never writes): ctx.intel.*, classification tables.
--
--  usage:   VFS.Include(path)(ctx, lib, cfg) -> handler table
--           Handlers the core dispatches to:
--             unitFilter(unitDefID)          which units this behavior owns
--             TeamTick(tick)                 once per AI team tick
--             UnitTick(tick, unitID, ...)    per owned unit
--             BaseDamaged(teamID, frame)     enemy damaged one of our buildings
--
--  license: GNU GPL, v2 or later
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return function(ctx, lib, cfg)

	--------------------------------------------------------------------------
	-- Tunables (owned by this behavior)
	--------------------------------------------------------------------------
	local WAVE_MIN_ARMY     = 4      -- minimum combat units before attacking
	local WAVE_MUSTER_SIZE  = 4      -- units that must be at muster point to trigger launch
	local WAVE_BIG_ARMY     = 9      -- if we have this many ground units, attack even if not fully mustered
	local MUSTER_RADIUS     = 600    -- how close a unit must be to count as "at muster"
	local WAVE_COOLDOWN     = 1500   -- minimum frames between launches (~50s at 30Hz)
	local ATTACK_RETARGET   = 300    -- frames between weak-point re-scans during an active push

	-- Retreat hysteresis, on EFFECTIVE hp: (hull + shield) / (maxHull + maxShield).
	-- SF has no repair. Fed hulls autoheal; Loz hulls never recover but their shield
	-- (up to half their pool) does. A single threshold on raw hull therefore benches
	-- Loz units forever. Instead: enter retreat low, exit when recovered ENOUGH --
	-- where "enough" for Loz is a full shield (the best that unit will ever be again).
	local RETREAT_ENTER     = 0.50   -- effective-hp fraction that triggers retreat
	local RETREAT_EXIT      = 0.75   -- effective-hp fraction that ends retreat (Fed heals to this)
	local RETREAT_TIMEOUT   = 750    -- frames (~25s); catch-all exit so nothing wedges

	--------------------------------------------------------------------------
	-- Shared state / config
	--------------------------------------------------------------------------
	local mapsizeX = cfg.mapsizeX
	local mapsizeZ = cfg.mapsizeZ

	local IsCombat  = ctx.IsCombat
	local IsAir     = ctx.IsAir
	local ShieldMax = ctx.ShieldMax

	local SimpleRetreatState   = ctx.retreat
	local SimpleMusterPos      = ctx.squad.muster
	local SimpleSquadState     = ctx.squad.state
	local SimpleAttackWave     = ctx.squad.attackWave
	local SimpleLastLaunch     = ctx.pacing.lastLaunch
	local SimpleLastTargetScan = ctx.pacing.lastTargetScan
	local SimpleUnderAttack    = ctx.intel.underAttack
	local SimpleEnemyBasePos   = ctx.intel.enemyBase
	local SimpleBaseThreat     = ctx.intel.baseThreat

	local FindWeakestEnemyTarget = lib.FindWeakestEnemyTarget
	local ComputeMusterPos       = lib.ComputeMusterPos

	local B = { name = "combat", order = 50 }

	function B.TeamInit(teamID)
		SimpleMusterPos[teamID]      = nil   -- set when first factory/commander known
		SimpleSquadState[teamID]     = "mustering"
		SimpleAttackWave[teamID]     = nil
		SimpleLastLaunch[teamID]     = 0
		SimpleLastTargetScan[teamID] = 0
	end

	--------------------------------------------------------------------------
	-- Ownership: all combat units, air and ground.
	--------------------------------------------------------------------------
	function B.unitFilter(unitDefID)
		return IsCombat[unitDefID] == true
	end

	--------------------------------------------------------------------------
	-- Per-team tick: muster point, ground census, squad state transitions.
	-- Writes tick.muster / tick.atMuster / tick.totalGround / tick.readyGround
	-- for anything downstream.
	--------------------------------------------------------------------------
	function B.TeamTick(tick)
		local n      = tick.frame
		local teamID = tick.teamID
		local units  = tick.units

		-- ---- Muster point: compute/refresh every ~40s or if unset ----
		if not SimpleMusterPos[teamID] or n % 2400 == 0 then
			SimpleMusterPos[teamID] = ComputeMusterPos(teamID)
		end
		local muster = SimpleMusterPos[teamID]
		tick.muster = muster

		-- Count ground combat units. Units in retreat are counted in
		-- totalGround but NOT in readyGround/atMuster: the recovering
		-- garrison must not inflate launch math, or waves fire with
		-- fewer real attackers than the numbers claim.
		local atMuster    = 0
		local totalGround = 0
		local readyGround = 0
		if muster then
			for k = 1, #units do
				local uid    = units[k]
				local uDefID = Spring.GetUnitDefID(uid)
				if uDefID and IsCombat[uDefID] and not IsAir[uDefID] then
					totalGround = totalGround + 1
					if not SimpleRetreatState[uid] then
						readyGround = readyGround + 1
						local ux2, _, uz2 = Spring.GetUnitPosition(uid)
						local dx2 = ux2 - muster.x
						local dz2 = uz2 - muster.z
						if dx2*dx2 + dz2*dz2 < MUSTER_RADIUS * MUSTER_RADIUS then
							atMuster = atMuster + 1
						end
					end
				end
			end
		end
		tick.atMuster    = atMuster
		tick.totalGround = totalGround
		tick.readyGround = readyGround

		local baseThreat = tick.baseThreat

		-- Squad state transitions
		-- Launch when a wave has mustered, OR when we already have a big
		-- army (don't sit forever waiting for perfect muster), OR when
		-- the base is under attack and we have at least a token force.
		-- An active base intruder suppresses outward launches so the home
		-- guard stays to deal with it instead of marching off.
		local cooldownOk    = (n - SimpleLastLaunch[teamID]) >= WAVE_COOLDOWN
		local readyToLaunch = cooldownOk and not baseThreat
				and (atMuster >= WAVE_MUSTER_SIZE or readyGround >= WAVE_BIG_ARMY)
				and readyGround >= WAVE_MIN_ARMY
		local forceAttack   = SimpleUnderAttack[teamID] and not baseThreat
				and readyGround >= 3
				and (n - SimpleLastLaunch[teamID] >= WAVE_COOLDOWN / 2)

		if (readyToLaunch or forceAttack)
				and SimpleSquadState[teamID] == "mustering" then
			SimpleSquadState[teamID] = "attacking"
			SimpleLastLaunch[teamID] = n
			SimpleLastTargetScan[teamID] = n
			-- Aim at the WEAKEST-defended enemy structure, not the
			-- centre of mass (which is usually the most fortified spot).
			local target = FindWeakestEnemyTarget(teamID)
					or SimpleEnemyBasePos[teamID]
					or {
						x = mapsizeX / 2 + math.random(-500, 500),
						z = mapsizeZ / 2 + math.random(-500, 500),
						y = Spring.GetGroundHeight(mapsizeX / 2, mapsizeZ / 2),
					}
			SimpleAttackWave[teamID] = target
			-- Issue FIGHT to all non-retreating ground units simultaneously
			for k = 1, #units do
				local uid    = units[k]
				local uDefID = Spring.GetUnitDefID(uid)
				if uDefID and IsCombat[uDefID] and not IsAir[uDefID] then
					if not SimpleRetreatState[uid] then
						Spring.GiveOrderToUnit(uid, CMD.FIGHT,
						                       { target.x + math.random(-200, 200),
						                         target.y,
						                         target.z + math.random(-200, 200) },
						                       { "shift", "alt", "ctrl" })
					end
				end
			end
		end

		-- While pushing, periodically re-scan for the softest target so
		-- the wave rolls onto fresh weak points as defences collapse.
		if SimpleSquadState[teamID] == "attacking"
				and (n - SimpleLastTargetScan[teamID]) >= ATTACK_RETARGET then
			SimpleLastTargetScan[teamID] = n
			local newTarget = FindWeakestEnemyTarget(teamID)
			if newTarget then SimpleAttackWave[teamID] = newTarget end
		end

		-- Return to mustering when army is spent
		if SimpleSquadState[teamID] == "attacking" and readyGround < 3 then
			SimpleSquadState[teamID] = "mustering"
			SimpleAttackWave[teamID]  = nil
		end
	end

	--------------------------------------------------------------------------
	-- Per-unit orders for owned (combat) units.
	--------------------------------------------------------------------------
	function B.UnitTick(tick, unitID, unitDefID, hpRatio, ux, uy, uz, unitCmds)
		local n          = tick.frame
		local teamID     = tick.teamID
		local allyTeamID = tick.allyTeamID
		local muster     = tick.muster
		local luaAI      = tick.luaAI
		local allunits   = tick.allUnits

		-- AIR: always independent, hunt nearest enemy
		if IsAir[unitDefID] then
			if unitCmds == 0 then
				local target = Spring.GetUnitNearestEnemy(unitID, 999999, false)
				if target then
					local tx, ty, tz = Spring.GetUnitPosition(target)
					Spring.GiveOrderToUnit(unitID, CMD.FIGHT,
					                       { tx + math.random(-80, 80), ty,
					                         tz + math.random(-80, 80) },
					                       { "shift", "alt", "ctrl" })
				end
			end

			-- DEFENDER AI: patrol near ally structures
		elseif string.sub(luaAI, 1, 16) == 'SimpleDefenderAI' then
			if unitCmds == 0 then
				for t = 1, 10 do
					local target = allunits[math.random(1, #allunits)]
					if Spring.GetUnitAllyTeam(target) == allyTeamID then
						local tx, ty, tz = Spring.GetUnitPosition(target)
						Spring.GiveOrderToUnit(unitID, CMD.FIGHT,
						                       { tx + math.random(-100, 100), ty,
						                         tz + math.random(-100, 100) },
						                       { "shift", "alt", "ctrl" })
						break
					end
				end
			end

			-- GROUND / SEA: squad staging system
		else
			-- ---- Retreat hysteresis ----
			-- Enter low on EFFECTIVE hp; exit on recovery,
			-- full shield (Loz's ceiling: hull never heals,
			-- so a topped-off shield means this unit is as
			-- good as it will ever get -- field it), or a
			-- timeout so nothing can wedge in retreat.
			local retreatFrame = SimpleRetreatState[unitID]
			if retreatFrame then
				local exitNow = hpRatio >= RETREAT_EXIT
						or (n - retreatFrame) >= RETREAT_TIMEOUT
				if not exitNow then
					local smax = ShieldMax[unitDefID]
					if smax then
						local s = Spring.GetUnitRulesParam(
								unitID, "personalShield") or 0
						if s >= smax then exitNow = true end
					end
				end
				if exitNow then
					SimpleRetreatState[unitID] = nil
					retreatFrame = nil
				end
			elseif hpRatio < RETREAT_ENTER then
				-- Enter retreat: break off IMMEDIATELY
				-- (replace the queue; a unit this hurt must
				-- not finish walking a FIGHT queue first).
				SimpleRetreatState[unitID] = n
				retreatFrame = n
				if muster then
					Spring.GiveOrderToUnit(unitID, CMD.MOVE,
					                       { muster.x + math.random(-100, 100),
					                         muster.y,
					                         muster.z + math.random(-100, 100) }, 0)
				end
			end

			if retreatFrame then
				-- Holding: if idle and drifted from muster,
				-- head back. Otherwise sit and recover.
				if unitCmds == 0 and muster and retreatFrame ~= n then
					local rdx = ux - muster.x
					local rdz = uz - muster.z
					if rdx * rdx + rdz * rdz
							> MUSTER_RADIUS * MUSTER_RADIUS then
						Spring.GiveOrderToUnit(unitID, CMD.MOVE,
						                       { muster.x + math.random(-100, 100),
						                         muster.y,
						                         muster.z + math.random(-100, 100) }, 0)
					end
				end

			elseif SimpleSquadState[teamID] == "attacking" then
				-- Attack mode: push to wave target or engage nearby foes
				if unitCmds == 0 then
					local wave = SimpleAttackWave[teamID]
					local nearEnemy = Spring.GetUnitNearestEnemy(
							unitID, 1500, false)
					if nearEnemy then
						local tx, ty, tz = Spring.GetUnitPosition(nearEnemy)
						Spring.GiveOrderToUnit(unitID, CMD.FIGHT,
						                       { tx + math.random(-60, 60), ty,
						                         tz + math.random(-60, 60) },
						                       { "shift", "alt", "ctrl" })
					elseif wave then
						Spring.GiveOrderToUnit(unitID, CMD.FIGHT,
						                       { wave.x + math.random(-150, 150),
						                         wave.y,
						                         wave.z + math.random(-150, 150) },
						                       { "shift", "alt", "ctrl" })
					end
				end

			else
				-- Muster / home-guard mode.
				local bthreat = SimpleBaseThreat[teamID]
				if bthreat then
					-- Intruder in the base: lock onto the specific unit so we
					-- chase and kill it instead of strolling past. ATTACK on the
					-- unitID tracks it if it moves. Only (re)issue if we are not
					-- already on this exact target, to avoid order thrashing.
					local cmds  = Spring.GetCommandQueue(unitID, 1)
					local first = cmds and cmds[1]
					local onIt  = first and first.id == CMD.ATTACK
					    and first.params and first.params[1] == bthreat.uid
					if not onIt then
						Spring.GiveOrderToUnit(unitID, CMD.ATTACK, { bthreat.uid }, 0)
					end
				else
					-- No intruder: attack-move to the staging area so we engage
					-- anything we pass on the way. (Plain MOVE used to ignore
					-- enemies en route, which is why units walked past raiders.)
					local nearEnemy = Spring.GetUnitNearestEnemy(unitID, 600, true)
					if nearEnemy and unitCmds == 0 then
						local tx, ty, tz = Spring.GetUnitPosition(nearEnemy)
						Spring.GiveOrderToUnit(unitID, CMD.FIGHT,
						                       { tx, ty, tz }, { "shift", "alt", "ctrl" })
						if muster then
							Spring.GiveOrderToUnit(unitID, CMD.FIGHT,
							                       { muster.x + math.random(-150, 150),
							                         muster.y,
							                         muster.z + math.random(-150, 150) },
							                       { "shift" })
						end
					elseif unitCmds == 0 and muster then
						Spring.GiveOrderToUnit(unitID, CMD.FIGHT,
						                       { muster.x + math.random(-200, 200),
						                         muster.y,
						                         muster.z + math.random(-200, 200) }, 0)
					end
				end
			end
		end
	end

	--------------------------------------------------------------------------
	-- An enemy damaged one of our buildings: fast-track the next wave by
	-- reducing the REMAINING cooldown to at most half. min() against the
	-- CURRENT frame keeps this idempotent under sustained fire.
	--------------------------------------------------------------------------
	function B.BaseDamaged(teamID, frame)
		SimpleLastLaunch[teamID] = math.min(SimpleLastLaunch[teamID] or 0,
		                                    frame - WAVE_COOLDOWN / 2)
	end

	return B
end
