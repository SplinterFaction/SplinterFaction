--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    game_researchpoints_ledger.lua
--  brief:   Source-agnostic Research Point economy. Owns the per-team RP balance
--           and exposes GG.Research { Get, CanAfford, Add, Spend } to the rest of
--           the codebase. Income sources (passive tick, kills, generators, ...)
--           only ever call GG.Research.Add; consumers (unit_morph) call Spend.
--           The ledger never branches on where points came from.
--  author:  SF
--  license: GNU GPL, v2 or later
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name    = "Research Points Ledger",
    desc    = "Per-team Research Point ledger and income (GG.Research API)",
    author  = "SF",
    date    = "2026",
    license = "GNU GPL, v2 or later",
    layer   = 0,        -- loads before unit_morph (layer 500); not strictly required
    enabled = true,
  }
end

--------------------------------------------------------------------------------
-- Config (income sources are optional; set any to 0 to disable)
--------------------------------------------------------------------------------

local STARTING_POINTS      = 0      -- granted to every team at game start
local PASSIVE_PER_SECOND   = 1      -- the anti-lockout floor; 0 disables
local KILL_REWARD_FRACTION = 0.05   -- RP per kill = victim metalCost * this; 0 disables
local LOSS_REWARD_FRACTION = 0      -- "learn from your losses"; fraction of the kill reward
                                    -- granted to the team that LOST the unit; 0 disables

local RULES_PARAM = "researchPoints"          -- read with Spring.GetTeamRulesParam
local PARAM_OPTS  = { allied = true }         -- self + allies can read, enemies cannot

-- Generators: a building with this unit customParam produces that many research
-- points per second just by existing, while finished, switched on, and not stunned.
-- The gadget itself charges the energy upkeep (RP_ENERGY_PARAM, energy per second)
-- and only credits RP when the team can pay, so it stops when the team runs dry --
-- the same feel as metal makers. Put the energy cost in this customParam, NOT in
-- the unitdef's energyUse, or the team would be charged twice. Placement rules
-- (e.g. must sit on a geothermal vent) are enforced by other gadgets.
local RP_INCOME_PARAM = "rp_income"
local RP_ENERGY_PARAM = "rp_energy_cost"

--------------------------------------------------------------------------------

if not gadgetHandler:IsSyncedCode() then
  --------------------------------------------------------------------------------
  -- Unsynced: forward sampled RP history to LuaUI, gated to what THIS client may
  -- see. The samples arrive from synced (identical on every client); this filter
  -- reproduces the graph's access rules -- spectators and post-game see every
  -- team, players see only their own + allied -- so enemy RP is never leaked
  -- mid-game, yet is revealed to everyone once the game is over.
  --------------------------------------------------------------------------------
  local spGetSpectatingState = Spring.GetSpectatingState
  local spGetMyTeamID        = Spring.GetMyTeamID
  local spAreTeamsAllied     = Spring.AreTeamsAllied
  local spIsGameOver         = Spring.IsGameOver

  local function maySee(teamID)
    if spIsGameOver and spIsGameOver() then return true end
    if spGetSpectatingState() then return true end
    local my = spGetMyTeamID()
    -- allied in either direction (covers initial and dynamic allies); a true
    -- enemy has no alliance either way, so their RP stays hidden.
    return spAreTeamsAllied(my, teamID) or spAreTeamsAllied(teamID, my)
  end

  local function onSample(_, teamID, index, value)
    if maySee(teamID) and Script.LuaUI("ResearchSampleEvent") then
      Script.LuaUI.ResearchSampleEvent(teamID, index, value)
    end
  end

  function gadget:Initialize()
    gadgetHandler:AddSyncAction("rpSample", onSample)
  end

  function gadget:Shutdown()
    gadgetHandler:RemoveSyncAction("rpSample")
  end

  return
end

--------------------------------------------------------------------------------
-- Synced: the ledger
--------------------------------------------------------------------------------

local spGetTeamList       = Spring.GetTeamList
local spGetTeamInfo       = Spring.GetTeamInfo
local spGetGaiaTeamID     = Spring.GetGaiaTeamID
local spSetTeamRulesParam = Spring.SetTeamRulesParam
local spGetUnitTeam       = Spring.GetUnitTeam
local spGetUnitDefID      = Spring.GetUnitDefID
local spGetUnitIsActive   = Spring.GetUnitIsActive
local spGetUnitIsStunned  = Spring.GetUnitIsStunned
local spGetTeamResources  = Spring.GetTeamResources
local spUseTeamResource   = Spring.UseTeamResource
local spGetUnitHealth     = Spring.GetUnitHealth
local spGetAllUnits       = Spring.GetAllUnits
local floor               = math.floor

