------------------------------------------------------------------------------------------
--- Rearming a bomber or fighter happens between two gadgets.
---
--- unit_airbase: controls when a unit is landed/rearming
---     - Initially all rearm-able planes have their ammo set to their customParams.maxAmmo
---     - When a Request-Rearm happens (locally or remote from bomber_control):
---       - Finds a free airpad slot and movestoward+snap
          -- TODO: If no free airpad slot found, set plane to "CantRearm" list (@bomber_control)
---     - Rearming only happens after repairing (if needed), sends event to bomber_control
--- unit_bomber_control: controls each bomber ammo and its reload time
---     - After firing, update ammo count
---     - (WIP) If out of ammo, reload is set to 99999+currentFrame ("infinite reload")
---       -- Send RequestRearm event to unit_airbase
---     - Once landed (on rearming state), reload is set to ammoReload (from customParams)
          -- TODO: If on "CantRearm" status, the plane will take a fixed amount of damage / sec
---     - After reload (on rearming state) is finished, request its release to unit_airbase
-------------------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Bomber Control",
    desc      = "Controls bombers and other re-armable planes",
    author    = "TheFatController",
    date      = "May 25, 2011",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

VFS.Include("gamedata/taptools.lua")

--------------------------------------------------------------------------------
--- SYNCED ONLY
-----------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
  return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--local cmdFly = 145  -- Fly/Land command button ID

GG.PlanesToRearm = {}
local newPlanesToRearm = {}  -- These guys just fired and must have "infinite" reload, until rearm
local newRequestLanding = {} -- We'll hold automatic landing request for one second to allow bombers some time to fire

local MoveCtrlEnable = Spring.MoveCtrl.Enable
local MoveCtrlSetVelocity = Spring.MoveCtrl.SetVelocity
local MoveCtrlDisable = Spring.MoveCtrl.Disable
local GetUnitVelocity = Spring.GetUnitVelocity
local spGetGameFrame = Spring.GetGameFrame
local spGetCommandQueue = Spring.GetCommandQueue
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local spSetUnitWeaponState = Spring.SetUnitWeaponState
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitDefID = Spring.GetUnitDefID

