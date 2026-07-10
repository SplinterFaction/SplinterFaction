--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    game_team_upgrades.lua
--  brief:   Team-wide, levelled Weapons / Armor upgrades bought with Research
--           Points. Entirely event-driven: on purchase the new multiplier is
--           applied ONCE to every finished unit the team owns, and thereafter
--           only at UnitFinished (new production, morphs) and UnitGiven
--           (shares/captures). No damage hooks, no polling, no per-frame work.
--
--           Damage:  Spring.SetUnitWeaponDamages overrides the damage table of
--                    each unit's weapon instances -- every later shot uses the
--                    new values natively.
--           Armor:   Spring.SetUnitMaxHealth (+ proportional SetUnitHealth so a
--                    60%-health unit stays at 60%), and, for units with the
--                    Protoss-style personal shield, GG.PersonalShields.SetScale
--                    so shield capacity scales in lockstep -- a true "+X%
--                    effective HP" for both factions.
--
--           All applications are ABSOLUTE-FROM-BASE (unitdef values x current
--           level multiplier), never compounding, so reapplying is idempotent
--           and UnitGiven correctly re-bases a unit onto the receiving team's
--           levels (including back down to x1.0 for an un-upgraded team).
--
--           Widget protocol:
--             widget -> gadget : Spring.SendLuaRulesMsg("team_upgrade weapons")
--                                Spring.SendLuaRulesMsg("team_upgrade armor")
--             gadget -> widget : UpgradeDenyEvent(track, reason)
--                                ("points" | "max" | "dead"), owner-player only
--           Levels are mirrored as team rules params (allied-visible):
--             upgrade_weapons_level / upgrade_armor_level
--           which also gives free /luarules reload persistence.
--
--           Gadget API (e.g. for SimpleAI):
--             GG.TeamUpgrades.GetLevel(teamID, "weapons"|"armor") -> level
--             GG.TeamUpgrades.GetNextCost(teamID, track) -> cost | nil (maxed)
--             GG.TeamUpgrades.Purchase(teamID, track) -> true | false, reason
--  author:  SF
--  license: GNU GPL, v2 or later
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name    = "Team Upgrades",
    desc    = "Levelled team-wide weapon damage and armor upgrades (RP)",
    author  = "SF",
    date    = "2026",
    license = "GNU GPL, v2 or later",
    layer   = 20,       -- after RP ledger (0) and Protoss shields (0)
    enabled = true,
  }
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

-- Each entry is one level: cost in RP, mult applied to BASE unitdef values.
local TRACKS = {
  weapons = {
    param  = "upgrade_weapons_level",
    levels = {
      { cost = 250,  mult = 1.15 },
      { cost = 500,  mult = 1.30 },
      { cost = 1000, mult = 1.50 },
    },
  },
  armor = {
    param  = "upgrade_armor_level",
    levels = {
      { cost = 250,  mult = 1.15 },
      { cost = 500,  mult = 1.30 },
      { cost = 1000, mult = 1.50 },
    },
  },
}

-- Armor upgrades scale personal-shield MAX capacity. Set this true to also
-- scale the regen rate (so a bigger shield refills in the same time); false
-- keeps base regen (bigger shield takes proportionally longer to top up).
local SCALE_SHIELD_REGEN = false

local PARAM_OPTS = { allied = true }
local MSG_PREFIX = "team_upgrade "     -- "team_upgrade weapons" / "team_upgrade armor"

--------------------------------------------------------------------------------

if not gadgetHandler:IsSyncedCode() then
  --------------------------------------------------------------------------------
  -- Unsynced: forward deny events only to the player who tried to buy.
  --------------------------------------------------------------------------------
  local spGetMyPlayerID = Spring.GetMyPlayerID

  local function onDeny(_, playerID, track, reason)
    if playerID == spGetMyPlayerID() and Script.LuaUI("UpgradeDenyEvent") then
      Script.LuaUI.UpgradeDenyEvent(track, reason)
    end
  end

  function gadget:Initialize()
    gadgetHandler:AddSyncAction("upgradeDeny", onDeny)
  end

  function gadget:Shutdown()
    gadgetHandler:RemoveSyncAction("upgradeDeny")
  end

  return
end

--------------------------------------------------------------------------------
-- Synced
--------------------------------------------------------------------------------

