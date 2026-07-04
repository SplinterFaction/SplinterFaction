--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    game_scanner_sweep.lua
--  brief:   Team-level "Scanner Sweep" support power. A player (not a unit)
--           targets a map position; a short-lived invisible probe unit is
--           spawned there, granting normal ground LOS in an 800 radius for
--           5 seconds, exactly as if a unit were standing on the spot.
--
--           Cost is Research Points, spent from the TEAM pool via
--           GG.Research.Spend (atomic). The cooldown is PER PLAYER, so two
--           players on one team can each fire their own sweep -- each pull
--           costs the shared pool 100 RP.
--
--           Widget protocol (LuaUI <-> LuaRules):
--             widget -> gadget : Spring.SendLuaRulesMsg("scanner_sweep <x> <z>")
--             widget -> gadget : Spring.SendLuaRulesMsg("scanner_query")
--                                (re-sync cooldown after a widget/LuaUI reload)
--             gadget -> widget : ScannerCooldownEvent(endFrame)
--                                (only ever delivered to the owning player)
--             gadget -> widget : ScannerDenyEvent(reason)
--                                ("cooldown" | "points" | "dead" | "spawn")
--  author:  SF
--  license: GNU GPL, v2 or later
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name    = "Scanner Sweep",
    desc    = "Player-targeted LOS reveal, paid in Research Points",
    author  = "SF",
    date    = "2026",
    license = "GNU GPL, v2 or later",
    layer   = 10,       -- after the RP ledger (layer 0): GG.Research must exist
    enabled = true,
  }
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local COST_RP          = 100                -- research points per sweep (team pool)
local COOLDOWN_SECONDS = 20                 -- per PLAYER, not per team
local REVEAL_SECONDS   = 5                  -- probe lifetime
local PROBE_UNITDEF    = "scanner_probe"    -- must exist in unitdefs
local SWEEP_CEG        = "scannersweep"    -- optional visual at target; harmless if undefined

local MSG_SWEEP        = "scanner_sweep"    -- "scanner_sweep <x> <z>"
local MSG_QUERY        = "scanner_query"

--------------------------------------------------------------------------------

if not gadgetHandler:IsSyncedCode() then
  --------------------------------------------------------------------------------
  -- Unsynced: forward per-player events to LuaUI, but ONLY to the player they
  -- belong to. Cooldowns are per player and nobody else's business; this filter
  -- is what keeps the synced->unsynced broadcast private.
  --------------------------------------------------------------------------------
  local spGetMyPlayerID = Spring.GetMyPlayerID

  local function onCooldown(_, playerID, endFrame)
    if playerID == spGetMyPlayerID() and Script.LuaUI("ScannerCooldownEvent") then
      Script.LuaUI.ScannerCooldownEvent(endFrame)
    end
  end

  local function onDeny(_, playerID, reason)
    if playerID == spGetMyPlayerID() and Script.LuaUI("ScannerDenyEvent") then
      Script.LuaUI.ScannerDenyEvent(reason)
    end
  end

  function gadget:Initialize()
    gadgetHandler:AddSyncAction("scannerCd",   onCooldown)
    gadgetHandler:AddSyncAction("scannerDeny", onDeny)
  end

  function gadget:Shutdown()
    gadgetHandler:RemoveSyncAction("scannerCd")
    gadgetHandler:RemoveSyncAction("scannerDeny")
  end

  return
end

--------------------------------------------------------------------------------
-- Synced
--------------------------------------------------------------------------------

local spGetPlayerInfo    = Spring.GetPlayerInfo
local spGetTeamInfo      = Spring.GetTeamInfo
local spGetGameFrame     = Spring.GetGameFrame
local spGetGroundHeight  = Spring.GetGroundHeight
local spCreateUnit       = Spring.CreateUnit
local spDestroyUnit      = Spring.DestroyUnit
local spSetUnitNoDraw    = Spring.SetUnitNoDraw
local spSetUnitNoSelect  = Spring.SetUnitNoSelect
local spSetUnitNoMinimap = Spring.SetUnitNoMinimap
local spSetUnitNeutral   = Spring.SetUnitNeutral
local spSpawnCEG         = Spring.SpawnCEG
local mapSizeX           = Game.mapSizeX
local mapSizeZ           = Game.mapSizeZ
local max, min           = math.max, math.min

local COOLDOWN_FRAMES = COOLDOWN_SECONDS * 30
local REVEAL_FRAMES   = REVEAL_SECONDS   * 30