local points  = {}                  -- points[teamID] = number (authoritative)
local gaiaID  = spGetGaiaTeamID()

-- No RP income (passive, generator, or kill/loss) is awarded until the
-- faction + placement pre-game sequence finishes. game_spawn.lua flips
-- GameRulesParam "phase" to "done" once every team has spawned; that param
-- has no ALLIED restriction, so it's globally readable here. Cached once
-- true since phase only ever moves forward.
local spGetGameRulesParam = Spring.GetGameRulesParam
local gameStarted = false

local function IsGameStarted()
  if gameStarted then return true end
  gameStarted = (spGetGameRulesParam("phase") == "done")
  return gameStarted
end

-- End-game graph history: sample every team's balance at this interval and
-- broadcast it (gated per client, unsynced side) so the graph has a complete,
-- access-correct RP series for everyone -- including enemy lines revealed at
-- game over, which a widget-side sampler could never backfill.
local RP_HISTORY_PERIOD = 12        -- seconds between history samples
local rpHist    = {}                -- rpHist[teamID] = { v1, v2, ... }
local rpSamples = 0                 -- samples taken so far
local rpResent  = false             -- game-over full resend done?

local rpIncome   = {}               -- [unitDefID] = research points per second (from customParam)
local generators = {}               -- [unitID]    = perSecond (live, finished generators)

local function mirror(teamID)
  spSetTeamRulesParam(teamID, RULES_PARAM, points[teamID] or 0, PARAM_OPTS)
end

--------------------------------------------------------------------------------
-- Public API. Defined at chunk load so any consumer that touches GG.Research
-- during its own Initialize never sees nil.
--------------------------------------------------------------------------------

GG.Research = {}

-- Current balance for a team (0 if untracked).
function GG.Research.Get(teamID)
  return points[teamID] or 0
end

-- Non-destructive affordability check.
function GG.Research.CanAfford(teamID, amount)
  return (points[teamID] or 0) >= (amount or 0)
end

-- Add points. `reason` is optional metadata for logging/stats only; the ledger
-- never makes decisions based on it. No-op for untracked teams (e.g. gaia).
function GG.Research.Add(teamID, amount, reason)
  if not points[teamID] or not amount or amount == 0 then
    return points[teamID]
  end
  local v = points[teamID] + amount
  if v < 0 then v = 0 end           -- clamp, in case a negative is ever passed
  points[teamID] = v
  mirror(teamID)
  return v
end

-- Atomic check-and-deduct. Returns true and deducts if affordable; otherwise
-- returns false and changes nothing. This is the ONLY call that must be atomic,
-- so two morphs in the same frame can never both spend the same points.
function GG.Research.Spend(teamID, amount)
  amount = amount or 0
  local cur = points[teamID] or 0
  if cur < amount then
    return false
  end
  points[teamID] = cur - amount
  mirror(teamID)
  return true
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function gadget:Initialize()
  for _, teamID in ipairs(spGetTeamList()) do
    if teamID ~= gaiaID then
      points[teamID] = STARTING_POINTS
      mirror(teamID)
    end
  end

  -- Cache which unit defs generate RP, and the energy each costs per second.
  for udid, ud in pairs(UnitDefs) do
    local cp = ud.customParams or {}
    local rp = tonumber(cp[RP_INCOME_PARAM])
    if rp and rp > 0 then
      rpIncome[udid] = { rp = rp, e = tonumber(cp[RP_ENERGY_PARAM]) or 0 }
    end
  end

  -- Mid-game luarules reload: pick up generators that are already finished.
  for _, unitID in ipairs(spGetAllUnits()) do
    local udid = spGetUnitDefID(unitID)
    if udid and rpIncome[udid] then
      local _, _, _, _, bp = spGetUnitHealth(unitID)
      if (bp == nil) or (bp >= 1) then
        generators[unitID] = rpIncome[udid]
      end
    end
  end
end