local spGetPlayerInfo        = Spring.GetPlayerInfo
local spGetTeamInfo          = Spring.GetTeamInfo
local spGetTeamList          = Spring.GetTeamList
local spGetTeamUnits         = Spring.GetTeamUnits
local spGetTeamRulesParam    = Spring.GetTeamRulesParam
local spSetTeamRulesParam    = Spring.SetTeamRulesParam
local spGetGaiaTeamID        = Spring.GetGaiaTeamID
local spGetUnitDefID         = Spring.GetUnitDefID
local spGetUnitHealth        = Spring.GetUnitHealth
local spSetUnitHealth        = Spring.SetUnitHealth
local spSetUnitMaxHealth     = Spring.SetUnitMaxHealth
local spSetUnitWeaponDamages = Spring.SetUnitWeaponDamages

local gaiaID = spGetGaiaTeamID()

local level = { weapons = {}, armor = {} }   -- level[track][teamID] = 0..#levels

-- Per-unitdef base caches, built once in Initialize.
local baseWeaponDamages = {}   -- [udid] = { [weaponNum] = { [armorType] = dmg } }
local baseHealth        = {}   -- [udid] = unitdef max health
local skipDef           = {}   -- [udid] = true for dummies (scanner probes etc.)

--------------------------------------------------------------------------------
-- Multiplier lookups
--------------------------------------------------------------------------------

local function MultFor(track, teamID)
  local lvl = level[track][teamID] or 0
  if lvl <= 0 then return 1 end
  return TRACKS[track].levels[lvl].mult
end

--------------------------------------------------------------------------------
-- Application (always absolute-from-base, hence idempotent)
--------------------------------------------------------------------------------

local function ApplyWeaponsToUnit(unitID, udid, mult)
  local weps = baseWeaponDamages[udid]
  if not weps then return end
  for weaponNum, dmg in pairs(weps) do
    local scaled = {}
    for armorType, v in pairs(dmg) do
      scaled[armorType] = v * mult
    end
    spSetUnitWeaponDamages(unitID, weaponNum, scaled)
  end
end

local function ApplyArmorToUnit(unitID, udid, mult)
  local base = baseHealth[udid]
  if base then
    local cur, mx = spGetUnitHealth(unitID)
    if cur and mx and mx > 0 then
      local newMax = base * mult
      spSetUnitMaxHealth(unitID, newMax)
      -- Preserve the health FRACTION: a 60% unit stays a 60% unit.
      spSetUnitHealth(unitID, cur * (newMax / mx))
    end
  end
  -- Loz personal shields: scale max capacity in lockstep with hull.
  if GG.PersonalShields and GG.PersonalShields.SetScale then
    GG.PersonalShields.SetScale(unitID, mult, SCALE_SHIELD_REGEN and mult or 1)
  end
end

local function ApplyBothToUnit(unitID, udid, teamID)
  ApplyWeaponsToUnit(unitID, udid, MultFor("weapons", teamID))
  ApplyArmorToUnit(unitID, udid, MultFor("armor", teamID))
end

-- Finished, non-dummy units of a team.
local function ForEachEligibleUnit(teamID, fn)
  for _, unitID in ipairs(spGetTeamUnits(teamID)) do
    local udid = spGetUnitDefID(unitID)
    if udid and not skipDef[udid] then
      local _, _, _, _, bp = spGetUnitHealth(unitID)
      if (bp == nil) or (bp >= 1) then     -- under-construction units get theirs at UnitFinished
        fn(unitID, udid)
      end
    end
  end
end

--------------------------------------------------------------------------------
-- Purchase
--------------------------------------------------------------------------------

-- Team-level purchase (also the AI entry point). Returns true, or false+reason.
local function Purchase(teamID, trackName)
  local track = TRACKS[trackName]
  if not track then return false, "badtrack" end

  local lvl = level[trackName][teamID] or 0
  if lvl >= #track.levels then return false, "max" end

  local cost = track.levels[lvl + 1].cost
  if not GG.Research.Spend(teamID, cost) then return false, "points" end

  lvl = lvl + 1
  level[trackName][teamID] = lvl
  spSetTeamRulesParam(teamID, track.param, lvl, PARAM_OPTS)

  local mult = track.levels[lvl].mult
  if trackName == "weapons" then
    ForEachEligibleUnit(teamID, function(unitID, udid)
      ApplyWeaponsToUnit(unitID, udid, mult)
    end)
  else
    ForEachEligibleUnit(teamID, function(unitID, udid)
      ApplyArmorToUnit(unitID, udid, mult)
    end)
  end

  return true
