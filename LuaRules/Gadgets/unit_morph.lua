--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    unit_morph.lua
--  brief:   Adds unit morphing command
--  author:  Dave Rodgers (improved by jK, Licho, aegis, CarRepairer & MaDDoX)
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- Current formula for morph speed ups, according to the number and type of morph boosters
--    https://www.intmath.com/functions-and-graphs/graphs-using-svg.php
---atan(((x+2)^1.5)/80+(sin(x+2)/20))+0.875    -- tier1
---atan(((x+2)^1.75)/80+(sin(x+2)/20))+0.875	-- tier2
---Total Max: 3.2

---Tech booster gains: Lvl1 = 25%, Lvl2 = 33%, Lvl3 = 50% (cummulative multipliers, total max +100%)

function gadget:GetInfo()
  return {
    name      = "UnitMorph",
    desc      = "Adds unit morphing",
    author    = "trepan (improved by jK, Licho, aegis, CarRepairer, MaDDoX)",
    date      = "Jan, 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 500,
    enabled   = true
  }
end

--include "keysym.h.lua"  -- This is usually in \luaui, let's simply copy what we need here
KEYSYMS = {
  Q     = 113,
  SPACE = 32,
}

-- SpeedUps
local spEcho = Spring.Echo
local spGetAllUnits = Spring.GetAllUnits
local spDestroyUnit = Spring.DestroyUnit
local spSendMessageToTeam = Spring.SendMessageToTeam
local spGetGameFrame = Spring.GetGameFrame
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTransporter = Spring.GetUnitTransporter
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetTeamList     = Spring.GetTeamList
local spGetCommandQueue = Spring.GetCommandQueue
local spGetUnitExperience = Spring.GetUnitExperience
local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
local spRemoveUnitCmdDesc = Spring.RemoveUnitCmdDesc
local spEditUnitCmdDesc = Spring.EditUnitCmdDesc
local spGetSelUnitsCount = Spring.GetSelectedUnitsCount
local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local spGetTeamColor = Spring.GetTeamColor
local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spIsUnitInView = Spring.IsUnitInView
local spSetUnitResourcing = Spring.SetUnitResourcing
local spAddUnitResource   = Spring.AddUnitResource
local SpGiveOrderToUnit = Spring.GiveOrderToUnit

VFS.Include("gamedata/taptools.lua")

-- Changes for "The Cursed"
--		CarRepairer: may add a customized texture in the morphdefs, otherwise uses original behavior (unit buildicon).
--		aZaremoth: may add a customized text in the morphdefs
-- Changes for "Advanced BA"
--		Deadnight Warrior: may add a customized command name in the morphdefs, otherwise defaults to "Upgrade"
--				   you may use "$$unitname" and "$$into" in 'text', both will be replaced with human readable unit names
-- Changes by raaar (04/2012):
--      commented out the preservation of cmd queue and unit lineage at lines 536 and 559 (look for Spring.GiveOrderToUnit)
-- Changes by raaar (12/2013):
--      commented out turning unit off at lines 396 and 425, was giving errors in spring 95.0
-- Changes for "TA Prime" by _MaDDoX (12/2017):
--      Default buildtime, buildcostenergy and buildcostmetal is now the difference between original and target unit values
--      Accepts and prioritizes definitions in customData.morphdef
--      Properly talks to multi_tech.lua (tech tree gadget by zwzsg)
--      'require' entry now require techs instead of units
--      'require' supports multiple tech requirements (comma-separated)
--      Morph button text now shown in red when requirements not fulfilled
--      Added support and buttons for Morph Pause/Resume and Queue
--      'animationonly' entry (TRUE|FALSE) doesn't replace the model; it'll only fire up a "morphup" animation in the unit script
--          , by setting the 'morphedinto' unitRulesParam

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Proposed Command ID Ranges:
--
--    all negative:  Engine (build commands)
--       0 -   999:  Engine
--    1000 -  9999:  Group AI
--   10000 - 19999:  LuaUI
--   20000 - 29999:  LuaCob
--   30000 - 39999:  LuaRules
--

local CMD_MORPH = 31410
local CMD_MORPH_STOP = 32410
-- New buttons IDs (MaDDoX)
local CMD_MORPH_PAUSE = 33410
local CMD_MORPH_QUEUE = 34410

local MAX_MORPH = 0           --// Will increase dynamically

local lastMorphQueueFrame = 0 --// Used to prevent multiple queue messages at once
local INSTAMORPH = TRUE --FALSE      --// Debug option, will make all morphs take 0 seconds and cost 0 resources

--------------------------------------------------------------------------------
--region  COMMON
--------------------------------------------------------------------------------

--[[ // for use with any mod -_-
function GetTechLevel(udid)
  local ud = UnitDefs[udid];
  return (ud and ud.techLevel) or 0
end
]]--

function string:split( inSplitPattern, outResults )
  if not outResults then
    outResults = { }
  end
  local theStart = 1
  local theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
  while theSplitStart do
    table.insert( outResults, string.sub( self, theStart, theSplitStart-1 ) )
    theStart = theSplitEnd + 1
    theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
  end
  table.insert( outResults, string.sub( self, theStart ) )
  return outResults
end

-- // for use with mods like CA <_<
local function GetTechLevel(UnitDefID)
  --return UnitDefs[UnitDefID].techLevel or 0
  local cats = UnitDefs[UnitDefID].modCategories
  if (cats) then
    --// workaround, cuz lua doesn't remove uppercase :(
    if     (cats["LEVEL1"]) then return 1
    elseif (cats["LEVEL2"]) then return 2
    elseif (cats["LEVEL3"]) then return 3
    elseif (cats["level1"]) then return 1
    elseif (cats["level2"]) then return 2
    elseif (cats["level3"]) then return 3
    end
  end
  return 0
end

local function isFactory(UnitDefID)
  return UnitDefs[UnitDefID].isFactory or false
end

local function isDone(UnitID)
  local _,_,_,_,buildProgress = Spring.GetUnitHealth(UnitID)
  return (buildProgress==nil)or(buildProgress>=1)
end

local function HeadingToFacing(heading)
  --return math.floor((-heading - 24576) / 16384) % 4
  return math.floor((heading + 8192) / 16384) % 4
end

--------------------------------------------------------------------------------
--endregion COMMON
--------------------------------------------------------------------------------

