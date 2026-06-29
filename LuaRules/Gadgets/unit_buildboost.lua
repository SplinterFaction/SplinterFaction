--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    unit_buildboost.lua
--  brief:   Adds a "Boost" command to builder order panels. Spends research
--           points (GG.Research) to temporarily multiply a builder's build
--           speed, then restores it when the duration elapses.
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
--------------------------------------------------------------------------------

local DEF_COST     = 100
local DEF_MULT     = 2.0
local DEF_ADD      = 0
local DEF_DURATION = 20      -- seconds

local CMD_BUILD_BOOST = 35410   -- LuaRules range (30000-39999); free vs morph's 31410-34410

local REFRESH_INTERVAL = 9      -- frames between button label/state refreshes

--------------------------------------------------------------------------------

if not gadgetHandler:IsSyncedCode() then
  return    -- pure synced gadget; UI reads state via unit rules params
end

local GAME_SPEED = Game.gameSpeed or 30

local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local spFindUnitCmdDesc   = Spring.FindUnitCmdDesc
local spEditUnitCmdDesc   = Spring.EditUnitCmdDesc
local spSetUnitBuildSpeed = Spring.SetUnitBuildSpeed
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local spGetUnitDefID      = Spring.GetUnitDefID
local spGetUnitTeam       = Spring.GetUnitTeam
local spGetUnitHealth     = Spring.GetUnitHealth
local spGetGameFrame      = Spring.GetGameFrame
local spGetAllUnits       = Spring.GetAllUnits
local spSendMessageToTeam = Spring.SendMessageToTeam

local floor = math.floor
local ceil  = math.ceil
local max   = math.max

local boostCfg = {}   -- [unitDefID] = { cost, mult, add, durationFrames } or nil
local builders = {}   -- [unitID]    = unitDefID  (units that carry the button)
local active   = {}   -- [unitID]    = { endFrame, base, teamID }

--------------------------------------------------------------------------------

local function isDone(unitID)
  local _, _, _, _, bp = spGetUnitHealth(unitID)
  return (bp == nil) or (bp >= 1)
end

local function durationSecs(cfg)
  return floor(cfg.durationFrames / GAME_SPEED + 0.5)
end

local function addBoostCmd(unitID, unitDefID)
  if spFindUnitCmdDesc(unitID, CMD_BUILD_BOOST) then return end
  local cfg = boostCfg[unitDefID]
  if not cfg then return end
  spInsertUnitCmdDesc(unitID, {
    id      = CMD_BUILD_BOOST,
    type    = CMDTYPE.ICON,
    name    = "Boost",
    action  = "buildboost",
    tooltip = string.format("Build Boost: x%.1f build speed for %ds  (%d research)",
                            cfg.mult, durationSecs(cfg), cfg.cost),
    -- texture = "LuaRules/Images/buildboost.png",  -- optional; add an asset here
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
    spSendMessageToTeam(teamID, "Build boost already active")
    return
  end

  if not (GG.Research and GG.Research.Spend(teamID, cfg.cost)) then
    spSendMessageToTeam(teamID, "Need " .. cfg.cost .. " research points to boost")
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

  -- Handle a mid-game luarules reload: re-add the button to existing builders.
  for _, unitID in ipairs(spGetAllUnits()) do
    local udid = spGetUnitDefID(unitID)
    if boostCfg[udid] then
      builders[unitID] = udid
      addBoostCmd(unitID, udid)
    end
  end
end

function gadget:UnitCreated(unitID, unitDefID, teamID)
  if boostCfg[unitDefID] then
    builders[unitID] = unitDefID
    addBoostCmd(unitID, unitDefID)
  end
end

-- Covers ordinary death AND the reclaim that morphing performs, so a boosted
-- builder that morphs is cleaned up here; the boost does not carry to the new unit.
function gadget:UnitDestroyed(unitID)
  builders[unitID] = nil
  active[unitID]   = nil
end

-- Instant action command: apply and consume so it never enters the queue.
function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID)
  if cmdID == CMD_BUILD_BOOST then
    activateBoost(unitID, unitDefID, teamID)
    return false
  end
  return true
end

function gadget:GameFrame(n)
  -- Expire finished boosts.
  if next(active) then
    for unitID, b in pairs(active) do
      if n >= b.endFrame then
        restoreBoost(unitID, b)
        active[unitID] = nil
      end
    end
  end

  -- Refresh button labels/state: live countdown while active, grey out while
  -- active or unaffordable.
  if n % REFRESH_INTERVAL == 0 then
    for unitID, udid in pairs(builders) do
      local idx = spFindUnitCmdDesc(unitID, CMD_BUILD_BOOST)
      if idx then
        local cfg = boostCfg[udid]
        local b   = active[unitID]
        if b then
          local secs = max(0, ceil((b.endFrame - n) / GAME_SPEED))
          spEditUnitCmdDesc(unitID, idx, { disabled = true, name = "Boost " .. secs .. "s" })
        else
          local teamID    = spGetUnitTeam(unitID)
          local canAfford = (not GG.Research) or (teamID and GG.Research.CanAfford(teamID, cfg.cost))
          spEditUnitCmdDesc(unitID, idx, { disabled = not canAfford, name = "Boost" })
        end
      end
    end
  end
end
