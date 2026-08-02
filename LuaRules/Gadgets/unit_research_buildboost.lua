--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    unit_buildboost.lua
--  brief:   Temporary RP-paid build speed boost on builders. Spends research
--           points (GG.Research) to temporarily multiply a builder's build
--           speed, then restores it when the duration elapses.
--
--           The command is registered HIDDEN: it never appears in the order
--           panel. The "Production Boost" button in gui_static_abilities.lua
--           issues it to the eligible builders in the current selection.
--  author:  SF
--  license: GNU GPL, v2 or later
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name    = "BuildBoost",
    desc    = "RP-paid temporary build speed boost on builders",
    author  = "SF",
    date    = "2026",
    license = "GNU GPL, v2 or later",
    layer   = 0,
    enabled = true,
  }
end

--------------------------------------------------------------------------------
-- Config. Per-unit overrides via customParams (human-readable units):
--   buildboost          = "false"  -- opt a builder out entirely
--   buildboost_cost     = 100      -- research points per activation
--   buildboost_mult     = 2.0      -- build speed multiplier while active
--   buildboost_add      = 0        -- flat build speed added on top of the mult
--   buildboost_duration = 20       -- seconds the boost lasts
-- Final boosted speed = base * mult + add.
--
-- NOTE: gui_static_abilities.lua mirrors DEF_COST / DEF_MULT / DEF_DURATION and
-- CMD_BUILD_BOOST so the button can show cost and eligibility without a
-- round trip. Keep the two in sync if you change them.
--------------------------------------------------------------------------------

local DEF_COST     = 100
local DEF_MULT     = 5.0
local DEF_ADD      = 0
local DEF_DURATION = 20      -- seconds

local CMD_BUILD_BOOST = 35410   -- LuaRules range (30000-39999); free vs morph's 31410-34410

--------------------------------------------------------------------------------

if not gadgetHandler:IsSyncedCode() then
  return    -- pure synced gadget; UI reads state via unit rules params
end

local GAME_SPEED = Game.gameSpeed or 30

local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local spFindUnitCmdDesc   = Spring.FindUnitCmdDesc
local spSetUnitBuildSpeed = Spring.SetUnitBuildSpeed
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local spGetUnitDefID      = Spring.GetUnitDefID
local spGetUnitHealth     = Spring.GetUnitHealth
local spGetGameFrame      = Spring.GetGameFrame
local spGetAllUnits       = Spring.GetAllUnits
local spSendMessageToTeam = Spring.SendMessageToTeam

local floor = math.floor

local boostCfg = {}   -- [unitDefID] = { cost, mult, add, durationFrames } or nil
local active   = {}   -- [unitID]    = { endFrame, base, teamID }

local lastMsgFrame = {}   -- [teamID] = frame; one message per team per frame

--------------------------------------------------------------------------------

-- A single click can order dozens of builders at once; collapse the resulting
-- burst of identical refusals into one line.
local function teamMsg(teamID, text)
  local n = spGetGameFrame()
  if lastMsgFrame[teamID] == n then return end
  lastMsgFrame[teamID] = n
  spSendMessageToTeam(teamID, text)
end

local function isDone(unitID)
  local _, _, _, _, bp = spGetUnitHealth(unitID)
  return (bp == nil) or (bp >= 1)
end

local function durationSecs(cfg)
  return floor(cfg.durationFrames / GAME_SPEED + 0.5)
end

-- The descriptor is registered but HIDDEN: it keeps the command valid on the
-- unit (and available to "/buildboost" / hotkey binds) without occupying a slot
-- in the order panel. The abilities panel drives it via GiveOrderToUnitArray.
local function addBoostCmd(unitID, unitDefID)
  if spFindUnitCmdDesc(unitID, CMD_BUILD_BOOST) then return end
  local cfg = boostCfg[unitDefID]
  if not cfg then return end
  spInsertUnitCmdDesc(unitID, {
    id       = CMD_BUILD_BOOST,
    type     = CMDTYPE.ICON,
    name     = "Boost",
    action   = "buildboost",
    hidden   = true,
    queueing = false,
    tooltip  = string.format("Production Boost: x%.1f build speed for %ds  (%d research)",
                             cfg.mult, durationSecs(cfg), cfg.cost),
  })
