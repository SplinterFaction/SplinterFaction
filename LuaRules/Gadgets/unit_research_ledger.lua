--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    unit_research_ledger.lua
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
    name    = "ResearchLedger",
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

--------------------------------------------------------------------------------

if not gadgetHandler:IsSyncedCode() then
  -- Unsynced side has nothing to do; balances travel via the team rules param,
  -- which any widget can read directly.
  return
end

--------------------------------------------------------------------------------
-- Synced: the ledger
--------------------------------------------------------------------------------

local spGetTeamList       = Spring.GetTeamList
local spGetGaiaTeamID     = Spring.GetGaiaTeamID
local spSetTeamRulesParam = Spring.SetTeamRulesParam
local floor               = math.floor

local points  = {}                  -- points[teamID] = number (authoritative)
local gaiaID  = spGetGaiaTeamID()

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
end

--------------------------------------------------------------------------------
-- Income source: passive floor (optional)
--------------------------------------------------------------------------------

if PASSIVE_PER_SECOND ~= 0 then
  function gadget:GameFrame(n)
    if n % 30 == 0 then             -- once per second at 30fps
      for teamID in pairs(points) do
        GG.Research.Add(teamID, PASSIVE_PER_SECOND, "passive")
      end
    end
  end
end

--------------------------------------------------------------------------------
-- Income source: kills (and optional "learn from your losses") (optional)
--------------------------------------------------------------------------------

if KILL_REWARD_FRACTION ~= 0 then
  function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
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
-- Territorial generators plug in here later with no ledger changes:
--   GG.Research.Add(teamID, amountPerTick, "generator")
-- ...wherever your on-spot building gadget ticks.
--------------------------------------------------------------------------------