end

--------------------------------------------------------------------------------
-- Public API (SimpleAI etc.)
--------------------------------------------------------------------------------

GG.TeamUpgrades = {}

function GG.TeamUpgrades.GetLevel(teamID, trackName)
  local t = level[trackName]
  return t and (t[teamID] or 0) or 0
end

function GG.TeamUpgrades.GetNextCost(teamID, trackName)
  local track = TRACKS[trackName]
  if not track then return nil end
  local lvl = level[trackName][teamID] or 0
  local nxt = track.levels[lvl + 1]
  return nxt and nxt.cost or nil       -- nil = maxed
end

GG.TeamUpgrades.Purchase = Purchase

--------------------------------------------------------------------------------
-- Message entry point (players)
--------------------------------------------------------------------------------

function gadget:RecvLuaMsg(msg, playerID)
  local trackName = msg:match("^" .. MSG_PREFIX .. "(%a+)$")
  if not trackName or not TRACKS[trackName] then return false end

  local _, _, spec, teamID = spGetPlayerInfo(playerID, false)
  if spec or not teamID then return true end

  if select(3, spGetTeamInfo(teamID, false)) then
    SendToUnsynced("upgradeDeny", playerID, trackName, "dead")
    return true
  end

  local ok, reason = Purchase(teamID, trackName)
  if not ok then
    SendToUnsynced("upgradeDeny", playerID, trackName, reason)
  end
  return true
end

--------------------------------------------------------------------------------
-- Unit lifecycle: the only other places upgrades are ever applied
--------------------------------------------------------------------------------

function gadget:UnitFinished(unitID, unitDefID, teamID)
  if skipDef[unitDefID] or teamID == gaiaID then return end
  -- Covers factory production AND morphs (a morph spawns a finished unit,
  -- which fires UnitFinished).
  ApplyBothToUnit(unitID, unitDefID, teamID)
end

function gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
  if skipDef[unitDefID] or newTeamID == gaiaID then return end
  local _, _, _, _, bp = spGetUnitHealth(unitID)
  if bp and bp < 1 then return end     -- unfinished share: its UnitFinished handles it
  -- Re-base onto the RECEIVING team's levels. Absolute-from-base makes this
  -- correct in both directions (upgrade up, or reset down to x1.0).
  ApplyBothToUnit(unitID, unitDefID, newTeamID)
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function gadget:Initialize()
  -- Base caches from the frozen defs.
  for udid, ud in pairs(UnitDefs) do
    local cp = ud.customParams or {}
    if cp.is_dummy then
      skipDef[udid] = true
    else
      baseHealth[udid] = ud.health

      local weps = ud.weapons
      if weps and #weps > 0 then
        local entry = nil
        for i = 1, #weps do
          local wdid = weps[i].weaponDef
          local wd = wdid and WeaponDefs[wdid]
          -- Skip shield-type weapons (engine shields have no damage to scale)
          if wd and wd.type ~= "Shield" then
            local dmg = {}
            local any = false
            for k, v in pairs(wd.damages) do
              if type(k) == "number" and type(v) == "number" then
                dmg[k] = v
                any = true
              end
            end
            if any then
              entry = entry or {}
              entry[i] = dmg
            end
          end
        end
        baseWeaponDamages[udid] = entry
      end
    end
  end

  -- /luarules reload persistence: rules params survive the reload, our locals
  -- do not. Read levels back and reapply to everything standing.
  for _, teamID in ipairs(spGetTeamList()) do
    if teamID ~= gaiaID then
      for trackName, track in pairs(TRACKS) do
        -- Parentheses: GetTeamRulesParam returns NO values for an unset param,
        -- and tonumber() with zero arguments is an error.
        local lvl = tonumber((spGetTeamRulesParam(teamID, track.param))) or 0
        if lvl > #track.levels then lvl = #track.levels end
        level[trackName][teamID] = lvl
      end
      if (level.weapons[teamID] or 0) > 0 or (level.armor[teamID] or 0) > 0 then
        ForEachEligibleUnit(teamID, function(unitID, udid)
          ApplyBothToUnit(unitID, udid, teamID)
        end)
      end
    end
  end
end