end

-- Capture the current "natural" build speed so a tech-scaled value is respected
-- on restore. Falls back to the unit def's base buildSpeed.
local function naturalSpeed(unitID, unitDefID)
  return spGetUnitRulesParam(unitID, "workertime") or UnitDefs[unitDefID].buildSpeed
end

local function activateBoost(unitID, unitDefID, teamID)
  local cfg = boostCfg[unitDefID]
  if not cfg then return end
  if not isDone(unitID) then return end           -- nothing to boost on a half-built builder

  if active[unitID] then
    return    -- silently ignore: the panel already excludes boosted builders
  end

  if not (GG.Research and GG.Research.Spend(teamID, cfg.cost)) then
    teamMsg(teamID, "Not enough research points to boost production")
    return
  end

  local base    = naturalSpeed(unitID, unitDefID)
  local boosted = base * cfg.mult + cfg.add
  spSetUnitBuildSpeed(unitID, boosted)

  local endFrame = spGetGameFrame() + cfg.durationFrames
  active[unitID] = { endFrame = endFrame, base = base, teamID = teamID }
  spSetUnitRulesParam(unitID, "buildboost_end", endFrame)   -- so UI can show a countdown
end

local function restoreBoost(unitID, b)
  if spGetUnitDefID(unitID) then     -- unit may already be gone
    -- Prefer the live natural speed in case tech changed it mid-boost.
    local base = spGetUnitRulesParam(unitID, "workertime") or b.base
    spSetUnitBuildSpeed(unitID, base)
    spSetUnitRulesParam(unitID, "buildboost_end", 0)
  end
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function gadget:Initialize()
  for udid, ud in pairs(UnitDefs) do
    if (ud.buildSpeed or 0) > 0 then
      local cp = ud.customParams or {}
      if cp.buildboost ~= "false" then
        boostCfg[udid] = {
          cost          = tonumber(cp.buildboost_cost) or DEF_COST,
          mult          = tonumber(cp.buildboost_mult) or DEF_MULT,
          add           = tonumber(cp.buildboost_add)  or DEF_ADD,
          durationFrames = floor(((tonumber(cp.buildboost_duration) or DEF_DURATION)) * GAME_SPEED + 0.5),
        }
      end
    end
  end

  -- Handle a mid-game luarules reload: re-register on existing builders.
  for _, unitID in ipairs(spGetAllUnits()) do
    local udid = spGetUnitDefID(unitID)
    if boostCfg[udid] then
      addBoostCmd(unitID, udid)
      if spGetUnitRulesParam(unitID, "buildboost_end") == nil then
        spSetUnitRulesParam(unitID, "buildboost_end", 0)
      end
    end
  end
end

function gadget:UnitCreated(unitID, unitDefID, teamID)
  if boostCfg[unitDefID] then
    addBoostCmd(unitID, unitDefID)
    -- Publish a defined value straight away so the abilities panel can read
    -- "not boosted" without special-casing nil.
    spSetUnitRulesParam(unitID, "buildboost_end", 0)
  end
end

-- Covers ordinary death AND the reclaim that morphing performs, so a boosted
-- builder that morphs is cleaned up here; the boost does not carry to the new unit.
function gadget:UnitDestroyed(unitID)
  active[unitID] = nil
end

-- Instant action command: apply and consume so it never enters the queue.
function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID)
  if cmdID == CMD_BUILD_BOOST then
    activateBoost(unitID, unitDefID, teamID)
    return false
  end
  return true
end

-- Expire finished boosts. Button state lives entirely in the abilities panel
-- now; it polls "buildboost_end" for the countdown, so there is nothing else
-- to tick here.
function gadget:GameFrame(n)
  if next(active) then
    for unitID, b in pairs(active) do
      if n >= b.endFrame then
        restoreBoost(unitID, b)
        active[unitID] = nil
      end
    end
  end
end