if (gadgetHandler:IsSyncedCode()) then
  --------------------------------------------------------------------------------
  --region  SYNCED
  --------------------------------------------------------------------------------

  include("LuaRules/colors.h.lua")

  WhiteStr   = "\255\255\255\255"
  BlackStr   = "\255\001\001\001"
  GreyStr    = "\255\128\128\128"
  RedStr     = "\255\255\001\001"
  OrangeStr  = "\255\255\175\001"
  PinkStr    = "\255\255\064\064"
  GreenStr   = "\255\001\255\001"
  BlueStr    = "\255\001\001\255"
  CyanStr    = "\255\001\255\255"
  YellowStr  = "\255\255\255\001"
  MagentaStr = "\255\255\001\255"

  Colors = {}
  Colors.white   = { 1.0, 1.0, 1.0, 1.0 }
  Colors.black   = { 0.0, 0.0, 0.0, 1.0 }
  Colors.grey    = { 0.5, 0.5, 0.5, 1.0 }
  Colors.red     = { 1.0, 0.0, 0.0, 1.0 }
  Colors.green   = { 0.0, 1.0, 0.0, 1.0 }
  Colors.blue    = { 0.0, 0.0, 1.0, 1.0 }
  Colors.yellow  = { 1.0, 1.0, 0.0, 1.0 }
  Colors.cyan    = { 0.0, 1.0, 1.0, 1.0 }
  Colors.magenta = { 1.0, 0.0, 1.0, 1.0 }

  local stopPenalty  = 0.667
  local morphPenaltyUnits = 1.5 --1.6
  local morphPenaltyStructures = 1.4 --1.25, 1.33
  local morphtimePenaltyUnits = 1.5
  local minMorphTime, maxMorphTime = 10000, 600000
  -- Workertime to morph into targets @ tiers 0 (no tech requirement), 1, 2, 3 and 4
  local MorphWorkerTime = { 75, 340, 430, 1120, 3000 }
  -- DEBUG
  --local MorphWorkerTime = { 1500, 2000, 3500, 7000, 15000 } --debug

  local MaxMorphTimeBonus = 3.2 --3
  local XpScale = 1.0                --// Multiplier of previous unit's experience to apply to new unit

  local XpMorphUnits = {}

  local devolution = true            --// remove upgrade capabilities after factory destruction?
  local stopMorphOnDevolution = true --// should morphing stop during devolution

  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------

  local spGetUnitGroup = Spring.GetUnitGroup
  local spSetUnitGroup = Spring.SetUnitGroup
  local spGetUnitExperience = Spring.GetUnitExperience
  local spSetUnitExperience = Spring.SetUnitExperience
  local spSetUnitPosition = Spring.SetUnitPosition
  local spSendCommands = Spring.SendCommands
  local spSetUnitPosition = Spring.SetUnitPosition
  local spCreateUnit = Spring.CreateUnit
  local spGetUnitStates = Spring.GetUnitStates
  local spGiveOrderArrayToUnitArray = Spring.GiveOrderArrayToUnitArray
  local spSetUnitHealth = Spring.SetUnitHealth
  local spGetUnitShieldState = Spring.GetUnitShieldState
  local spSetUnitShieldState = Spring.SetUnitShieldState
  local spSetUnitRulesParam    = Spring.SetUnitRulesParam
  local spGetUnitHealth = Spring.GetUnitHealth
  local spSetUnitBlocking = Spring.SetUnitBlocking
  local spUseUnitResource = Spring.UseUnitResource
  local spGetTeamResources = Spring.GetTeamResources
  local spGetUnitBasePosition = Spring.GetUnitBasePosition
  local spGetUnitHeading = Spring.GetUnitHeading

  local morphDefs  = {}         --// made global in Initialize()
  local extraUnitMorphDefs = {} -- stores mainly planetwars morphs
  local hostName = nil          -- planetwars hostname
  local PWUnits = {}            -- planetwars units
  --local cleanRulesParam = {}    -- used to clean up temporary 'wasmorphed' unitRulesParam

  --  morphingUnits[unitID] = {  def = morphDef, progress = 0.0, increment = morphDef.increment,
  --                             morphID = morphID, pauseID, queueID, teamID = teamID, paused = false }
  local morphingUnits = {}    --// make it global in Initialize()

  local reqTechs = {}         --// {[techId]=true, ...} all possible techs which are used as a requirement for a morph
  local techboosters = { {id="booster1",bonus=1.25}, {id="booster2",bonus=1.33}, {id="booster3",bonus=1.5},}

  --// per team techlevel and owned MorphReq. units table
  local teamTechLevel = {}
  --// per team Queue Units
  --- TODO: Make it global, accessible by UNSYNCED
  local teamQueuedUnits = {}  -- [team:1..n]={ queuedUnits }
  local unitsToDestroy = {}   -- [uid:1..n]={frame:number}  :: Frame it was set to be removed from game
  --local queuedUnits = {}    -- [idx:1..n]={unitID=n, morphData={}}
  --local teamJustMorphed = {}       -- [teamID] = unitID | nil

  --// Prime: Removing support for Required Units
  local prereqCount = {}  -- UnitDefIDs which may be morphed; [teamId] [# of required UnitDefIDs currenty]
  --// Boosters could be, eg. techcenters. For each tech level the player has it, the faster the morphs would be globally (TAP not using it now)
  local boosters = {}     -- TechCenter [teamID][Tier] --eg.: TechCenters[1][1] == Player 1's Tier 1 techcenters

  local teamList = Spring.GetTeamList()
  for i=1,#teamList do
    local teamID = teamList[i]
    prereqCount[teamID]  = {}
    teamTechLevel[teamID]   = 0     -- Initialize how many techCenters of each tier this team owns
    --teamJustMorphed[teamID] = nil   -- When a unit has just finished morph, nil becomes its unitID (checkQueue resets it)
    boosters[teamID]     = {}
    teamQueuedUnits[teamID] = {}    -- Initialize the morph queue for this team

    -- currently only supports Tier 0 and 2 builders
    boosters[teamID][0] = 0
    boosters[teamID][2] = 0
  end

  -- Shallow table copy
  function table.clone(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
      copy = {}
      for orig_key, orig_value in pairs(orig) do
        copy[orig_key] = orig_value
      end
    else -- number, string, boolean, etc
      copy = orig
    end
    return copy
  end

  local morphCmdDesc = {
    --  id     = CMD_MORPH, -- added by the calling function because there is now more than one option
    type   = CMDTYPE.ICON,
    name   = 'Morph',
    cursor = 'Morph',  -- add with LuaUI?
    action = 'morph',
  }

  local morphStopCmdDesc = {
    id     = CMD_MORPH_STOP,
    type   = CMDTYPE.ICON,
    name   = 'Stop\nMorph',
    texture = 'luaui/images/gfxbuttons/cmd_morphstop.png',
    cursor = 'Morph',
    action = 'morph',
  }

  local morphQueueCmdDesc = {
    id     = CMD_MORPH_QUEUE, -- might be added by the calling function if/when supports more than one option
    type   = CMDTYPE.ICON,
    name   = 'Queue',
    texture = 'luaui/images/gfxbuttons/cmd_morphqueue.png',
    cursor = 'Morph',  -- add with LuaUI?
    action = 'morphqueue',
  }

  local morphPauseCmdDesc = {
    id     = CMD_MORPH_PAUSE,
    type   = CMDTYPE.ICON,
    name   = 'Pause',
    texture = 'luaui/images/gfxbuttons/cmd_morphpause.png',
    cursor = 'Morph',  -- add with LuaUI?
    action = 'morphpause',
  }

  --// will be replaced in Initialize()
  local RankToXp    = function() return 0 end
  local GetUnitRank = function() return 0 end

  local Max = math.max
  local Floor = math.floor

  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------


  --// translate lowercase UnitNames to real unitname (with upper-/lowercases)
  local defNamesL = {}
  for defName in pairs(UnitDefNames) do
    defNamesL[string.lower(defName)] = defName
  end

  local function isTechStructure(unitDefID)
    local unitDef = UnitDefs[unitDefID]
    return unitDef.customParams.func == "tech" or unitDef.customParams.iscommander
  end

  --// Calculates Default values | edited for TA Prime by MaDDoX
  local function DefCost(paramName, udSrc, udDst)
    if (INSTAMORPH) then
      return 0 end
    local function checkGroupSize(udef, paramName)
      local paramCost = udef[paramName]
      if udef.customParams and udef.customParams.groupsize then
        local udefgroupSize = tonumber(udef.customParams.groupsize)
        if udefgroupSize and udefgroupSize > 1 then
          paramCost = paramCost / udefgroupSize
        end
      end
      return paramCost
    end
    local function isStructure(udef)
      return udef.isImmobile or false
    end
    local pSrc = checkGroupSize(udSrc, paramName)--udSrc[paramName]
    local pTgt = checkGroupSize(udDst, paramName)--udDst[paramName]
    if ((not pSrc) or (not pTgt) or
            (type(pSrc) ~= 'number') or
            (type(pTgt) ~= 'number')) then
      spEcho('Morph '..paramName..' error: NaN found')
      return 0
    end

    local morphPenalty = morphPenaltyUnits
    -- buildtime cost is unaffected by unit time

    local cost = pTgt - pSrc

    if isStructure(udSrc) then
      if paramName ~= 'buildTime' then
        morphPenalty = morphPenaltyStructures
      end
    else
      if paramName == 'buildTime' then
        morphPenalty = morphtimePenaltyUnits
      end
    end
    cost = cost * morphPenalty
    if paramName == 'buildTime' then
      cost = math_clamp(minMorphTime, maxMorphTime, cost) -- morph time can never be out of this range
    end
    return Floor(Max(0, cost))
  end

  -- That's only called on initialize, to validate morph_defs.lua & custom data
  local function BuildMorphDef(udSrc, morphData)
    local udDst = UnitDefNames[defNamesL[string.lower(morphData.into)] or -1]
    if (not udDst) then
      if (not morphData.into) then
        spEcho('Morph gadget: Invalid "into" field within morphData')
      else
        spEcho('Morph gadget: Bad morph dst type: ' .. morphData.into)
      end
      return
    else
      local unitDef = udDst
      local newData = {}
      newData.into = udDst.id

      local requireDefined = -1
      local foundAllRequires = true
      local reqTier = 0
      if (morphData.require and GG.TechCheck) then
        --require = (UnitDefNames[defNamesL[string.lower(morphData.require)] or -1] or {}).id
        local requires = morphData.require:split(',')
        -- // All required technologies must be defined, or else invalidate
        for i = 1, #requires do
          -- Team 0 is used just as a filler here, the important is that the return ~= nil
          requireDefined = GG.TechCheck(requires[i], 0) ~= nil
          if (requireDefined) then
            if (requires[i]=="UberTech") then reqTier = 4
            elseif (requires[i]=="MohoTech") then reqTier = 3
            elseif (requires[i]=="AdvancedTech") then reqTier = 2
            elseif (requires[i]=="EnhancedTech") then reqTier = 1
            elseif (requires[i]=="Tech")  then reqTier = 0
            end
            reqTechs[requires[i]]=true              -- echo('Morph gadget: Requirement defined: ' .. requires[i])
          else
            foundAllRequires = false                -- echo('Morph gadget: Bad morph requirement: ' .. requires[i].." tech not found")           --require = -1
          end
        end
      end
      newData.require = foundAllRequires and morphData.require or -1

      -- Tech0: 250 (base), Tech1: 300, Tech2: 350, Tech3: 400, Tech4: 450
      local morphTime = morphData.time or (DefCost('buildTime', udSrc, udDst) / MorphWorkerTime[reqTier+1])
      if INSTAMORPH then
        morphTime = 1
      end
      --// DEBUG: All info about morphs default build times, including tier
      --spEcho("Base Morph time: "..udSrc.name.." -> "..udDst.name
      --        .." (calc) "..DefCost('buildTime', udSrc, udDst)/MorphWorkerTime[reqTier+1].." reqTier: "..reqTier)
      newData.time = morphTime
      newData.increment = (1 / (30 * newData.time))
      --Spring.Echo("morph to: "..morphData.into.." metal: "..(morphData.metal or "nil").." | energy: "..(morphData.energy or "nil"))
      newData.metal  = morphData.metal  or DefCost('metalCost',  udSrc, udDst)
      newData.energy = morphData.energy or DefCost('energyCost', udSrc, udDst)
      --Spring.Echo(" metal: "..newData.metal.." | energy: "..newData.energy.." | m-inc: "..newData.increment * newData.metal.." | e-inc: "..newData.increment * newData.energy)
      newData.resTable = {
        m = (newData.increment * newData.metal),
        e = (newData.increment * newData.energy)
      }
      newData.tech = morphData.tech or 0
      newData.xp   = morphData.xp or 0
      newData.rank = morphData.rank or 0
      newData.facing = morphData.facing
      newData.animationonly = morphData.animationonly or 0

      newData.cmd     = CMD_MORPH      + MAX_MORPH
      newData.stopCmd = CMD_MORPH_STOP + MAX_MORPH
      MAX_MORPH = MAX_MORPH + 1

      newData.texture = morphData.texture
      if morphData.text then
        newData.text = string.gsub(morphData.text, "$$unitname", udSrc.humanName)
        newData.text = string.gsub(newData.text, "$$into", udDst.humanName)
      else
        newData.text = morphData.text
      end
      if morphData.cmdname then
        newData.cmdname = morphData.cmdname
      else
        newData.cmdname = "Upgrade"
      end
      --if morphData.animationonly then
      --	newData.animationonly = morphData.animationonly
      --else
      --	newData.animationonly = FALSE
      --end
      return newData
    end
  end

  local function ValidateMorphDefs(morphDefs)
    local newDefs = {}
    for srcName,morphData in pairs(morphDefs) do
      --//#debug
      --    Spring.Echo("Source: "..src)
      --    for k,v in pairs(morphData) do
      --      Spring.Echo("K, V:"..tostring(k),v)
      --      for q,w in pairs(v) do
      --        Spring.Echo("-- morphData v: "..q,w)
      --      end
      --    end

      --The UnitDefNames[] table holds the unitdefs and can be used to get the unitdef table for a known unitname
      local srcUDef = UnitDefNames[defNamesL[string.lower(srcName)] or -1]
      if (not srcUDef) then
        spEcho('Morph gadget: Bad morph src type: ' .. srcName)
      else
        newDefs[srcUDef.name] = {}  -- was: id, now using name (eg.: armpw) instead
        if (morphData.into) then
          local morphDef = BuildMorphDef(srcUDef, morphData)
          if (morphDef) then newDefs[srcUDef.name][morphDef.cmd] = morphDef end
        else
          for _,morphData in pairs(morphData) do
            local morphDef = BuildMorphDef(srcUDef, morphData)
            if (morphDef) then newDefs[srcUDef.name][morphDef.cmd] = morphDef end
          end
        end
      end
    end
    return newDefs
  end

  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------

  -- //This is where multiple tech requirements check kick in.

  -- Previously it returned how many of the required unit type there are in the game
  --return ((teamReqUnits[teamID][reqTechs] or 0) > 0)
  -- Now it returns a list of all unreached techs
  local function TechReqList(teamID, reqTechs)
    if (reqTechs == -1) then
      return {} end

    local unreachedTechs = {}
    if (reqTechs and GG.TechCheck) then
      local requires = reqTechs:split(',')

      for i = 1, #requires do
        local hasRequire = GG.TechCheck(requires[i], teamID) == true
        if (not hasRequire) then
          unreachedTechs[#unreachedTechs+1] = requires[i] end
      end
    end

    return unreachedTechs
  end

  local function TechReqCheck(teamID, reqTechs)
    if (not reqTechs or reqTechs == -1 or not GG.TechCheck) then
      return true end

    local hasAllTechs = true
    local requires = reqTechs:split(',')

    for i = 1, #requires do
      local hasRequire = GG.TechCheck(requires[i], teamID) == true
      if not hasRequire then
        hasAllTechs = false
      end
    end

    return hasAllTechs
  end

  -- Return final MorphTimeBonus according to the amount of tech centers and the bonus table
  -- It applies a law of diminishing returns so that the second tech center of a type boosts
  -- more the morph speed than the third. If you build more than that there's no added bonus.
  --- Table of 3rd tech center gains:
  ---
  ---   1.11  / 1.15  (Tier 1)  || with 1 + (x-1)/2
  ---   1.18  / 1.2   (Tier 2)
  ---   1.375 / 1.25  (Tier 3)
  ---   1.45  / 1.3   (Tier 4)

  --- atan(((x+2)^1.5)/80+(sin(x+2)/20))+0.875    -- tier1
  ---atan(((x+2)^1.75)/80+(sin(x+2)/20))+0.875	-- tier2
  ---Total Max: 3.2

  local function GetMorphTimeBonus(unitTeam)
    local bonus = 1
    for teamID, tierCount in pairs(boosters) do   --eg.: builders[1][2] == Player 1's Tier 2 builder count
      if teamID == unitTeam then
        for i = 0, 2, 2 do     -- Only builders of tier 0 and 2 supported for now (start = 0, end = 2, step = 2)
          local x = boosters[teamID][i]
          if x > 0 then
            --Spring.Echo("TeamID:"..teamID.." Idx:"..i.." Builders: "..builders[teamID][i])
            --- atan(((x+2)^1.5)/80+(sin(x+2)/20))+0.875    -- tier1
            ---atan(((x+2)^1.75)/80+(sin(x+2)/20))+0.875	-- tier2
            local power = (i == 0) and 1.5 or 1.75
            local tierbonus = math.atan((math.pow(x+2,power)/80 + (math.sin(x+2)/20)))+0.875 --math.max (1,
            if i == 2 then
              tierbonus = math.min (1, tierbonus) -- T2 builders never present a penalty (first four T0 ones do)
            end
            --Spring.Echo(" tier: "..i.." builders: "..x.." tierbonus: ".. tierbonus)
            bonus = bonus + (tierbonus - 1)   -- We take the fractional part only
          end
        end
        break
      end
    end
    -- Check for Tech Boosters
    if GG.TechCheck then
      for i = 1, 3 do
        if GG.TechCheck(techboosters[i].id, unitTeam) then
          bonus = bonus * techboosters[i].bonus --1.25, 1.33, 1.5
        end
      end
    end
    --if bonus ~= 1 then
    --  spEcho("bonus: "..bonus) end
    if INSTAMORPH then
      return 10000 end
    return math.min (MaxMorphTimeBonus, bonus) -- max MaxMorphTimeBonus
  end

  local function GetMorphTooltip(unitID, unitDefID, teamID, morphDef, teamTech, unitXP, unitRank, unreachedTechs)
    local ud = UnitDefs[morphDef.into]
    local tt = ''
    if (morphDef.text ~= nil) then
      tt = tt .. WhiteStr  .. morphDef.text .. '\n'
    else
      --tt = tt .. WhiteStr  .. 'Upgrade into a ' .. ud.humanName .. '\n'
      tt = tt .. 'Upgrade into a ' .. ud.humanName .. '\n'
    end
    if (morphDef.time > 0) then
      local morphTimeBonus = GetMorphTimeBonus (spGetUnitTeam(unitID))
      tt = tt .. GreenStr  .. 'time: '   .. morphDef.time * (1/morphTimeBonus)    .. '\n'
    end
    if (morphDef.metal > 0) then
      tt = tt .. CyanStr   .. 'metal: '  .. morphDef.metal    .. '\n'
    end
    if (morphDef.energy > 0) then
      tt = tt .. YellowStr .. 'energy: ' .. morphDef.energy   .. '\n'
    end

------ This adds the metal/energy cost per second line
    local metalCost = math.floor(morphDef.metal + 0.5)
    local energyCost = math.floor(morphDef.energy + 0.5)
    local timeCost = math.floor(morphDef.time + 0.5)
    local metalCostPerSecond
    local energyCostPerSecond
    if timeCost ~= nil and timeCost ~= 0 then
      if metalCost ~= nil and metalCost ~= 0 then
        metalCostPerSecond = metalCost / timeCost
      else
        metalCostPerSecond = 0
      end
      if energyCost ~= nil and energyCost ~= 0 then
        energyCostPerSecond = energyCost / timeCost
      else
        energyCostPerSecond = 0
      end
      tt = tt .. CyanStr .. 'metal' .. WhiteStr .. ' / ' .. YellowStr .. 'energy' .. WhiteStr .. ' cost per second: ' .. CyanStr .. metalCostPerSecond .. WhiteStr .. " / " .. YellowStr .. energyCostPerSecond  .. '\n'
    end
------

    if (morphDef.tech > teamTech) or
            (morphDef.xp > unitXP) or
            (morphDef.rank > unitRank) or
            (unreachedTechs and #unreachedTechs >= 1)
    then
      tt = tt .. RedStr .. '\nRequires: '
      if (morphDef.tech>teamTech) then tt = tt .. ' level: ' .. morphDef.tech end
      if (morphDef.xp>unitXP)     then tt = tt .. ' xp: '    .. string.format('%.2f',morphDef.xp) end
      if (morphDef.rank>unitRank) then tt = tt .. ' rank: '  .. morphDef.rank .. ' (' .. string.format('%.2f',RankToXp(unitDefID,morphDef.rank)) .. 'xp)' end
      -- if (not teamOwnsReqUnit)	then tt = tt .. ' unit: '  .. UnitDefs[morphDef.require].humanName end
      -- Refactored to show unreached+required tech
      --tt = tt .. ' unit: '  .. reqTech[x]
      -- // Loop all unreachedTechs and add to the tooltip
      if (unreachedTechs and #unreachedTechs >= 1)	then
        local str = unreachedTechs[1]
        if #unreachedTechs > 1 then
          for i = 2, #unreachedTechs do
            str = str .. ', '..unreachedTechs[i]
          end
        end
        tt = tt..str
      end
    end
    return tt
  end

  -- Usage eg. UpdateCmdDesc(unitID, CMD_MORPH_PAUSE, morphPauseCmdDesc, disabled, tooltip)
  local function UpdateCmdDesc(unitID, CmdID, cmdArray) --disabled, tooltip
    local cmdDescIdx = spFindUnitCmdDesc(unitID, CmdID)
    if not cmdDescIdx then
      return end
    spEditUnitCmdDesc(unitID, cmdDescIdx, cmdArray)
  end

  local function UpdateMorphReqs(teamID)
    local newMorphCmdDesc = {}

    local teamTech  = teamTechLevel[teamID] or 0
    local teamUnits = Spring.GetTeamUnits(teamID)
    for n = 1,#teamUnits do
      local unitID   = teamUnits[n]
      local unitXP   = spGetUnitExperience(unitID)
      local unitRank = GetUnitRank(unitID)
      local unitDefID = spGetUnitDefID(unitID)

      local morphDefs = morphDefs[UnitDefs[unitDefID].name] or {}

      for _,morphDef in pairs(morphDefs) do
        local morphCmdDescIdx = spFindUnitCmdDesc(unitID, morphDef.cmd)
        if morphCmdDescIdx then
          local unreachedTechs = TechReqList(teamID, morphDef.require)
          newMorphCmdDesc.disabled = (morphDef.tech > teamTech) or (morphDef.rank > unitRank)
                  or (morphDef.xp > unitXP) or (#unreachedTechs > 0)
          --if (morphCmdDesc.disabled) then
          --  morphCmdDesc.name = "\255\255\64\64"..morphDef.cmdname    -- Reddish
          --else
          --  morphCmdDesc.name = "\255\255\255\255"..morphDef.cmdname
          --end
          newMorphCmdDesc.name = newMorphCmdDesc.disabled and "\255\255\64\64"..morphDef.cmdname
                  or "\255\255\255\255"..morphDef.cmdname
          newMorphCmdDesc.tooltip = GetMorphTooltip(unitID, unitDefID, teamID, morphDef, teamTech, unitXP,
                                                    unitRank, unreachedTechs)
          spEditUnitCmdDesc(unitID, morphCmdDescIdx, newMorphCmdDesc)
          -- Enable/disable pause and queue buttons
          --UpdateCmdDesc(unitID, CMD_MORPH_PAUSE, {disabled=true})
          --TODO: Remove time info from 'Pause' button
          UpdateCmdDesc(unitID, CMD_MORPH_QUEUE, {disabled=newMorphCmdDesc.disabled,
                                                  tooltip="Queue "..newMorphCmdDesc.tooltip})
        end
      end
    end
  end

  local function AddMorphButtons(unitID, unitDefID, teamID, morphDef, teamTech)
    local unitXP   = spGetUnitExperience(unitID)
    local unitRank = GetUnitRank(unitID)
    local teamReqTechs = TechReqList(teamID, morphDef.require)
    local teamHasTechs = teamReqTechs and #teamReqTechs == 0
    morphCmdDesc.tooltip = GetMorphTooltip(unitID, unitDefID, teamID, morphDef, teamTech, unitXP, unitRank, teamReqTechs)

    if morphDef.texture then
      morphCmdDesc.texture = "LuaRules/Images/Morph/".. morphDef.texture
    else
      morphCmdDesc.texture = "#" .. morphDef.into   --// only works with a patched layout.lua or the TweakedLayout widget!
    end
    morphCmdDesc.name = morphDef.cmdname

    -- Sets initial state of command buttons to be added to the unit
    morphCmdDesc.disabled = morphDef.tech > teamTech or morphDef.rank > unitRank
            or morphDef.xp > unitXP or not teamHasTechs
    morphStopCmdDesc.disabled = true
    morphQueueCmdDesc.disabled = morphCmdDesc.disabled
    morphQueueCmdDesc.tooltip = "Queue "..morphCmdDesc.tooltip
    morphPauseCmdDesc.disabled = true
    morphPauseCmdDesc.tooltip = "Pause/Resume Morph"

    morphCmdDesc.id = morphDef.cmd

    local cmdDescID = spFindUnitCmdDesc(unitID, morphDef.cmd)
    if (cmdDescID) then
      spEditUnitCmdDesc(unitID, cmdDescID, morphCmdDesc)
    else
      spInsertUnitCmdDesc(unitID, morphCmdDesc)
      spInsertUnitCmdDesc(unitID, morphStopCmdDesc)
      spInsertUnitCmdDesc(unitID, morphPauseCmdDesc)
      spInsertUnitCmdDesc(unitID, morphQueueCmdDesc)
    end

    morphCmdDesc.tooltip = nil
    morphCmdDesc.texture = nil
    morphCmdDesc.text = nil
  end

  local function AddExtraUnitMorph(unitID, unitDef, teamID, morphDef)  -- adds extra unit morph (planetwars morphing)
    morphDef = BuildMorphDef(unitDef, morphDef)
    extraUnitMorphDefs[unitID] = morphDef
    AddMorphButtons(unitID, unitDef.id, teamID, morphDef, 0)
  end

  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------


  local function ReAssignAssists(newUnit, oldUnit)
    if newUnit == nil or oldUnit == nil then
      return end
    local ally = spGetUnitAllyTeam(newUnit)
    local alliedTeams = spGetTeamList(ally)
    for n=1,#alliedTeams do
      local teamID = alliedTeams[n]
      local alliedUnits = spGetTeamUnits(teamID)
      for i=1,#alliedUnits do
        local unitID = alliedUnits[i]
        local cmds = spGetCommandQueue(unitID, 1)
        for j=1,#cmds do
          local cmd = cmds[j]
          if (cmd.id == CMD.GUARD)and(cmd.params[1] == oldUnit) then
            SpGiveOrderToUnit(unitID,CMD.INSERT,{cmd.tag,CMD.GUARD,0,newUnit},{})
            SpGiveOrderToUnit(unitID,CMD.REMOVE,{cmd.tag},{})
          end
        end
      end
    end
  end

  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------

  local function StartMorph(unitID, morphDef, teamID) --, cmdID)

    -- do not allow morph for unfinished units
    if not isDone(unitID) or not morphDef then
      return true end

    --Spring.SetUnitHealth(unitID, { paralyze = 1.0e9 })    --// turns mexes and mm off (paralyze the unit)
    --Spring.SetUnitResourcing(unitID,"e",0)                --// turns solars off
    --Spring.GiveOrderToUnit(unitID, CMD.ONOFF, { 0 }, { "alt" }) --// turns radars/jammers off

    --  DebugTable(morphDef)
    morphingUnits[unitID] = {
      def = morphDef,
      progress = 0.0,
      increment = morphDef and morphDef.increment or 0.01,
      morphID = nil, --morphID,
      teamID = teamID,
      paused = false,
    }

    -- Morph Started, disable Morph Button & enable stop morph button
    local cmdDescID = spFindUnitCmdDesc(unitID, morphDef.cmd)
    if cmdDescID then
      --spEditUnitCmdDesc(unitID, cmdDescID, {id=morphDef.stopCmd, name=RedStr.."Stop", disabled=false})
      spEditUnitCmdDesc(unitID, cmdDescID, {id=morphDef.cmd, disabled=true})
    end

    local stopCmdDescID = spFindUnitCmdDesc(unitID, CMD_MORPH_STOP)
    if stopCmdDescID then
      spEditUnitCmdDesc(unitID, stopCmdDescID, {disabled=false})
    end

    local queueDescID = spFindUnitCmdDesc(unitID, CMD_MORPH_QUEUE)
    if queueDescID then
      spEditUnitCmdDesc(unitID, queueDescID, {id=CMD_MORPH_QUEUE, disabled=true})
    end

    local pauseDescID = spFindUnitCmdDesc(unitID, CMD_MORPH_PAUSE)
    if pauseDescID then
      spEditUnitCmdDesc(unitID, pauseDescID, {id=CMD_MORPH_PAUSE, disabled=false})
    end

    SendToUnsynced("unit_morph_start", unitID, spGetUnitDefID(unitID), morphDef.cmd)
  end

  local function StartQueue(teamID)
    local queuedUnits = teamQueuedUnits[teamID]
    if queuedUnits and #queuedUnits > 0 then
      -- TODO: => Next Morph Set
      local nextMorph = queuedUnits[1]  -- Takes first in line
      -- Safe check. It shouldn't ever fall in here, but this is quite finicky so..
      --while not nextMorph.unitID and #queuedUnits > 1 do
      --  table.remove(queuedUnits, 1)
      --  nextMorph = queuedUnits[1]
      --end
      if not nextMorph.unitID or not spGetUnitDefID(nextMorph.unitID) then
        local idx = 1
        local element = queuedUnits[idx].unitID
        while not element and idx <= #queuedUnits do
          element = queuedUnits[idx]
          idx = idx +1
        end
        spSendMessageToTeam(teamID, "Morph Queue error for team: "..teamID..". Queued units count: "..#queuedUnits.." First valid Idx: "..idx)
        return
      end
      while not nextMorph.unitID and #queuedUnits > 1 do
        table.remove(queuedUnits, 1)
        nextMorph = queuedUnits[1]
      end
      if not nextMorph.unitID then
        return
      end

      local unitDefName = UnitDefs[spGetUnitDefID(nextMorph.unitID)].name
      local morphDef = morphDefs[unitDefName][nextMorph.cmdID]
      StartMorph(nextMorph.unitID, morphDef, nextMorph.teamID) --nextMorph.teamID, cmdID, unitID
    end
  end

  local function PauseMorph(unitID, morphData, cmdID)
    if not isDone(unitID) then return true end  -- unit not fully built yet
    local morphingUnit = morphingUnits[unitID]
    if not morphingUnit then
      return false end
    morphData.paused = not morphData.paused -- Switch state (pause/resume)
    -- Set button description to 'pause' (orange) or 'resume' (green text)

    local pauseDescID = spFindUnitCmdDesc(unitID, CMD_MORPH_PAUSE)
    if pauseDescID then
      local str = morphingUnit.paused and GreenStr.."Resume" or OrangeStr.."Pause"
      --Spring.Echo("Pausing/Resuming Morph: "..str)
      spEditUnitCmdDesc(unitID, pauseDescID, {name=str, tooltip="Pause/Resume Upgrade"})
    end

    SendToUnsynced("unit_morph_pause", unitID)
  end

  local function QueueMorph(unitID, teamID, startCmdID)
    -- morphData {def = morphDef, progress = 0.0, increment = morphDef.increment,
    --            morphID = morphID, teamID = teamID, paused = false }
    if not startCmdID then
      return end

    -- do not allow queue for unfinished units or if morph already started
    if not isDone(unitID) or morphingUnits[unitID]
            or ipairs_containsElement(teamQueuedUnits[teamID], "unitID", unitID) then
      --Spring.Echo("Unit already queued!")
      return end

    local insertIdx = #teamQueuedUnits[teamID]+1
    table.insert(teamQueuedUnits[teamID], {unitID=unitID, teamID=teamID, cmdID= startCmdID })

    if spGetGameFrame() > lastMorphQueueFrame then
      spSendMessageToTeam(teamID, "Queueing unit(s) at Position: "..tonumber(insertIdx))
      lastMorphQueueFrame = spGetGameFrame()
    end

    -- Disable start and queue buttons
    --local morphDef = (morphDefs[unitDefID] or {})[cmdID or 1] or extraUnitMorphDefs[unitID]
    local cmdDescID = spFindUnitCmdDesc(unitID, startCmdID)
    if cmdDescID then -- At this point, it's a morph_stop command
      spEditUnitCmdDesc(unitID, cmdDescID, {disabled=false}) --id=morphDef.cmd,
    end

    local queueDescID = spFindUnitCmdDesc(unitID, CMD_MORPH_QUEUE)
    if queueDescID then
      spEditUnitCmdDesc(unitID, queueDescID, {disabled=true})
    end

    local pauseDescID = spFindUnitCmdDesc(unitID, CMD_MORPH_PAUSE)
    if pauseDescID then
      spEditUnitCmdDesc(unitID, pauseDescID, {disabled=true}) -- id=CMD_MORPH_PAUSE,
    end

    --SendToUnsynced("unit_morph_start", unitID, unitDefID, morphDef.cmd)
  end

  -- This fires only after UnitDestroyed (or morph_stop), to resume morph queue
  local function checkQueue(unitID, teamID)
    -- Remove any morph-stopped unit from morph queue
    --//teamQueuedUnits :: [1..n]={ queuedUnits }
    --//queuedUnits :: [1..n]={unitID=n, morphData={}}
    local queuedUnits = teamQueuedUnits[teamID]
    --Spring.Echo("Queued unit count: "..#queuedUnits)
    local idx = ipairs_containsElement(queuedUnits, 'unitID', unitID)
    while idx do -- Was the destroyed unit in this player's queue?
      --if idx ~= 1 then
      --  Spring.Echo("Remove Index: "..idx) end
      table.remove(teamQueuedUnits[teamID], idx)
      --If destroyed/stopMorph'ed unitID is the head, resume queue
      local isHead = idx == 1
      if isHead then
        StartQueue(teamID) end
      --else
      --  Spring.Echo("Check Queue: unit wasn't found: "..unitID.." on team: "..teamID)
      idx = ipairs_containsElement(queuedUnits, 'unitID', unitID)
    end
  end

  local function StopMorph(unitID, morphData)
    checkQueue(unitID, morphData.teamID)
    morphingUnits[unitID] = nil

    --Spring.SetUnitHealth(unitID, { paralyze = -1})
    local scale = morphData.progress * stopPenalty
    local unitDefID = spGetUnitDefID(unitID)

    spSetUnitResourcing(unitID,"e", UnitDefs[unitDefID].energyMake)
    -- Spring.GiveOrderToUnit(unitID, CMD.ONOFF, { 1 }, { "alt" })
    local usedMetal  = morphData.def.metal  * scale
    spAddUnitResource(unitID, 'metal',  usedMetal)
    --local usedEnergy = morphData.def.energy * scale
    --Spring.AddUnitResource(unitID, 'energy', usedEnergy)

    SendToUnsynced("unit_morph_stop", unitID)

    --local cmdDescIdx = spFindUnitCmdDesc(unitID, morphData.def.stopCmd) -- Currently only handling one stop_morph
    --if cmdDescIdx then
    --  spEditUnitCmdDesc(unitID, cmdDescIdx, { id=morphData.def.cmd, name=morphData.def.cmdname})
    --end

    local cmdDescIdx = spFindUnitCmdDesc(unitID, morphData.def.cmd)
    if cmdDescIdx then
      spEditUnitCmdDesc(unitID, cmdDescIdx, { id=morphData.def.cmd, disabled=false})
    end

    local queueDescID = spFindUnitCmdDesc(unitID, CMD_MORPH_STOP)
    if queueDescID then
      spEditUnitCmdDesc(unitID, queueDescID, {id=CMD_MORPH_STOP, disabled=true})
    end

    local queueDescID = spFindUnitCmdDesc(unitID, CMD_MORPH_QUEUE)
    if queueDescID then
      spEditUnitCmdDesc(unitID, queueDescID, {id=CMD_MORPH_QUEUE, disabled=false})
    end

    local pauseDescID = spFindUnitCmdDesc(unitID, CMD_MORPH_PAUSE)
    if pauseDescID then
      spEditUnitCmdDesc(unitID, pauseDescID, {id=CMD_MORPH_PAUSE, disabled=true})
    end
  end

  local function FinishMorph(unitID, morphData)
    if unitID == nil then
      return end
    local udDst = UnitDefs[morphData.def.into]
    --local ud = UnitDefs[unitID]
    local defName = udDst.name
    local unitTeam = morphData.teamID
    local px, py, pz = spGetUnitBasePosition(unitID)
    local h = spGetUnitHeading(unitID)
    spSetUnitBlocking(unitID, false)
    morphingUnits[unitID] = nil
    spSetUnitRulesParam(unitID, "justmorphed", 1)
    --[Deprecated] After 10 frames, we'll clean up this unitRulesParam, to allow explosions after this time frame
    --cleanRulesParam[unitID] = Spring.GetGameFrame()+10

    local oldHealth,oldMaxHealth,paralyzeDamage,captureProgress,buildProgress = spGetUnitHealth(unitID)
    local isBeingBuilt = false
    if buildProgress < 1 then
      isBeingBuilt = true end

    local newUnit = nil
    local face = HeadingToFacing(h)

    --Spring.Echo("Animation Only: ", morphData.def.animationonly)
    if (morphData.def.animationonly == 1) then
      local env = Spring.UnitScript.GetScriptEnv(unitID)
      if env then
        if env.MorphUp then
          Spring.UnitScript.CallAsUnit(unitID, env.MorphUp) end
      end
      local newBuildSpeed, newMass, newMaxHealth, newTooltip  = udDst.buildSpeed, udDst.mass, udDst.health, (udDst.humanName .." - ".. udDst.tooltip)
      local orgHealth, orgMaxHealth = spGetUnitHealth(unitID)
      local newHealth = (orgHealth/orgMaxHealth) * newMaxHealth
      local newBuildTime, newMetalCost, newEnergyCost = udDst.buildTime, udDst.metalCost, udDst.energyCost
      --Spring.Echo("newbt, newmc, newec: "..(newBuildTime or "nil")..", "..(newMetalCost or "nil")..", "..(newEnergyCost or "nil"))

      Spring.SetUnitBuildSpeed ( unitID, newBuildSpeed )	--currently used only by factories, so only buildspeed needed
      Spring.SetUnitMass ( unitID, newMass )
      Spring.SetUnitMaxHealth ( unitID, newMaxHealth )
      Spring.SetUnitHealth( unitID, newHealth )
      --Spring.Echo("New values (buildspeed, mass, health, maxhealth): ", newBuildSpeed, newMass, newHealth, newMaxHealth )
      Spring.SetUnitTooltip ( unitID, newTooltip )	--"advanced bot lab - "
      Spring.SetUnitCosts ( unitID, { metalCost = newMetalCost, energyCost = newEnergyCost, buildTime = newBuildTime })
      SendToUnsynced("unit_morph_finished", unitID, unitID)
      spSetUnitRulesParam(unitID, "morphedinto", 1)
      spSetUnitRulesParam(unitID, "upgraded", 1)	--That's to be consumed by the per-unit upgrade handler ("puu")
    else
      --- Is it a structure?
      if udDst.isBuilding or udDst.isFactory then
        --if udDst.isBuilding then

        local x = math.floor(px/16)*16
        local y = py
        local z = math.floor(pz/16)*16

        local xsize = udDst.xsize
        local zsize =(udDst.zsize or udDst.ysize)
        if ((face == 1) or(face == 3)) then
          xsize, zsize = zsize, xsize
        end
        if xsize/4 ~= math.floor(xsize/4) then
          x = x+8
        end
        if zsize/4 ~= math.floor(zsize/4) then
          z = z+8
        end
        newUnit = spCreateUnit(defName, x, y, z, face, unitTeam)
        if newUnit then
          spSetUnitPosition(newUnit, x, y, z) end
        --- it's a mobile unit
      else
        newUnit = spCreateUnit(defName, px, py, pz, face, unitTeam)
        --Spring.SetUnitRotation(newUnit, 0, -h * math.pi / 32768, 0)
        if newUnit then
          spSetUnitPosition(newUnit, px, py, pz)
          spSetUnitRulesParam(unitID, "morphedinto", 1)
        end
      end
      -- Below is consumed in update (without it, last commander-ends might be triggered by mistake (!))
      unitsToDestroy[unitID] = spGetGameFrame() + 1   -- Set frame for the unit to be removed from game
    end

    -- Safe check. All code below should only run if a new unit was successfully created
    if newUnit == nil then
      return end

    --if (extraUnitMorphDefs[unitID] ~= nil) then
    ---- nothing here for now
    --end

    if (hostName ~= nil) and PWUnits[unitID] then
      -- send planetwars deployment message
      PWUnit = PWUnits[unitID]
      PWUnit.currentDef=udDst
      local data = PWUnit.owner..","..defName..","..math.floor(px)..","..math.floor(pz)..",".."S"
      spSendCommands("w "..hostName.." pwmorph:"..data)
      extraUnitMorphDefs[unitID] = nil
      GG.PlanetWars.units[unitID] = nil
      GG.PlanetWars.units[newUnit] = PWUnit
      SendToUnsynced('PWCreate', unitTeam, newUnit)
    elseif (not morphData.def.facing) then  -- set rotation only if unit is not planetwars and facing is not true
      --Spring.Echo(morphData.def.facing)
      --Spring.SetUnitRotation(newUnit, 0, -h * math.pi / 32768, 0)
    end

    --//copy experience & group
    local newXp = spGetUnitExperience(unitID)*XpScale
    local nextMorph = morphDefs[morphData.def.into]
    --  local oldGroup = spGetUnitGroup(unitID)
    if nextMorph~= nil and nextMorph.into ~= nil then nextMorph = {morphDefs[morphData.def.into]} end
    if (nextMorph) then --//determine the lowest xp req. of all next possible morphs
      local maxXp = math.huge
      for _, nm in pairs(nextMorph) do
        local rankXpInto = RankToXp(nm.into,nm.rank)
        if (rankXpInto>0)and(rankXpInto<maxXp) then
          maxXp=rankXpInto
        end
        local xpInto     = nm.xp
        if (xpInto>0)and(xpInto<maxXp) then
          maxXp=xpInto
        end
      end
      newXp = math.min( newXp, maxXp*0.9)
    end
    if newUnit and newXp then
      spSetUnitExperience(newUnit, newXp)
    end
    --spSetUnitGroup(newUnit, oldGroup)

    --//copy some state
    local states = spGetUnitStates(unitID)
    spGiveOrderArrayToUnitArray({ newUnit }, {
      { CMD.FIRE_STATE, { states.firestate },             { } },
      { CMD.MOVE_STATE, { states.movestate },             { } },
      { CMD.REPEAT,     { states["repeat"] and 1 or 0 },  { } },
      { CMD.CLOAK,      { states.cloak     and 1 or udDst.initCloaked },  { } },
      { CMD.ONOFF,      { 1 },                            { } },
      { CMD.TRAJECTORY, { states.trajectory and 1 or 0 }, { } },
    })

    --//Copy command queue        [deprecated]FIX : removed 04/2012, caused erros
    -- Now copies only move/patrol commands from queue, shouldn't pose any issues
    local cmdqueuesize = Spring.GetUnitCommands(unitID, 0)
    if type(cmdqueuesize) == "number" then
      local cmds = Spring.GetUnitCommands(unitID,100)
      for i = 1, cmdqueuesize do  -- skip the first command (CMD_MORPH)
        local cmd = cmds[i]
        if istable(cmd) and cmd.id and (cmd.id == CMD.MOVE or cmd.id == CMD.PATROL) then
          local m = { x = cmd.params[1], z = cmd.params[3] }
          if m.x and m.z then
            local y = Spring.GetGroundHeight(m.x, m.z)
            Spring.GiveOrderToUnit(newUnit, CMD.INSERT,
                                   {-1, cmd.id, CMD.OPT_SHIFT, m.x, y, m.z}, {"alt"}
            )
          end
        end
      end
    end

    --//reassign assist commands to new unit
    ReAssignAssists(newUnit, unitID)

    --// copy health
    local oldHealth,oldMaxHealth,_,_,buildProgress = spGetUnitHealth(unitID)
    local _,newMaxHealth         = spGetUnitHealth(newUnit)
    local newHealth = (oldHealth / oldMaxHealth) * newMaxHealth
    if newHealth<=1 then newHealth = 1 end
    spSetUnitHealth(newUnit, {health = newHealth, build = buildProgress})

    --// copy shield power
    local enabled,oldShieldState = spGetUnitShieldState(unitID)
    if oldShieldState and spGetUnitShieldState(newUnit) then
      spSetUnitShieldState(newUnit, enabled,oldShieldState)
    end

    --// FIXME: - re-attach to current transport?
    --// Send to unsynced so it can broadcast to widgets (and update selection here)
    SendToUnsynced("unit_morph_finished", unitID, newUnit)

    spSetUnitBlocking(newUnit, true)
  end

  -- Here's where the Morph is updated
  local function UpdateMorph(unitID, morphData, bonus)
    if not unitID or not morphData or not morphData.def then
      return false end
    -- Morph is paused either explicity or when unit is not finished being built or is being transported
    if not isDone(unitID) or morphData.paused or spGetUnitTransporter(unitID) then
      return true end               -- true => Morph is still enabled

    -- Workaround for a weird edge case with team-less units breaking the gadget
    local teamID = spGetUnitTeam(unitID)
    if not teamID then
      return false -- remove from list and get out of here
    end

    --- If we're stalled on E or M and it's a mobile unit, don't move on
    --- Workaround, without it multiple simultaneous morphs might complete without sufficient resources
    local currentM, storageM, pullM = spGetTeamResources(teamID, "metal") --currentLevel, storage, pull, income, expense
    local currentE, storageE, pullE = spGetTeamResources(teamID, "energy")
    --Spring.Echo("currentLevel, storage, pull, income, expense: ",currentM, storage, pullM, income, expense)

    local deficitFactor = 1
    -- If we're below 2% of metal, or energy, apply deficit to slow down morphs
    if currentM / storageM < 0.02 then
      local pullM = pullM - currentM
      local deficitMin, deficitMax = 0, 300
      -- First we make sure pullM is in the desired range, then we find the deficitFactor interpolator, from 0.01 to 1
      deficitFactor = lerp(1, 0.01, inverselerp(deficitMin, deficitMax, math_clamp(deficitMin, deficitMax, pullM)))
    elseif currentE / storageE < 0.02 then
      local pullE = pullE - currentE
      local deficitMin, deficitMax = 0, 3000
      deficitFactor = lerp(1, 0.01, inverselerp(deficitMin, deficitMax, math_clamp(deficitMin, deficitMax, pullE)))
    end
    if deficitFactor ~= 1 then
      --Spring.Echo("Deficit factor: "..deficitFactor)
      bonus = bonus * deficitFactor
    end

    -- To implement proper "upkeep" when on deficit, reduce costs and progress proportionally.
    if bonus > 0 and spUseUnitResource(unitID, { ["m"] = morphData.def.resTable.m * bonus,
                                                 ["e"] = morphData.def.resTable.e * bonus }) then
      morphData.progress = morphData.progress + (morphData.increment * bonus)
    end
    if morphData.progress >= 1.0 then
      FinishMorph(unitID, morphData)
      return false -- remove from the list, all done
    end
    return true    -- continue with morph
  end

  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------

  --// Add MorphDefs from customData entries (TODO: allow data merge with customParams, currently only overrides)
  local function AddCustomMorphDefs()
    for id,unitDef in pairs(UnitDefs) do
      -- Below params can be defined directly into unitdef customParams. Tables may be decoded in alldefs_post (from UnitDefsData)
      if unitDef.customParams.morphdef__into then
        local customMorphDef = {
          into = unitDef.customParams.morphdef__into,
          time = tonumber(unitDef.customParams.morphdef__time),
          require = unitDef.customParams.morphdef__require,
          metal = tonumber(unitDef.customParams.morphdef__metal),
          energy = tonumber(unitDef.customParams.morphdef__energy),
          --TODO: xp, rank, tech, texture
          cmdname = unitDef.customParams.morphdef__cmdname,
          text = unitDef.customParams.morphdef__text,
          animationonly = tonumber(unitDef.customParams.morphdef__animationonly),
          --isfactory = tobool(unitDef.customParams.morphdef__isfactory),   -- Will enable buildOptions according to the target unit;
          ---- will also update the morphdef once morph is done
        }
        morphDefs[unitDef.name] = customMorphDef
      end
    end
  end

  function gadget:Initialize()
    --// RankApi linking
    if (GG.rankHandler) then
      GetUnitRank = GG.rankHandler.GetUnitRank
      RankToXp    = GG.rankHandler.RankToXp
    end

    if GG.TechInit then
      for i = 1, 3 do
        GG.TechInit(techboosters[i].id)
      end
    end

    -- self linking for planetwars
    GG['morphHandler'] = {}
    GG['morphHandler'].AddExtraUnitMorph = AddExtraUnitMorph

    hostName = GG.PlanetWars and GG.PlanetWars.options.hostname or nil
    PWUnits = GG.PlanetWars and GG.PlanetWars.units or {}

    if (type(GG.UnitRanked)~="table") then GG.UnitRanked = {} end
    table.insert(GG.UnitRanked, UnitRanked)

    --// get the morphDefs
    morphDefs = include("gamedata/morph_defs.lua")

    --// MorphDefs can now be all defined in customParams (by MaDDoX)
    AddCustomMorphDefs()
    morphDefs = ValidateMorphDefs(morphDefs)
    --DebugTable(morphDefs)

    --  if (not morphDefs)
    --    then gadgetHandler:RemoveGadget()
    --    return end

    --// make it global for unsynced access via SYNCED
    _G.morphUnits = morphingUnits
    _G.teamQUnits = teamQueuedUnits
    _G.morphDefs  = morphDefs
    _G.extraUnitMorphDefs  = extraUnitMorphDefs

    --// Register CmdIDs
    for number = 0, MAX_MORPH-1 do
      gadgetHandler:RegisterCMDID(CMD_MORPH + number)
      gadgetHandler:RegisterCMDID(CMD_MORPH_STOP + number)
      --gadgetHandler:RegisterCMDID(CMD_MORPH_PAUSE) --TODO: RegisterCMDID MorphPause + number
    end

    local allUnits = spGetAllUnits()
    for i = 1, #allUnits do
      local unitID    = allUnits[i]
      local unitDefID = spGetUnitDefID(unitID)
      local unitDefName = UnitDefs[unitDefID].name
      local teamID    = spGetUnitTeam(unitID)
      --// Deprecated, now just checks existing technologies on start
      --    if (reqTechs[unitDefID])and(isFinished(unitID)) then
      --      local morphUnits = morphableUnits[teamID]
      --      morphUnits[unitDefID] = (morphUnits[unitDefID] or 0) + 1
      --    end
      UpdateMorphReqs(teamID)
      AddFactory(unitID, unitDefID, teamID)
      local morphDefSet  = morphDefs[unitDefName]
      if (morphDefSet) then
        local useXPMorph = false
        for _,morphDef in pairs(morphDefSet) do
          if (morphDef) then
            local cmdDescID = spFindUnitCmdDesc(unitID, morphDef.cmd)
            if (not cmdDescID) then
              AddMorphButtons(unitID, unitDefName, teamID, morphDef, teamTechLevel[teamID])
            end
            useXPMorph = (morphDef.xp > 0) or useXPMorph
          end
        end
        if (useXPMorph) then
          XpMorphUnits[#XpMorphUnits+1] = { id=unitID, defID= unitDefName, team=teamID} end
      end
    end

  end

  function gadget:Shutdown()
    for i,f in pairs(GG.UnitRanked or {}) do
      if f == UnitRanked then
        table.remove(GG.UnitRanked, i)
        break
      end
    end

    local allUnits = spGetAllUnits()
    for i=1,#allUnits do
      local unitID    = allUnits[i]
      local morphData = morphingUnits[unitID]
      if (morphData) then
        StopMorph(unitID, morphData)
      end
      for number=0,MAX_MORPH-1 do
        local cmdDescID = spFindUnitCmdDesc(unitID, CMD_MORPH+number)
        if (cmdDescID) then
          spRemoveUnitCmdDesc(unitID, cmdDescID)
        end
      end
    end
  end

  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------

  -- When a unit starts being built, still in green-placeholder mode
  function gadget:UnitCreated(unitID, unitDefID, teamID)
    local morphDefSet = morphDefs[UnitDefs[unitDefID].name]
    if (morphDefSet) then
      local useXPMorph = false
      for _,morphDef in pairs(morphDefSet) do
        if (morphDef) then
          AddMorphButtons(unitID, unitDefID, teamID, morphDef, teamTechLevel[teamID])
          useXPMorph = (morphDef.xp > 0) or useXPMorph
        end
      end
      if useXPMorph then
        XpMorphUnits[#XpMorphUnits+1] = {id=unitID,defID=unitDefID,team=teamID} end
    end
  end

  -- Makes sure the builders table is properly initialized for a given unitTeam/tier
  local function checkBoostersTable(boosterTable, unitTeam, tier)
    if not boosterTable[unitTeam] then
      boosterTable[unitTeam] = {} end
    if not boosterTable[unitTeam][tier] then
      boosterTable[unitTeam][tier] = 0 end
    return boosterTable
  end

  -- Count all morph-boosters in the game (currently metal converters)
  local function UpdateMorphBoosters(unitID, unitDefID, added)
    local ud = UnitDefs[unitDefID]
    if ud == nil or ud.customParams.func ~= "converter" then
      return end

    local unitTeam = spGetUnitTeam(unitID)
    local tier = tonumber(ud.customParams.tier)
    boosters = checkBoostersTable(boosters, unitTeam, tier)
    local newValue = added and boosters[unitTeam][tier] + 1
            or boosters[unitTeam][tier] - 1

    boosters[unitTeam][tier] = newValue
    --spEcho("Updated one Tier "..ud.customParams.tier.." builder from team "..unitTeam
    --        ..", now: "..builders[unitTeam][tier])
  end

  -- When a unit is completed, it must re-check morphing prereqs, since some tech could've been unlocked
  function gadget:UnitFinished(unitID, unitDefID, teamID)
    local bfrTechLevel = teamTechLevel[teamID] or 0
    AddFactory(unitID, unitDefID, teamID)

    UpdateMorphBoosters(unitID, unitDefID, true)
    UpdateMorphReqs(teamID)

    --  if (bfrTechLevel ~= teamTechLevel[teamID]) then
    --    UpdateMorphReqs(teamID)
    --  end
  end

  function gadget:UnitDestroyed(unitID, unitDefID, teamID)
    --.." was just morphed? "..tostring(teamJustMorphed[teamID]==unitID))
    checkQueue(unitID, teamID)
    local morphData = morphingUnits[unitID]
    if morphData then
      StopMorph(unitID, morphData) end

    local prevTechLevel = teamTechLevel[teamID] or 0

    RemoveFactory(unitID, unitDefID, teamID)

    local updateButtons = false
    --TODO: Devolution enabled by lack of prerequisites should be added here, if needed
    --if isDone(unitID) then --reqTechs[techId]
    -- Reduces 1 from amount of required units found
    --prereqCount[teamID][unitDefID] = (prereqCount[teamID][unitDefID] or 1) - 1
    --if (prereqCount[teamID][unitDefID] <= 0) then
    --  StopMorphsOnDevolution(teamID)
    --  updateButtons = true
    --end
    --end
    UpdateMorphBoosters(unitID, unitDefID, false) --removed

    if prevTechLevel ~= teamTechLevel[teamID] then
      StopMorphsOnDevolution(teamID)
      updateButtons = true
    end

    --if updateButtons then
    UpdateMorphReqs(teamID) --end
  end

  function gadget:UnitTaken(unitID, unitDefID, oldTeamID, teamID)
    self:UnitCreated(unitID, unitDefID, teamID)
    if isDone(unitID) then
      self:UnitFinished(unitID, unitDefID, teamID)
    end
  end

  function gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
    self:UnitDestroyed(unitID, unitDefID, oldTeamID)
  end

  function UnitRanked(unitID,unitDefID,teamID,newRank,oldRank)
    local morphDefSet = morphDefs[UnitDefs[unitDefID].name]

    if (morphDefSet) then
      local teamTech = teamTechLevel[teamID] or 0
      local unitXP   = spGetUnitExperience(unitID)
      for _, morphDef in pairs(morphDefSet) do
        if (morphDef) then
          local cmdDescID = spFindUnitCmdDesc(unitID, morphDef.cmd)
          if (cmdDescID) then
            local morphCmdDesc = {}
            local teamReqTechs = TechReqList(teamID,morphDef.require)
            local teamHasTechs = teamReqTechs and #teamReqTechs == 0

            morphCmdDesc.disabled = (morphDef.tech > teamTech) or (morphDef.rank > newRank)
                    or (morphDef.xp > unitXP) or (not teamHasTechs)
            morphCmdDesc.tooltip  = GetMorphTooltip(unitID, unitDefID, teamID, morphDef, teamTech, unitXP, newRank, teamReqTechs)
            spEditUnitCmdDesc(unitID, cmdDescID, morphCmdDesc)
          end
        end
      end
    end
  end


  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------


  function AddFactory(unitID, unitDefID, teamID)
    if (isFactory(unitDefID)) then
      local unitTechLevel = GetTechLevel(unitDefID)
      if (unitTechLevel > teamTechLevel[teamID]) then
        teamTechLevel[teamID]=unitTechLevel
      end
    end
  end

  -- unitID was destroyed, check if is factory
  function RemoveFactory(unitID, unitDefID, teamID)
    if (devolution)and(isFactory(unitDefID))and(isDone(unitID)) then

      --// check all factories and determine team level
      local level = 0
      local teamUnits = spGetTeamUnits(teamID)
      for i=1,#teamUnits do
        local unitID2 = teamUnits[i]
        if (unitID2 ~= unitID) then
          local unitDefID2 = spGetUnitDefID(unitID2)
          if (isFactory(unitDefID2) and isDone(unitID2)) then
            local unitTechLevel = GetTechLevel(unitDefID2)
            if (unitTechLevel>level) then level = unitTechLevel end
          end
        end
      end

      if (level ~= teamTechLevel[teamID]) then
        teamTechLevel[teamID] = level
      end

    end
  end

  function StopMorphsOnDevolution(teamID)
    if (stopMorphOnDevolution) then
      for unitID, morphData in pairs(morphingUnits) do
        local morphDef = morphData.def
        if (morphData.teamID == teamID)
                and morphDef.tech > teamTechLevel[teamID]
                or not TechReqCheck(teamID, morphDef.require)
        then
          StopMorph(unitID, morphData)
        end
      end
    end
  end

  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------

  function gadget:GameFrame(n)

    --if n == startFrame then

    --end

    -- We do a next-frame destroy to prevent upgraded last-commanders inadvertently finishing the game
    for uID, frame in pairs(unitsToDestroy) do
      if n >= frame then
        --Remark: This will fire up UnitDestroyed > checkQueue > StartQueue if/when needed
        spDestroyUnit(uID, false, true) -- selfd = false, reclaimed = true
        unitsToDestroy[uID]=nil
      end
    end

    --if n % 5 < 0.01 then
    --    for uID, frame in pairs(cleanRulesParam) do
    --        if n >= frame then
    --            spSetUnitRulesParam(uID, "wasmorphed", 0)
    --        end
    --    end
    --end

    if (n+24)%45 < 0.01 then --%150
      --AddCustomMorphDefs()

      local unitCount = #XpMorphUnits
      local i = 1

      while i <= unitCount do
        local unitdata    = XpMorphUnits[i]
        local unitID      = unitdata.id
        local unitDefID   = unitdata.defID

        local morphDefSet = morphDefs[UnitDefs[unitDefID].name]
        if (morphDefSet) then
          local teamID   = unitdata.team
          local teamTech = teamTechLevel[teamID] or 0
          local unitXP   = spGetUnitExperience(unitID)
          local unitRank = GetUnitRank(unitID)

          local xpMorphLeft = false
          for _,morphDef in pairs(morphDefSet) do
            if (morphDef) then
              local cmdDescIdx = spFindUnitCmdDesc(unitID, morphDef.cmd)
              if (cmdDescIdx) then
                local morphCmdDesc = {}
                local teamOwnsReqUnit = TechReqList(teamID, morphDef.require)
                morphCmdDesc.disabled = morphDef.tech > teamTech or morphDef.rank > unitRank or morphDef.xp > unitXP or not teamOwnsReqUnit
                morphCmdDesc.tooltip  = GetMorphTooltip(unitID, unitDefID, teamID, morphDef, teamTech, unitXP, unitRank, teamOwnsReqUnit)
                spEditUnitCmdDesc(unitID, cmdDescIdx, morphCmdDesc)

                xpMorphLeft = morphCmdDesc.disabled or xpMorphLeft
              end
            end
          end
          if not xpMorphLeft then
            --// remove unit from list (it fulfills all XP requirements)
            XpMorphUnits[i] = XpMorphUnits[unitCount]
            XpMorphUnits[unitCount] = nil
            unitCount = unitCount - 1
            i = i - 1
          end
        end
        i = i + 1
      end
    end

    for unitID, morphData in pairs(morphingUnits) do
      local bonus = GetMorphTimeBonus(spGetUnitTeam(unitID))
      if not UpdateMorph(unitID, morphData, bonus) then
        morphingUnits[unitID] = nil
      end
    end
  end

  local function getMorphDef(unitID, unitDefID, cmdID)
    return (morphDefs[UnitDefs[unitDefID].name] or {})[cmdID] or extraUnitMorphDefs[unitID]
  end

  local function hasTech(unitID, unitDefID, teamID, cmdID)
    local morphDef = getMorphDef(unitID, unitDefID, cmdID)
    if morphDef and morphDef.tech <= teamTechLevel[teamID]
            and morphDef.rank <= GetUnitRank(unitID)
            and morphDef.xp <= spGetUnitExperience(unitID)
            and TechReqCheck(teamID, morphDef.require)
    then
      return true end
    return false
  end

  -- Processes morph-related command buttons
  -- AllowCommand: called when the command is given, before the unit's queue is altered
  function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
    local morphData = morphingUnits[unitID]   -- def = morphDef, progress = 0.0, increment = morphDef.increment,
    --                                           morphID = morphID, teamID = teamID, paused = false
    if morphData then
      if cmdID == CMD_MORPH_STOP then  -- or (cmdID == CMD.STOP)
        if not spGetUnitTransporter(unitID) then
          StopMorph(unitID, morphData)
          return false
        end
      elseif cmdID == CMD.ONOFF then
        return false
        --elseif cmdID == CMD.SELFD then
        --StopMorph(unitID, morphData)
      elseif cmdID == CMD_MORPH_PAUSE then
        PauseMorph(unitID, morphData)
        --return false
      elseif cmdID == CMD_MORPH_QUEUE then
        return hasTech(unitID, unitDefID, teamID, cmdID)
                and not ipairs_containsElement(teamQueuedUnits[teamID], "unitID", unitID)
        --else --// disallow ANY command to units in morph
        --  return false
      end
    elseif cmdID >= CMD_MORPH and cmdID < CMD_MORPH + MAX_MORPH then
      -- Valid MORPH command, allow it to go through (actually processed in gadget:commandfallback)
      --Spring.Echo(" Has Tech: "..hasTech(unitID, unitDefID, teamID, cmdID))
      if hasTech(unitID, unitDefID, teamID, cmdID) and isFactory(unitDefID) then
        --// the factory cai is broken and doesn't call CommandFallback(),
        --// so we have to start the morph here
        local morphDef = getMorphDef(unitID, unitDefID, cmdID)
        StartMorph(unitID, morphDef, teamID)
        return false
      else
        return true
      end
      return false
    end

    return true
  end

  -- Fallback to process the Morph (start) command
  -- CommandFallback: called when the unit reaches a custom command in its queue
  function gadget:CommandFallback(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
    if cmdID == CMD_MORPH_QUEUE then
      -- def = morphDef, progress = 0.0, increment = morphDef.increment,
      --  --   morphID = morphID, teamID = teamID, paused = false
      -- Actual morph hasn't started yet, so we create a temporary morphData
      -- local morphData = { def = morphDef, progress = 0.0, increment = morphDef.increment,
      --                    morphID = nil, teamID = teamID, paused = false, }
      -- We must find the morph-start CmdID
      local startCmdID
      for id, _ in pairsByKeys(morphDefs[UnitDefs[unitDefID].name]) do
        startCmdID = id
        break -- We're only taking the first cmdID for now --TODO: support multiple morph buttons
      end
      -- If there are no morphingUnits, start morphing this immediately
      if #teamQueuedUnits[teamID] == 0 then
        local morphDef = getMorphDef(unitID, unitDefID, startCmdID)
        --if not morphDef then
        --  return true, true end      --// command was used, remove it
        QueueMorph(unitID, teamID, startCmdID)
        StartMorph(unitID, morphDef, teamID)
      else
        QueueMorph(unitID, teamID, startCmdID)
      end
      return true, true
    end
    -- Start Morph processing goes below
    if cmdID < CMD_MORPH or cmdID >= CMD_MORPH+MAX_MORPH then
      return false        --// command unknown, not used here
    end
    local morphDef = getMorphDef(unitID, unitDefID, cmdID)
    if not morphDef then
      return true, true   --// command was used, remove it
    end
    local morphData = morphingUnits[unitID]
    if not morphData then
      StartMorph(unitID, morphDef, teamID)
      return true, true
    end
    return true, false    --// command was used, do not remove it
  end

  --------------------------------------------------------------------------------
  --endregion  END SYNCED
  --------------------------------------------------------------------------------
else
  --------------------------------------------------------------------------------
  --region  UNSYNCED
  --------------------------------------------------------------------------------

  --// 75b2 compability (removed it in the next release)
  --if (Spring.GetTeamColor==nil) then
  --  Spring.GetTeamColor = function(teamID) local _,_,_,_,_,_,r,g,b = Spring.GetTeamInfo(teamID); return r,g,b end
  --end

  --
  -- speed-ups
  --

  local gameFrame;
  local SYNCED = SYNCED
  local CallAsTeam = CallAsTeam

  local GetUnitTeam         = Spring.GetUnitTeam
  local GetUnitHeading      = Spring.GetUnitHeading
  local GetUnitBasePosition = Spring.GetUnitBasePosition
  local GetGameFrame        = Spring.GetGameFrame
  local GetSpectatingState  = Spring.GetSpectatingState
  local AddWorldIcon        = Spring.AddWorldIcon
  local AddWorldText        = Spring.AddWorldText
  local IsUnitVisible       = Spring.IsUnitVisible
  local GetLocalTeamID      = Spring.GetLocalTeamID
  local spAreTeamsAllied    = Spring.AreTeamsAllied
  local spGetGameFrame      = Spring.GetGameFrame

  local glBeginText    = gl.BeginText
  local glEndText      = gl.EndText
  local glBillboard    = gl.Billboard
  local glColor        = gl.Color
  local glPushMatrix   = gl.PushMatrix
  local glTranslate    = gl.Translate
  local glRotate       = gl.Rotate
  local glScale        = gl.Scale
  local glUnitShape    = gl.UnitShape
  local glPopMatrix    = gl.PopMatrix
  local glText         = gl.Text
  local glPushAttrib   = gl.PushAttrib
  local glPopAttrib    = gl.PopAttrib
  local glBlending     = gl.Blending
  local glDepthTest    = gl.DepthTest

  local GL_LEQUAL      = GL.LEQUAL
  local GL_ONE         = GL.ONE
  local GL_SRC_ALPHA   = GL.SRC_ALPHA
  local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
  local GL_COLOR_BUFFER_BIT = GL.COLOR_BUFFER_BIT

  local UItextColor = {1.0, 1.0, 0.6, 1.0}
  local UItextSize = 12.0

  local headingToDegree = (360 / 65535)

  --- Keys that activate the queue display
  local activationKeyTable = {
    --[KEYSYMS.C] = true,
    [KEYSYMS.Q] = true,
    --[KEYSYMS.B] = true,
    [KEYSYMS.SPACE] = true,
  }

  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------

  local useLuaUI = false
  local oldFrame = 0        --// used to save bandwidth between unsynced->LuaUI
  local drawProgress = true --// a widget can do this job too (see healthbars)

  local morphUnits
  local teamQUnits

  local unitGroup = {}    --// { [unitID]=n,.. }

  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------

  --//synced -> unsynced actions

  local function SelectSwap(cmd, oldID, newID)  --  SendToUnsynced("unit_morph_finished", unitID, newUnit)
    --animation-only morphs won't need this
    if not (oldID == newID) then
      local group = unitGroup[oldID]
      if group then
        Spring.SetUnitGroup(newID, group)
        unitGroup[oldID] = nil
      end

      local selUnits = Spring.GetSelectedUnits()
      for i=1,#selUnits do
        local unitID = selUnits[i]
        if (unitID == oldID) then
          selUnits[i] = newID
          Spring.SelectUnitArray(selUnits)
          break
        end
      end
    end

    if Script.LuaUI('MorphFinished') then
      --Spring.Echo(" Sending to Unsynced")
      --Script.LuaUI.MorphFinished(oldID, newID)
      if (useLuaUI) then
        local readTeam, spec, specFullView = nil,GetSpectatingState()
        if (specFullView)
        then readTeam = Script.ALL_ACCESS_TEAM
        else readTeam = GetLocalTeamID() end
        CallAsTeam ({ ['read'] = readTeam }, function()
          if (IsUnitVisible(oldID)) then
            Script.LuaUI.MorphFinished(oldID,newID)
          end
        end)
      end
    end

    return true
  end

  local function StartMorph (cmd, unitID, unitDefID, morphID)
    --local defReload = spGetUnitRulesParam(unitID, "defreload")
    local group = Spring.GetUnitGroup(unitID)
    unitGroup[unitID]=group
    --Spring.Echo("group stored: "..group)
    if (Script.LuaUI('MorphStart')) then
      if (useLuaUI) then
        local readTeam, spec, specFullView = nil,GetSpectatingState()
        if (specFullView)
        then readTeam = Script.ALL_ACCESS_TEAM
        else readTeam = GetLocalTeamID() end
        CallAsTeam({ ['read'] = readTeam }, function()
          if (unitID)and(IsUnitVisible(unitID)) then
            local unitDefName = UnitDefs[unitDefID].name
            Script.LuaUI.MorphStart(unitID, (SYNCED.morphDefs[unitDefName] or {})[morphID] or SYNCED.extraUnitMorphDefs[unitID])
          end
        end)
      end
    end
    return true
  end

  local function PauseMorph(cmd, unitID)
    if (Script.LuaUI('MorphPause')) then
      if (useLuaUI) then
        local readTeam, spec, specFullView = nil,GetSpectatingState()
        if (specFullView)
        then readTeam = Script.ALL_ACCESS_TEAM
        else readTeam = GetLocalTeamID() end
        CallAsTeam({ ['read'] = readTeam }, function()
          if (unitID)and(IsUnitVisible(unitID)) then
            Script.LuaUI.MorphPause(unitID)
          end
        end)
      end
    end
    return true
  end

  local function StopMorph(cmd, unitID)
    if (Script.LuaUI('MorphStop')) then
      if (useLuaUI) then
        local readTeam, spec, specFullView = nil,GetSpectatingState()
        if (specFullView)
        then readTeam = Script.ALL_ACCESS_TEAM
        else readTeam = GetLocalTeamID() end
        CallAsTeam({ ['read'] = readTeam }, function()
          if (unitID)and(IsUnitVisible(unitID)) then
            Script.LuaUI.MorphStop(unitID)
          end
        end)
      end
    end
    return true
  end

  --region Support Methods

  local teamColors = {}
  local function SetTeamColor(teamID,a)
    local color = teamColors[teamID]
    if (color) then
      color[4]=a
      glColor(color)
      return
    end
    local r, g, b = spGetTeamColor(teamID)
    if (r and g and b) then
      color = { r, g, b }
      teamColors[teamID] = color
      glColor(color)
      return
    end
  end

  --// patches an annoying popup the first time you morph a unittype(+team)
  local alreadyInit = {}
  local function InitializeUnitShape(unitDefID,unitTeam)
    local iTeam = alreadyInit[unitTeam]
    if (iTeam)and(iTeam[unitDefID]) then return end

    glPushMatrix()
    gl.ColorMask(false)
    glUnitShape(unitDefID, unitTeam)
    gl.ColorMask(true)
    glPopMatrix()
    if not alreadyInit[unitTeam]
    then alreadyInit[unitTeam] = {} end
    alreadyInit[unitTeam][unitDefID] = true
  end

  local function DrawMorphUnit(unitID, morphData, localTeamID)
    local h = GetUnitHeading(unitID)
    if h == nil then
      return end --// bonus, heading is only available when the unit is in LOS
    local px,py,pz = GetUnitBasePosition(unitID)
    if px == nil then
      return end
    local unitTeam = morphData.teamID
    local newShapeID = morphData.def.into --unitID --
    --Spring.Echo(" old/new "..unitID.." - "..morphData.def.into)

    InitializeUnitShape(newShapeID,unitTeam) --BUGFIX

    local frac = ((gameFrame + unitID) % 30) / 30
    local alpha = math.min(1.0 * math.abs(0.5 - frac), 0.8)
    local angle
    if morphData.def.facing then
      angle = -HeadingToFacing(h) * 90 + 180
    else
      angle = h * headingToDegree
    end

    SetTeamColor(unitTeam,alpha)
    glPushMatrix()
    glTranslate(px, py, pz)
    glRotate(angle, 0, 1, 0)
    glScale(0.9, 0.9, 0.9)  --new
    glUnitShape(newShapeID, unitTeam)
    glPopMatrix()

    --// cheesy progress indicator
    if (drawProgress)and(localTeamID)and
            ( (spAreTeamsAllied(unitTeam,localTeamID)) or (localTeamID==Script.ALL_ACCESS_TEAM) )
    then
      glPushMatrix()
      glPushAttrib(GL_COLOR_BUFFER_BIT)
      glTranslate(px, py+14, pz)
      glBillboard()
      local progStr = string.format("%.1f%%", 100 * morphData.progress)
      gl.Text(progStr, 0, -65, 24, "oc")
      glPopAttrib()
      glPopMatrix()
    end
  end

  --endregion

  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------
  --region Spring Events

  function gadget:Initialize()
    -- This allows synced messages to be received by the unsynced part (https://springrts.com/phpbb/viewtopic.php?t=11408)
    gadgetHandler:AddSyncAction("unit_morph_finished", SelectSwap)
    gadgetHandler:AddSyncAction("unit_morph_start", StartMorph)
    gadgetHandler:AddSyncAction("unit_morph_pause", PauseMorph)
    gadgetHandler:AddSyncAction("unit_morph_stop", StopMorph)
    --startFrame = spGetGameFrame()
  end

  function gadget:Shutdown()
    gadgetHandler:RemoveSyncAction("unit_morph_finished")
    gadgetHandler:RemoveSyncAction("unit_morph_start")
    gadgetHandler:RemoveSyncAction("unit_morph_pause")
    gadgetHandler:RemoveSyncAction("unit_morph_stop")
  end

  function gadget:Update()
    local frame = spGetGameFrame()
    if (frame<=oldFrame) then
      return end
    oldFrame = frame
    if not SYNCED.morphUnits or (not next(SYNCED.morphUnits)) then    -- If table empty, return
      return end
    -- Script.LuaUI: makes an unsynced gadget call a function that is in a listening widget.
    local hasMorphUpdate = Script.LuaUI('MorphUpdate')
    if hasMorphUpdate ~= useLuaUI then   --//Update Callins on change
      drawProgress = not Script.LuaUI('MorphDrawProgress')
      useLuaUI     = hasMorphUpdate
    end

    if useLuaUI then
      local morphTable = {}
      local readTeam, spec, specFullView = nil, GetSpectatingState()
      if (specFullView)
      then readTeam = Script.ALL_ACCESS_TEAM
      else readTeam = GetLocalTeamID() end
      CallAsTeam({ ['read'] = readTeam }, function()
        for unitID, morphData in pairs(SYNCED.morphUnits) do
          if (unitID and morphData)and(IsUnitVisible(unitID)) then
            morphTable[unitID] = { progress=morphData.progress, into=morphData.def.into }
          end
        end
      end)
      Script.LuaUI.MorphUpdate(morphTable)
    end
  end

  local cacheGameFrame, teamQueuedUnits, morphUnits
  local cachedReadTeamTable = { read = 123 }
  local function DrawMorphUnits(readTeam)
    for unitID, morphData in pairs(morphUnits) do
      if unitID and morphData and IsUnitVisible(unitID) then
        DrawMorphUnit(unitID, morphData, readTeam)
      end
    end
  end
  function gadget:DrawWorld()
    local localTeam = GetLocalTeamID()
    gameFrame = GetGameFrame()
    if gameFrame ~= cacheGameFrame then
      cacheGameFrame = gameFrame
      morphUnits = SYNCED.morphUnits
      teamQueuedUnits = SYNCED.teamQUnits[localTeam]
    end

    if not morphUnits or (not next(morphUnits)) then
      return --//no morphs to draw
    end

    glBlending(GL_SRC_ALPHA, GL_ONE)
    glDepthTest(GL_LEQUAL)


    local spec, specFullView = GetSpectatingState()
    local readTeam = specFullView
            and Script.ALL_ACCESS_TEAM or localTeam

    --- [BEGIN] Draw MorphQueue indexes
    --glBeginText()
    for i = 1, #teamQueuedUnits do
      local unit = teamQueuedUnits[i]["unitID"]
      if spIsUnitInView(unit) then
        local ux, uy, uz = spGetUnitViewPosition(unit)
        glPushMatrix()
        glTranslate(ux, uy, uz)
        glBillboard()
        glColor(UItextColor)
        glText("[" .. i.."]", 20.0, -25.0, UItextSize, "cno")
        glPopMatrix()
      end
    end
    --glEndText()
    --- [END] Draw MorphQueue indexes

    cachedReadTeamTable.read = readTeam
    CallAsTeam(cachedReadTeamTable, DrawMorphUnits, readTeam)
    for unitID, morphData in pairs(morphUnits) do
      if unitID and morphData and IsUnitVisible(unitID) then
        DrawMorphUnit(unitID, morphData, readTeam)
      end
    end
    glDepthTest(false)
    glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  end

  --function gadget:RecvLuaMsg(msg, playerID)
  --  Spring.Echo("Received message: "..msg.." from player "..playerID)
  --end

  --endregion
  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------

  --------------------------------------------------------------------------------
  --endregion  UNSYNCED (end)
  --------------------------------------------------------------------------------

end
--------------------------------------------------------------------------------
--  COMMON
--------------------------------------------------------------------------------