-- Returns the owning team if the generator may produce this tick, AFTER charging
-- its energy upkeep. Stops on EMP / under-construction (stunned), when switched
-- off or engine-disabled (not active), or when the team cannot pay the energy cost
-- this tick. Charging through the gadget (rather than reading the energy level) is
-- what makes the stop reliable: a failed payment is ground truth that the energy
-- was not there, banked or incoming.
local function chargeAndGetTeam(unitID, energyCost)
  if spGetUnitIsStunned(unitID) then return nil end
  if spGetUnitIsActive(unitID) == false then return nil end
  local teamID = spGetUnitTeam(unitID)
  if not teamID then return nil end

  if energyCost > 0 then
    local cur = spGetTeamResources(teamID, "energy")
    if not cur or cur < energyCost then return nil end   -- dry: no RP this tick
    spUseTeamResource(teamID, { e = energyCost })        -- pay the upkeep ourselves
  end

  return teamID
end

--------------------------------------------------------------------------------
-- Per-second income: passive floor (optional) + generators
--------------------------------------------------------------------------------

function gadget:UnitFinished(unitID, unitDefID, teamID)
  if rpIncome[unitDefID] then
    generators[unitID] = rpIncome[unitDefID]
  end
end

function gadget:GameFrame(n)
  if n % 30 ~= 0 then return end          -- once per second at 30fps

  -- Withhold all per-tick income until the pre-game sequence is done; the
  -- generator loop is also skipped entirely so it never charges energy
  -- upkeep for RP that wouldn't be granted anyway.
  local started = IsGameStarted()

  if started and PASSIVE_PER_SECOND ~= 0 then
    for teamID in pairs(points) do
      -- Skip dead/resigned teams: their balance freezes at death (kept in `points`
      -- so the end-game graph still samples them as a flat line to game end).
      if not select(3, spGetTeamInfo(teamID, false)) then
        GG.Research.Add(teamID, PASSIVE_PER_SECOND, "passive")
      end
    end
  end

  if started then
    for unitID, gen in pairs(generators) do
      local teamID = chargeAndGetTeam(unitID, gen.e)   -- nil if stunned/off/can't pay
      if teamID then
        GG.Research.Add(teamID, gen.rp, "generator")
      end
    end
  end

  -- Sample every team's balance for the end-game graph and broadcast it. The
  -- unsynced side decides which teams each client is allowed to receive.
  if n % (RP_HISTORY_PERIOD * 30) == 0 then
    rpSamples = rpSamples + 1
    for teamID in pairs(points) do
      local h = rpHist[teamID]
      if not h then h = {} ; rpHist[teamID] = h end
      local v = points[teamID] or 0
      h[rpSamples] = v
      SendToUnsynced("rpSample", teamID, rpSamples, v)
    end
  end

  -- On game over, resend the full series once so every client ends up with the
  -- complete history (the unsynced filter reveals all teams post-game).
  if not rpResent and Spring.IsGameOver and Spring.IsGameOver() then
    rpResent = true
    for teamID, h in pairs(rpHist) do
      for i = 1, #h do
        SendToUnsynced("rpSample", teamID, i, h[i])
      end
    end
  end
end

--------------------------------------------------------------------------------
-- Unit removal: clean up generators (always) and pay kill rewards (optional)
--------------------------------------------------------------------------------

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
  generators[unitID] = nil            -- also covers the reclaim a morph performs

  if KILL_REWARD_FRACTION ~= 0 and IsGameStarted() then
    if not attackerTeamID then return end          -- no killer (selfd, reclaim, ...)
    if attackerTeamID == teamID then return end     -- ignore killing your own units
    if attackerTeamID == gaiaID then return end

    local ud = UnitDefs[unitDefID]
    if not ud then return end

    local reward = floor((ud.metalCost or 0) * KILL_REWARD_FRACTION)
    if reward > 0 then
      GG.Research.Add(attackerTeamID, reward, "kill")
      if LOSS_REWARD_FRACTION ~= 0 then
        local consolation = floor(reward * LOSS_REWARD_FRACTION)
        if consolation > 0 then
          GG.Research.Add(teamID, consolation, "loss")
        end
      end
    end
  end
end

--------------------------------------------------------------------------------
-- Territorial / on-spot rules (must sit on a geothermal vent, etc.) are enforced
-- by other gadgets, which simply avoid placing the generator unit off-spot.
--------------------------------------------------------------------------------