-- Callback from the unit animation script (.cob or .lua), when ammo-weapon is fired
function BombsAway(unitID, unitDefID, unitTeam)
    --local ud = UnitDefs[unitDefID]
    local ammo = spGetUnitRulesParam(unitID,"ammo")
    local newAmmo = ammo and math.max(0, ammo-1) or 1
    spSetUnitRulesParam(unitID, "ammo", newAmmo)
    if newAmmo == 0 then
        newPlanesToRearm[#newPlanesToRearm + 1] = unitID
        newRequestLanding[#newRequestLanding + 1] = { id = unitID, frame = spGetGameFrame() + 30 }
        --if Script.LuaRules('RequestRearm') then
        --  Script.LuaRules.RequestRearm(unitID)
        --end
    end
    --Spring.Echo("Bombs released from: "..unitID.." ammo was: ".. Spring.GetUnitRulesParam(unitID, "ammo")) -- || Bombers to Rearm: "..#GG.PlanesToRearm)
end

-- We're counting on all re-armable weapons reload time to be the same..
local function getReload(unitID)
  local origReload = Spring.GetUnitWeaponState(unitID, 1, "reloadTime")
  spSetUnitRulesParam(unitID, "origReload", origReload)
  return origReload
end

local function GetRearmWeaponsCount(unitID)
  local unitDef = UnitDefs[spGetUnitDefID(unitID)]
  local rearmweapons = unitDef.customParams.rearmweapons
  return (rearmweapons ~= nil) and tonumber(rearmweapons) or 1
end


--- Callback from unit_airbase, for when bomber is ready to rearm; n == event Frame
function RearmBomber(unitID, n)
  --Spring.Echo("Bomber_control rearming: ", unitID)
  local origReload = Spring.GetUnitRulesParam(unitID, "origReload")
  if not origReload then
    origReload = getReload(unitID)
    if not origReload or not type(origReload)=="number" then
      return end
  end

  -- Reset weapon(s) reload to default
  local rearmweapons = GetRearmWeaponsCount(unitID)
  for i = 1, rearmweapons do
    Spring.SetUnitWeaponState(unitID, i, {reloadTime = origReload, reloadState = n + origReload})
  end

  GG.PlanesToRearm[unitID] = { startFrame = n, endFrame = n + (origReload * 30) } -- rearm-finished frame
  --Spring.Echo("start, end frames: ",n,n+(origReload*30))
end

--region ################ Spring Events and CallIns

function gadget:Initialize()
  gadgetHandler:RegisterGlobal("BombsAway", BombsAway)
  gadgetHandler:RegisterGlobal("RearmBomber", RearmBomber)
end

-- Setup ammo-weaponry planes
function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
  local ud = UnitDefs[unitDefID]
  if ud.customParams and ud.customParams.maxammo then
    --local weaponswithammo = ud.customParams.weaponswithammo or 1
    --for weaponNum = 0, weaponswithammo do
    getReload(unitID)
    spSetUnitRulesParam(unitID, "ammo", ud.customParams.maxammo)
    --spGiveOrderToUnit(unitID, cmdFly, { 1 }, {})    -- By default, ammo planes have 'land' status
  end
end

function gadget:GameFrame(n)

  -- Set up just-outofammo planes
  for _,unitID in ipairs(newPlanesToRearm) do
    local rearmweapons = GetRearmWeaponsCount(unitID)
    -- Increase weapon reload (n+99999) then remove it from newPlanesToRearm
    for i = 1, rearmweapons do
      spSetUnitWeaponState(unitID, i, {reloadTime = 99999, reloadState = n + 99999})
    end
    ipairs_remove(newPlanesToRearm, unitID)
  end

  -- Actually fire a request-rearm after a full second has passed. Bombers need breathing room.
  for _, request in ipairs(newRequestLanding) do
    --newRequestLanding[#newRequestLanding + 1] = { id = unitID, frame = spGetGameFrame() + 30 }
    if n >= request.frame then
      local cQueue = spGetCommandQueue(request.id, 1)
      local hasCommand = cQueue and #cQueue > 0 --cQueue[1] and cQueue[1].id == CMD.ATTACK
      --Spring.Echo("has command? " ..tostring(hasCommand))
      if (not hasCommand) and Script.LuaRules('RequestRearm') then
        Script.LuaRules.RequestRearm(request.id)
        ipairs_remove(newRequestLanding, request)
      end
    end
  end

  -- Once rearm is finished, set plane as ready (to release or stay docked)
  for unitID, v in pairs(GG.PlanesToRearm) do
    local perc = inverselerp(v.startFrame, v.endFrame, n)
    if perc >= 0.999 then
      --Spring.Echo("Rearm done: "..unitID)
      GG.PlanesToRearm[unitID]=nil
      if Script.LuaRules('RearmDone') then
        Script.LuaRules.RearmDone(unitID)
      end
      spSetUnitRulesParam(unitID, "rearmProgress", nil)  -- clear
      local ud = UnitDefs[spGetUnitDefID(unitID)]
      if ud then
        local maxammo = ud.customParams.maxammo
        if maxammo then
          spSetUnitRulesParam(unitID,"ammo", ud.customParams.maxammo)
        end
      end
    else
      spSetUnitRulesParam(unitID, "rearmProgress", perc)
    end
  end

end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Copy-pasta from unit_bomber_control
--local function Rearm(unitID)
--  local function GetFrames(unitID)
--    local currFrame = GetGameFrame()
--    local reloadFrame = 0
--    if reloadFrames[unitID] then
--      reloadFrame = reloadFrames[unitID]
--    end
--    return currFrame, reloadFrame
--  end
--
--  local unitDefID = GetUnitDefID(unitID)
--  local origAmmo = GetUnitRulesParam(unitID, "ammo")
--  local weaponsWithAmmo = tonumber(UnitDefs[unitDefID].customParams.weaponswithammo) or 1   -- 1 by default
--  local maxAmmo = tonumber(UnitDefs[unitDefID].customParams.maxammo)
--
--  if origAmmo < maxAmmo then
--    -- scale the number of loaded rounds per tick so that total reload time
--    -- never takes much more than RELOAD_AVERAGE_DURATION
--    -- (math.floor + 0.5 trick is because Lua lacks math.round, and we need integers)
--    local ammoToAdd = math.floor(maxAmmo * REARM_FREQUENCY / REARM_AVERAGE_DURATION + 0.5)
--    if ammoToAdd == 0 then
--      ammoToAdd = 1
--    end
--    local newAmmo = origAmmo + ammoToAdd
--    vehicles[unitID].ammoLevel = newAmmo
--    SetUnitRulesParam(unitID, "ammo", newAmmo)
--  end
--
--  local hasWeapon = UnitDefs[unitDefID].weapons[1]
--  local reload = hasWeapon and tonumber(WeaponDefs[hasWeapon.weaponDef].reload) or 1     -- default 1s
--
--  if origAmmo < 1 then
--    local currFrame, reloadFrame = GetFrames(unitID)
--    local reloadState = reloadFrame
--    if Spring.UnitScript.GetScriptEnv(unitID) then
--      return end
--    for weapNum = 1, weaponsWithAmmo do
--      SetUnitWeaponState(unitID, weapNum, {reloadTime = reload, reloadState = reloadFrame })
--      vehicles[unitID].reloadFrame[weapNum] = reloadFrame
--    end
--  end
--
--end