local probeDefID   = nil    -- resolved in Initialize
local cdEndFrame   = {}     -- [playerID] = frame at which that player may fire again
local probes       = {}     -- [unitID]   = frame at which this probe dies
local haveProbes   = false  -- cheap GameFrame gate

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function Deny(playerID, reason)
  SendToUnsynced("scannerDeny", playerID, reason)
end

local function DoSweep(playerID, x, z)
  -- Resolve player -> team; spectators cannot fire.
  local _, active, spec, teamID = spGetPlayerInfo(playerID, false)
  if spec or not teamID then
    return
  end

  -- Dead/resigned teams keep their RP frozen (ledger behaviour) and get no toys.
  local isDead = select(3, spGetTeamInfo(teamID, false))
  if isDead then
    Deny(playerID, "dead")
    return
  end

  local f = spGetGameFrame()
  if (cdEndFrame[playerID] or 0) > f then
    Deny(playerID, "cooldown")
    return
  end

  -- Clamp target into the map (a click on the void edge should still work).
  x = max(0, min(x, mapSizeX))
  z = max(0, min(z, mapSizeZ))
  local y = max(spGetGroundHeight(x, z) or 0, 0)   -- water surface, not seafloor

  -- Atomic team-pool spend; the ONLY thing that may fail after this is unit
  -- creation, which refunds.
  if not GG.Research.Spend(teamID, COST_RP) then
    Deny(playerID, "points")
    return
  end

  local unitID = spCreateUnit(PROBE_UNITDEF, x, y, z, 0, teamID)
  if not unitID then
    -- Unit limit or blocked def: give the points back, no cooldown.
    GG.Research.Add(teamID, COST_RP, "scanner_refund")
    Deny(playerID, "spawn")
    return
  end

  -- Belt-and-suspenders on top of the unitdef: never drawn, never selectable,
  -- never on the minimap, never auto-targeted.
  spSetUnitNoDraw(unitID, true)
  spSetUnitNoSelect(unitID, true)
  spSetUnitNoMinimap(unitID, true)
  spSetUnitNeutral(unitID, true)

  probes[unitID] = f + REVEAL_FRAMES
  haveProbes = true

  cdEndFrame[playerID] = f + COOLDOWN_FRAMES
  SendToUnsynced("scannerCd", playerID, cdEndFrame[playerID])

  -- Optional flourish at the target; SpawnCEG on an undefined name is a no-op.
  if SWEEP_CEG then
    spSpawnCEG(SWEEP_CEG, x, y + 8, z, 0, 1, 0)
    Spring.PlaySoundFile("scannersweep", 1)
  end
end

--------------------------------------------------------------------------------
-- Message entry point
--------------------------------------------------------------------------------

function gadget:RecvLuaMsg(msg, playerID)
  if msg == MSG_QUERY then
    -- Widget (re)loaded: tell it where its cooldown stands. 0 = ready.
    SendToUnsynced("scannerCd", playerID, cdEndFrame[playerID] or 0)
    return true
  end

  local x, z = msg:match("^" .. MSG_SWEEP .. " (%-?%d+%.?%d*) (%-?%d+%.?%d*)$")
  if x then
    DoSweep(playerID, tonumber(x), tonumber(z))
    return true
  end

  return false
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function gadget:Initialize()
  local ud = UnitDefNames[PROBE_UNITDEF]
  if not ud then
    Spring.Echo("[ScannerSweep] unitdef '" .. PROBE_UNITDEF .. "' not found -- gadget disabled")
    gadgetHandler:RemoveGadget(self)
    return
  end
  probeDefID = ud.id

  -- Mid-game luarules reload: any live probes are orphans with no death timer.
  -- Kill them now rather than leaving permanent wards on the map.
  for _, unitID in ipairs(Spring.GetAllUnits()) do
    if Spring.GetUnitDefID(unitID) == probeDefID then
      spDestroyUnit(unitID, false, true)
    end
  end
end

function gadget:GameFrame(f)
  if not haveProbes then return end

  local remaining = false
  for unitID, dieFrame in pairs(probes) do
    if f >= dieFrame then
      probes[unitID] = nil
      spDestroyUnit(unitID, false, true)   -- no wreck, reclaimed-style removal
    else
      remaining = true
    end
  end
  haveProbes = remaining
end

function gadget:UnitDestroyed(unitID)
  -- Covers probes killed by splash damage etc. before their timer.
  if probes[unitID] then
    probes[unitID] = nil
  end
end
