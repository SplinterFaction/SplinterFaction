--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    luarules/configs/simpleai/behaviors/b_adaptive.lua
--  brief:   AdaptiveAI difficulty controller (order 5 -- runs before every
--           other behavior). For teams the core marked ctx.adaptiveTeams,
--           this module measures how the game is going for the OPPOSITION
--           (army value, kill/loss exchange, economy, base pressure), blends
--           that into a "player dominance" estimate, and steers a difficulty
--           scalar D in [0,1] so that the AI stays slightly AHEAD of the
--           player, by the adaptiveai_edge modoption (0 = an even game). It
--           used to aim for the opposite, the player slightly ahead. D is
--           mapped onto a knob table other behaviors consume:
--
--             tick.knobs                    (set every team tick; nil for
--                                            plain SimpleAI teams -> stock)
--             services.GetKnobs(teamID)     (same table, for call sites that
--                                            have no tick, e.g. the shared
--                                            construction selector)
--
--           Knob semantics: D = 0.5 reproduces STOCK SimpleAI values exactly
--           (every knob is a three-anchor lerp low/stock/high), so mid
--           difficulty IS today's SimpleAI. Below 0.5 the AI paces slower,
--           launches smaller sloppier waves, aims at the enemy centroid
--           instead of weak points, lets wounded units fight on, never
--           boosts, and builds slower. Above 0.5 all of that sharpens, and
--           its factories/constructors physically build faster via
--           Spring.SetUnitBuildSpeed.
--
--           The controller is smoothed but leans forward:
--             * 3-minute warmup before D moves at all (no signal yet)
--             * EMA smoothing + a deadband so it does not twitch
--             * per-update step clamps, ASYMMETRIC: it hardens twice as fast
--               as it eases, since this AI is meant to set the pace. (When
--               the target was a player edge it was the other way round.)
--
--           Modoptions (ModOptions.lua, "AI Opponent Options"):
--             adaptiveai_start  starting D, 0..1 (0.5 = plain SimpleAI)
--             adaptiveai_edge   how far ahead the AI tries to stay, 0..0.5
--             adaptiveai_aggression  temperament, 0..1
--           These three set up the plain AdaptiveAI only. The easier
--           variants (AdaptiveAIRelaxed, AdaptiveAIEasy, AdaptiveAIBeginner:
--           see VARIANTS below, and LuaAI.lua) carry their own fixed values.
--
--           Owns ctx state: none (all controller state is module-local;
--           the only shared surfaces are tick.knobs / services.GetKnobs).
--           Reads: ctx.adaptiveTeams (written by the core at detection),
--                  ctx.IsCombat / IsFactory / IsConstructor / IsCommander,
--                  tick.allUnits / tick.mInc / tick.units.
--           Hooks consumed from the core: TeamInit, TeamTick, BaseDamaged,
--                  UnitLost, UnitKilled, UnitFinished.
--
--           Debug: publishes game rules params per adaptive team --
--             adaptiveai_d_<teamID>    current difficulty (0..1)
--             adaptiveai_dom_<teamID>  smoothed player-dominance (-1..1)
--             adaptiveai_aggr_<teamID> aggression (0..1, the adaptiveai_aggression modoption)
--
--  usage:   VFS.Include(path)(ctx, lib, cfg, services) -> handler table
--
--  license: GNU GPL, v2 or later
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return function(ctx, lib, cfg, services)

	--------------------------------------------------------------------------
	-- Tunables (owned by this behavior)
	--------------------------------------------------------------------------
	-- Controller cadence / dynamics
	local UPDATE_INTERVAL = 900    -- frames between controller updates (~30s)
	local WARMUP_FRAMES   = 5400   -- no D movement before this (~3 min): too little signal
	-- Dominance is positive when the PLAYER is ahead. The target is negative:
	-- the AI stays ahead by the adaptiveai_edge modoption (default 0.15, about
	-- 57/43 in its favour; 0 = an even game).
	local TARGET_DOM      = -0.15
	do
		local mo = Spring.GetModOptions and Spring.GetModOptions()
		local v  = mo and tonumber(mo.adaptiveai_edge)
		if v then TARGET_DOM = -math.max(0, math.min(0.5, v)) end
	end
	local DEADBAND        = 0.06   -- |dominance - target| inside this -> no step at all
	local GAIN            = 0.15   -- step per unit of error beyond the deadband
	local MAX_STEP_UP     = 0.07   -- max D increase per update: it HARDENS twice as fast...
	local MAX_STEP_DOWN   = 0.035  -- ...as it eases (see brief)
	local STEP_REF        = 0.035  -- a step cap of this size steers with GAIN x1; bigger caps steer harder in proportion
	local EMA_KEEP        = 0.6    -- dominance smoothing: new = old*KEEP + raw*(1-KEEP)

	-- Signal weights (must sum to 1). Army value dominates because it is the
	-- most direct "who is winning" reading; exchange captures skill even when
	-- totals are close; economy leads army by a couple of minutes; pressure
	-- (our base taking hits) is the lagging confirmation.
	local W_ARMY  = 0.40
	local W_EXCH  = 0.25
	local W_ECO   = 0.20
	local W_PRESS = 0.15

	-- Exchange accumulators decay each update (~3.3 min half-life at 0.90),
	-- so an early slaughter stops steering D fifteen minutes later.
	local EXCH_DECAY      = 0.90
	local PRESSURE_MEMORY = 1800   -- frames a base hit keeps the pressure signal warm (~60s)

	-- Build-speed application is quantized so we only sweep the team's units
	-- when the multiplier moves a real step, not on every controller nudge.
	local BS_QUANT = 0.05

	-- Starting difficulty; optionally overridden by the adaptiveai_start
	-- modoption (a number 0..1). 0.5 == stock SimpleAI strength; the modoption
	-- defaults to 0.6 so the AI opens with a small head start.
	local D_START = 0.6
	do
		local mo = Spring.GetModOptions and Spring.GetModOptions()
		local v  = mo and tonumber(mo.adaptiveai_start)
		if v then D_START = math.max(0, math.min(1, v)) end
	end

	-- Aggression (modoption adaptiveai_aggression, 0..1): how willing the team
	-- is to attack and to see an attack through, whatever it costs. It does
	-- not move with the game and is separate from difficulty: D is how well the
	-- AI plays, aggression is its temperament. 0.5 is exactly the stock
	-- behaviour (every aggression knob is a three-anchor lerp around the
	-- b_combat constant); below it the team wants a bigger edge and pulls back
	-- sooner, above it the team attacks on less, stays in a fight it is locally
	-- losing, and holds the field for as long as the trade is going its way.
	local AGGRESSION = 0.7
	do
		local mo = Spring.GetModOptions and Spring.GetModOptions()
		local v  = mo and tonumber(mo.adaptiveai_aggression)
		if v then AGGRESSION = math.max(0, math.min(1, v)) end
	end

	--------------------------------------------------------------------------
	-- Profiles. The plain AdaptiveAI is set up by the modoptions above. The
	-- variants are the same controller, tuned down and fixed: the modoptions do
	-- not reach them, so one game can hold several of them side by side.
	--   start      D at game start
	--   target     the player dominance it steers for (negative: AI ahead,
	--              0: an even game, positive: the player ahead)
	--   aggression temperament, as the modoption
	--   dMax       D never rises above this, however far ahead the player gets
	--   stepUp / stepDown   most D can move per update, harder / easier
	-- The key is the LuaAI name (LuaAI.lua); it has to begin with "AdaptiveAI",
	-- which is what the core and ai_neverstall look for.
	--------------------------------------------------------------------------
	local DEFAULT_PROFILE = {
		start = D_START, target = TARGET_DOM, aggression = AGGRESSION,
		dMax = 1, stepUp = MAX_STEP_UP, stepDown = MAX_STEP_DOWN,
	}
	local VARIANTS = {
		-- an even game, stock temperament, stops short of its best play
		AdaptiveAIRelaxed  = { start = 0.50, target = 0.00, aggression = 0.50, dMax = 0.75, stepUp = 0.05,  stepDown = 0.05 },
		-- lets the player keep a small lead, never plays above plain SimpleAI
		AdaptiveAIEasy     = { start = 0.35, target = 0.10, aggression = 0.35, dMax = 0.55, stepUp = 0.035, stepDown = 0.07 },
		-- lets the player keep a clear lead, slow and timid throughout
		AdaptiveAIBeginner = { start = 0.15, target = 0.20, aggression = 0.15, dMax = 0.35, stepUp = 0.02,  stepDown = 0.07 },
	}

	-- name is the team's LuaAI name; the longest variant name it begins with wins
	local function ProfileFor(name)
		local best, bestLen = DEFAULT_PROFILE, 0
		if type(name) == "string" then
			for key, p in pairs(VARIANTS) do
				local n = #key
				if n > bestLen and string.sub(name, 1, n) == key then
					best, bestLen = p, n
				end
			end
		end
		return best
	end

	--------------------------------------------------------------------------
	-- Shared state / config
	--------------------------------------------------------------------------
	local gaiaTeamID    = cfg.gaiaTeamID

	local AdaptiveTeams = ctx.adaptiveTeams
	local IsCombat      = ctx.IsCombat
	local IsFactory     = ctx.IsFactory
	local IsConstructor = ctx.IsConstructor
	local IsCommander   = ctx.IsCommander

	--------------------------------------------------------------------------
	-- Module-local controller state (all keyed by teamID unless noted)
	--------------------------------------------------------------------------
	local D           = {}   -- difficulty scalar in [0, profile.dMax]
	local profile     = {}   -- the team's profile (DEFAULT_PROFILE or one of VARIANTS)
	local dom         = {}   -- EMA-smoothed player dominance in [-1,1]
	local knobs       = {}   -- derived knob table (mutated in place; consumers may cache it)
	local lastUpdate  = {}   -- frame of last controller update
	local killedVal   = {}   -- decayed metal value of enemy units this team destroyed
	local lostVal     = {}   -- decayed metal value of own units lost to enemies
	local lastBaseHit = {}   -- frame an enemy last damaged one of our buildings
	local appliedBS   = {}   -- quantized build-speed multiplier currently applied (1.0 = untouched)
	local enemySet    = {}   -- [teamID] = { [enemyTeamID]=true }; teams are fixed at game start
	local baseSpeed   = {}   -- [defID] = stock UnitDef buildSpeed (lazy cache)
	local metalCost   = {}   -- [defID] = stock UnitDef metalCost  (lazy cache)

	--------------------------------------------------------------------------
	-- Small helpers
	--------------------------------------------------------------------------
	local function Clamp01(v)
		if v < 0 then return 0 elseif v > 1 then return 1 end
		return v
	end

	-- Three-anchor lerp: d=0 -> lo, d=0.5 -> mid, d=1 -> hi. Anchoring the
	-- midpoint at each knob's STOCK value is what makes D=0.5 exactly today's
	-- SimpleAI -- keep that property when retuning: change lo/hi, not mid.
	local function Tri(lo, mid, hi, d)
		if d <= 0.5 then
			return lo + (mid - lo) * (d * 2)
		end
		return mid + (hi - mid) * ((d - 0.5) * 2)
	end

	local function Round(v)
		return math.floor(v + 0.5)
	end

	local function MetalCost(defID)
		local c = metalCost[defID]
		if c == nil then
			local ud = UnitDefs[defID]
			c = (ud and ud.metalCost) or 1
			metalCost[defID] = c
		end
		return c
	end

	local function BaseSpeed(defID)
		local s = baseSpeed[defID]
		if s == nil then
			local ud = UnitDefs[defID]
			s = (ud and ud.buildSpeed) or 0
			baseSpeed[defID] = s
		end
		return s
	end

	local function IsBuilderDef(defID)
		return IsFactory[defID] or IsConstructor[defID] or IsCommander[defID]
	end

	-- Enemy team set, built once per team on first use (team lists are fixed
	-- for the whole game in Recoil, so no refresh is needed).
	local function EnemySet(teamID)
		local set = enemySet[teamID]
		if set then return set end
		set = {}
		local all = Spring.GetTeamList()
		for i = 1, #all do
			local t = all[i]
			if t ~= teamID and t ~= gaiaTeamID
					and not Spring.AreTeamsAllied(teamID, t) then
				set[t] = true
			end
		end
		enemySet[teamID] = set
		return set
	end

	--------------------------------------------------------------------------
	-- Knob derivation. Every knob's MID anchor is the stock SimpleAI value
	-- from the owning behavior -- keep these in sync if those constants move:
	--   b_combat:       WAVE_COOLDOWN 1500, WAVE_MUSTER_SIZE 4,
	--                   WAVE_BIG_ARMY 9, ATTACK_RETARGET 300, RETREAT_ENTER 0.50
	--   b_construction: pacing multiplier (CON_BUILD_SPACING / FACTORY_SPACING*)
	--   b_economy:      boost allowed
	--   b_upgrades:     UPGRADE_COOLDOWN multiplier
	--------------------------------------------------------------------------
	local function RecomputeKnobs(teamID)
		local d = D[teamID]
		local k = knobs[teamID]
		k.buildSpeedMult   = Tri(0.65, 1.0, 1.5, d)    -- SetUnitBuildSpeed on builders (hi was 1.35; more room to pull ahead)
		k.waveCooldown     = Round(Tri(2700, 1500, 1000, d))
		k.musterSize       = Round(Tri(2, 4, 7, d))
		k.bigArmy          = Round(Tri(5, 9, 15, d))
		k.retargetInterval = Round(Tri(600, 300, 240, d))
		k.weakTargeting    = d >= 0.35                 -- below: dumb centroid attacks
		k.retreatEnter     = Tri(0.20, 0.50, 0.55, d)  -- low D units fight nearly to death
		k.pacingMult       = Tri(1.6, 1.0, 0.75, d)    -- constructor/factory start spacing
		k.boostAllowed     = d >= 0.40                 -- low D never spends RP on boosts
		k.upgradeCdMult    = Tri(3.0, 1.0, 0.7, d)     -- weapons/armor purchase cadence

		-- Aggression knobs (b_combat). Mid anchors are b_combat's constants:
		--   LAUNCH_RATIO x1, WAVE_PATIENCE x1, PATIENCE_RATIO 0.9, WAVE_BREAK 0.35,
		--   OUTMATCH_RATIO 0.6, OUTMATCH_TICKS 2, RETREAT_ENTER x1 (wave members),
		--   REINFORCE_HEALTH 0.6, REINFORCE_SHARE 0.5, WAVE_REGROUP_BEATEN 1800,
		--   RAID.FLEE_RATIO 1.5
		local a = profile[teamID].aggression
		k.aggression       = a
		k.launchMult       = Tri(1.5, 1.0, 0.5, a)     -- x the edge a launch waits for
		k.patienceMult     = Tri(1.75, 1.0, 0.4, a)    -- x how long a gathered army waits for that edge
		k.patienceRatio    = Tri(1.0, 0.9, 0.5, a)     -- share of the enemy's army a patience launch still needs
		k.waveBreak        = Tri(0.50, 0.35, 0.10, a)  -- wave called home at this share of what set out
		k.outmatchRatio    = Tri(0.8, 0.6, 0.25, a)    -- locally outmatched below this x the enemy there
		k.outmatchTicks    = Round(Tri(1, 2, 6, a))    -- ...for this many ticks running
		-- Above stock only: a wave that would be called home stays out while what
		-- it has killed is worth at least this x what it has lost.
		k.tradeHold        = (a > 0.5) and (1.6 - (a - 0.5) * 2.0) or nil   -- 1.6 just above stock .. 0.6 at 1
		k.waveRetreatMult  = Tri(1.3, 1.0, 0.3, a)     -- x the hp at which a wave member breaks off
		k.reinforceHealth  = Tri(0.75, 0.6, 0.3, a)
		k.reinforceShare   = Tri(0.6, 0.5, 0.25, a)
		k.regroupBeaten    = Round(Tri(2700, 1800, 750, a))
		k.raidFlee         = Tri(1.2, 1.5, 2.5, a)
	end

	local function PublishDebug(teamID)
		Spring.SetGameRulesParam("adaptiveai_d_" .. teamID,
		                         Round(D[teamID] * 1000) / 1000)
		Spring.SetGameRulesParam("adaptiveai_dom_" .. teamID,
		                         Round((dom[teamID] or 0) * 1000) / 1000)
		Spring.SetGameRulesParam("adaptiveai_aggr_" .. teamID, profile[teamID].aggression)
	end

	--------------------------------------------------------------------------
	-- Build-speed application
	--------------------------------------------------------------------------
	local function ApplySpeed(unitID, unitDefID, mult)
		if IsBuilderDef(unitDefID) then
			local bs = BaseSpeed(unitDefID)
			if bs > 0 then
				Spring.SetUnitBuildSpeed(unitID, bs * mult)
			end
		end
	end

	local B = { name = "adaptive", order = 5 }

	function B.TeamInit(teamID)
		if not AdaptiveTeams[teamID] then return end
		local p = ProfileFor(AdaptiveTeams[teamID])
		profile[teamID]     = p
		D[teamID]           = math.min(p.start, p.dMax)
		dom[teamID]         = p.target     -- start AT target: no phantom step after warmup
		knobs[teamID]       = {}
		lastUpdate[teamID]  = 0
		killedVal[teamID]   = 0
		lostVal[teamID]     = 0
		lastBaseHit[teamID] = nil
		appliedBS[teamID]   = 1.0          -- 1.0 == "no unit has been touched yet"
		RecomputeKnobs(teamID)
		PublishDebug(teamID)
	end

	-- Shared service: knob access for call sites that have no tick in hand
	-- (b_construction's shared selector). Returns nil for non-adaptive teams,
	-- which every consumer treats as "use stock values".
	services.GetKnobs = function(teamID)
		return knobs[teamID]
	end

	--------------------------------------------------------------------------
	-- Per-team tick. ALWAYS stamps tick.knobs (nil for non-adaptive teams) --
	-- tick is a shared table reused across teams, so skipping the stamp would
	-- leak the previous team's knobs into this one.
	--------------------------------------------------------------------------
	function B.TeamTick(tick)
		local teamID = tick.teamID
		local k      = knobs[teamID]
		tick.knobs   = k
		if not k then return end

		local n = tick.frame

		-- ---- Build-speed sweep on band change ----
		-- Quantize so we only touch units when the multiplier moved a real
		-- step. New builders finished between sweeps are caught by the
		-- UnitFinished hook below.
		local q = Round(k.buildSpeedMult / BS_QUANT) * BS_QUANT
		if q ~= appliedBS[teamID] then
			local units = tick.units
			for i = 1, #units do
				local uid    = units[i]
				local uDefID = Spring.GetUnitDefID(uid)
				if uDefID then
					ApplySpeed(uid, uDefID, q)
				end
			end
			appliedBS[teamID] = q
		end

		-- ---- Controller update, every UPDATE_INTERVAL frames ----
		if (n - (lastUpdate[teamID] or 0)) < UPDATE_INTERVAL then return end
		lastUpdate[teamID] = n

		-- Decay the exchange accumulators BEFORE reading them, so old
		-- slaughters fade at a fixed rate regardless of new activity.
		killedVal[teamID] = killedVal[teamID] * EXCH_DECAY
		lostVal[teamID]   = lostVal[teamID]   * EXCH_DECAY

		-- ---- Signal 1: fielded army value, ours vs all enemies ----
		-- tick.allUnits is the core's once-per-tick snapshot; classification
		-- and cost caches are defID-keyed so enemy units are covered too.
		local eset     = EnemySet(teamID)
		local aV, eV   = 0, 0
		local allunits = tick.allUnits
		for i = 1, #allunits do
			local uid = allunits[i]
			local ut  = Spring.GetUnitTeam(uid)
			if ut == teamID or eset[ut] then
				local dID = Spring.GetUnitDefID(uid)
				if dID and IsCombat[dID] then
					local c = MetalCost(dID)
					if ut == teamID then aV = aV + c else eV = eV + c end
				end
			end
		end
		local armyS = 0
		if aV + eV > 0 then armyS = (eV - aV) / (eV + aV) end

		-- ---- Signal 2: kill/loss value exchange ----
		local kd, ls = killedVal[teamID], lostVal[teamID]
		local exchS  = 0
		if kd + ls > 50 then   -- ignore noise until real value has traded
			exchS = (ls - kd) / (ls + kd)
		end

		-- ---- Signal 3: metal income, ours vs all enemies summed ----
		-- The resource FLOOR (core) tops up STOCK, not income, so this stays
		-- a true reading of production on both sides.
		local aI = tick.mInc or 0
		local eI = 0
		for t in pairs(eset) do
			local _, _, _, inc = Spring.GetTeamResources(t, "metal")
			eI = eI + (inc or 0)
		end
		local ecoS = 0
		if aI + eI > 0 then ecoS = (eI - aI) / (eI + aI) end

		-- ---- Signal 4: pressure on our base ----
		local pressS = 0
		local hit = lastBaseHit[teamID]
		if hit then
			pressS = Clamp01(1 - (n - hit) / PRESSURE_MEMORY)
		end

		-- ---- Blend + smooth ----
		local raw = W_ARMY * armyS + W_EXCH * exchS + W_ECO * ecoS + W_PRESS * pressS
		dom[teamID] = dom[teamID] * EMA_KEEP + raw * (1 - EMA_KEEP)

		-- ---- Steer D (after warmup) ----
		if n >= WARMUP_FRAMES then
			local p    = profile[teamID]
			local err  = dom[teamID] - p.target
			local step = 0
			if err > DEADBAND then
				-- Player doing better than the target: get harder (the plain
				-- AdaptiveAI quickly, the easier variants less so).
				step = math.min(p.stepUp, (err - DEADBAND) * GAIN * (p.stepUp / STEP_REF))
			elseif err < -DEADBAND then
				-- AI doing better than the target: ease off.
				step = math.max(-p.stepDown, (err + DEADBAND) * GAIN * (p.stepDown / STEP_REF))
			end
			if step ~= 0 then
				local d = math.min(p.dMax, Clamp01(D[teamID] + step))
				if d ~= D[teamID] then
					D[teamID] = d
					RecomputeKnobs(teamID)
				end
			end
		end

		PublishDebug(teamID)
	end

	--------------------------------------------------------------------------
	-- Event hooks (dispatched by the core)
	--------------------------------------------------------------------------
	-- One of OUR units died to an enemy -> loss value. Weighted by build
	-- progress so a sniped nano-frame is a small loss, not a full one.
	function B.UnitLost(teamID, unitID, unitDefID)
		if not knobs[teamID] then return end
		local _, _, _, _, bp = Spring.GetUnitHealth(unitID)
		lostVal[teamID] = lostVal[teamID] + MetalCost(unitDefID) * (bp or 1)
	end

	-- We destroyed an enemy unit -> kill value, same progress weighting.
	function B.UnitKilled(teamID, unitID, unitDefID)
		if not knobs[teamID] then return end
		local _, _, _, _, bp = Spring.GetUnitHealth(unitID)
		killedVal[teamID] = killedVal[teamID] + MetalCost(unitDefID) * (bp or 1)
	end

	-- An enemy damaged one of our buildings (same event b_combat fast-tracks
	-- waves on): warm the pressure signal.
	function B.BaseDamaged(teamID, frame)
		if not knobs[teamID] then return end
		lastBaseHit[teamID] = frame
	end

	-- A unit of ours finished (or was given to us): if the team's build-speed
	-- band is off stock, stamp new builders immediately so they don't run at
	-- base speed until the next band change.
	function B.UnitFinished(unitID, unitDefID, teamID)
		local k = knobs[teamID]
		if not k then return end
		local q = appliedBS[teamID]
		if q and q ~= 1.0 then
			ApplySpeed(unitID, unitDefID, q)
		end
	end

	return B
end
