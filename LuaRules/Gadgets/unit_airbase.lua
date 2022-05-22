-------------------------------------------------------------------------------------------------
--- Rearming a bomber or fighter happens between two gadgets.
---
--- unit_airbase: controls when a unit is landed/rearming
---     - Initially all rearm-able planes have their ammo set to their customParams.maxAmmo
---     - Rearming only happens after repairing (if needed), sends event to bomber_control
--- unit_bomber_control: controls each bomber ammo and its reload time
---     - After firing, reload is set to 99999+currentFrame ("infinite reload")
---     - Once landed (on rearming state), reload is set to ammoReload (from customParams)
---     - After reload (on rearming state) is finished, release it from unit_airbase
---     - PS: For the reload system to work, the unit script must fire a 'bombsaway' lua event
---
---     - !!!!Weapon Parameter "ReloadTime" becomes the "Time to Re-Arm"!!!!
-------------------------------------------------------------------------------------------------

function gadget:GetInfo()
    return {
        name      = "Airbase Manager",
        desc      = "Automated and manual use of air repair pads",
        author    = "ashdnazg, Bluestone, updated by MaDDoX (ammo reload)",
        date      = "February 2016",
        license   = "GNU GPL, v2 or later",
        layer     = 1,
        enabled   = true  --  loaded by default?
    }
end

-- Ammo Reference: https://github.com/spring1944/spring1944/blob/master/LuaRules/Gadgets/game_ammo.lua

VFS.Include("gamedata/taptools.lua")

---------------------------------------------------------------------------------
local CMD_LAND_AT_AIRBASE = 35430
local CMD_LAND_AT_SPECIFIC_AIRBASE = 35431

CMD.LAND_AT_AIRBASE = CMD_LAND_AT_AIRBASE
CMD[CMD_LAND_AT_AIRBASE] = "LAND_AT_AIRBASE"
CMD.LAND_AT_SPECIFIC_AIRBASE = CMD_LAND_AT_SPECIFIC_AIRBASE
CMD[CMD_LAND_AT_SPECIFIC_AIRBASE] = "LAND_AT_SPECIFIC_AIRBASE"

local spGetUnitDefID = Spring.GetUnitDefID
local AreTeamsAllied	 = Spring.AreTeamsAllied
local GetGameFrame       = Spring.GetGameFrame
local ValidUnitID		 = Spring.ValidUnitID
--local GetUnitAllyTeam    = Spring.GetUnitAllyTeam
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitRadius = Spring.GetUnitRadius
local spGetUnitPiecePosDir = Spring.GetUnitPiecePosDir
local spUnitAttach = Spring.UnitAttach
local spSetUnitLoadingTransport = Spring.SetUnitLoadingTransport
local GetUnitIsStunned   = Spring.GetUnitIsStunned
local GetUnitPosition    = Spring.GetUnitPosition
local GetUnitRulesParam  = Spring.GetUnitRulesParam
local GetUnitSeparation  = Spring.GetUnitSeparation
local GetUnitsInCylinder = Spring.GetUnitsInCylinder
local GetUnitTeam        = Spring.GetUnitTeam
local GetUnitWeaponState = Spring.GetUnitWeaponState
local SetUnitExperience  = Spring.SetUnitExperience
local SetUnitRulesParam  = Spring.SetUnitRulesParam
local SetUnitWeaponState = Spring.SetUnitWeaponState
local UseUnitResource	 = Spring.UseUnitResource
local GetTeamRulesParam	= Spring.GetTeamRulesParam
local SetTeamRulesParam	= Spring.SetTeamRulesParam
local spSetUnitLoadingTransport = Spring.SetUnitLoadingTransport
local spSetUnitLandGoal = Spring.SetUnitLandGoal
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitRulesParam = Spring.GetUnitRulesParam

local airbaseDefIDs = {
    [UnitDefNames["healstation"].id] = 5000, --350,     -- distance in elmos for snap onto pad
	[UnitDefNames["healstation"].id] = 5000,
}

local snapDist = 60 -- default snap distance, if not found in table

-- restorestate "Enum" : 0=Done; 1=OutOfAmmo; 2=Rearming; 3=Repairing
--local Restore = { Done=0, OutOfAmmo=1, Rearming=2, Repairing=3 }

local cmd_fly = 145  -- Fly/Land command button ID

local function isAirBase(unitDefID)
    return airbaseDefIDs[unitDefID] ~= nil
end


--------------------------------------------------------------------------------
-- Synced

if (gadgetHandler:IsSyncedCode()) then
    --------------------------------------------------------------------------------

    local airbases = {} -- airbaseID = { int pieceNum = unitID reservedFor }

    local pendingLanders = {}  -- unitIDs of planes that want rearm or repair and are waiting to be assigned airbases
    local cancelledLanders = {} -- planes which need repair/rearm but got their landing cancelled manually
    local landingPlanes = {}   -- planes that are in the process of landing on (including flying towards) airbases; [1]=airbaseID, [2]=pieceNum
    local landedPlanes = {}    -- unitIDs of planes that are currently landed in airbases
    --local requestingRearm = {} -- use: requestingRearm[unitID] = true  TODO: replace with 'OrphanPlanes', no airpad assigned

    local vehicles = {}  -- Planes with Ammo
    local newVehicles = {}
    --local reloadFrames = {}
    local startFrame

    local previousHealFrame = 0
    -- FYI: We know which are the rearm-able planes by checking if its uDef.customParams.maxammo > 0

    ---------------------------
    --region ################ Custom Commands

    --------------------------------------------------------------------------------
    -- config
    --------------------------------------------------------------------------------
    local combatCommands = {	-- commands that require ammo to execute
        [CMD.ATTACK] = true,
        [CMD.AREA_ATTACK] = true,
        [CMD.FIGHT] = true,
        [CMD.PATROL] = true,
        [CMD.GUARD] = true,
        [CMD.MANUALFIRE] = true,
    }

    local landAtAnyAirbaseCmd = {
        id      = CMD_LAND_AT_AIRBASE,
        name    = "Any Airbase",
        action  = "landatairbase",
        cursor  = 'landatairbase',
        type    = CMDTYPE.ICON,
        tooltip = "Airbase: Makes the unit land at the nearest available airbase for repairs/rearm",
    }

    local landAtSpecificAirbaseCmd = {
        id      = CMD_LAND_AT_SPECIFIC_AIRBASE,
        name    = "Airbase",
        action  = "landatspecificairbase",
        cursor  = 'landatspecificairbase',
        type    = CMDTYPE.ICON_UNIT,
        tooltip = "Airbase: Makes the unit land at a specific airbase for repairs/rearm",
    }

    --endregion

    --region ################ Helper Functions
    ---------------------------------------
    -- helper funcs (pads)

    --- Returns ammo, maxAmmo
    local function getAmmo(unitID)
        local ud = UnitDefs[spGetUnitDefID(unitID)]
        local maxammo = 1
        --if ud.customParams and ud.customParams.maxAmmo then
        --    maxammo = ud.customParams.maxAmmo
        --end
        if ud.customParams ~= nil and ud.customParams.maxAmmo ~= nil then
            maxammo = ud.customParams.maxAmmo
        end
        return spGetUnitRulesParam(unitID, "ammo"), maxammo
        --local ammo = spGetUnitRulesParam(unitID, "ammo")
        --if ammo then
        --    ammo = tonumber(ammo) end
        --return ammo or 0, maxammo
    end

    -- @return It's either false ie. cannot land at this airbase, or the piece number of a free pad within this airbase
    function CanLandAt(unitID, airbaseID)

        -- check that this airbase has pads (needed?)
        local airbasePads = airbases[airbaseID]
        if not airbasePads then
            return false
        end

        -- check that this airbase is on our team
        local unitTeamID = Spring.GetUnitTeam(unitID)
        local airbaseTeamID = Spring.GetUnitTeam(airbaseID)
        if not unitTeamID or not airbaseTeamID or not Spring.AreTeamsAllied(unitTeamID, airbaseTeamID) then
            return false
        end

        -- try to find a vacant pad within this airbase
        local padPieceNum = false
        for pieceNum, reserved in pairs(airbasePads) do
            if not reserved then
                padPieceNum = pieceNum
                break
            end
        end
        return padPieceNum
    end

    ---------------------------------------
    -- Helper Funcs (main)
    ---------------------------------------

    --- Free up the pad that this landingPlane had reserved
    function RemoveLandingPlane(unitID)
        if landingPlanes[unitID] then
            local airbaseID, pieceNum = landingPlanes[unitID][1], landingPlanes[unitID][2]
            local airbasePads = airbases[airbaseID]
            if airbasePads then
                airbasePads[pieceNum] = false
            end
            landingPlanes[unitID] = nil
            cancelledLanders[unitID] = true
        end
    end

    ---------------------------------------
    -- Helper Funcs (other)
    ---------------------------------------

    -- check if this unitID (which is assumed to be a plane) would want to land
    function NeedsRepair(unitID)
        local health, maxHealth, _, _, buildProgress = Spring.GetUnitHealth(unitID)
        if buildProgress<1 then return false end
        local landAtState = Spring.GetUnitStates(unitID).autorepairlevel
        return health < maxHealth * landAtState
    end

    -----@param unitID number   ---@return boolean
    function NeedsRearm(unitID)
        local ammo = getAmmo(unitID)
        if ammo and isnumber(ammo) then
            return ammo < 1
        end
        return false
    end

    function IsPlane(unitDefID)
        return UnitDefs[unitDefID].isAirUnit
    end

    ---@param unitDefID number   ---@return boolean
    local function isRearmable(unitDefID)
        --local unitDefID	= spGetUnitDefID(unitID)
        local ud = UnitDefs[unitDefID]
        if ud.customParams and ud.customParams.maxammo then
            return isnumber(ud.customParams.maxammo) and ud.customParams.maxammo > 0
        end
        return false
    end

    --local function NeedsRearm(unitID)            -- Is it out of ammo?
    --   if not isRearmable(UnitDefs(spGetUnitDefID(unitID))) then
    --      return false
    --   end
    --   local ammo = Spring.GetUnitRulesParam(unitID, "ammo")
    --   if isnumber(ammo) then
    --      return math.ceil(ammo) == 0 end  -- Handle negative values just in case
    --   return false
    --end

    function GetDistanceToPoint(unitID, px,py,pz)
        if not Spring.ValidUnitID(unitID) then return end
        if not px then return end

        local ux, uy, uz = Spring.GetUnitPosition(unitID)
        local dx, dy ,dz = ux - px, uy - py, uz - pz
        local dist = dx * dx + dy * dy + dz * dz
        return dist
    end

    function FlyAway(unitID, airbaseID)
        -- hack, after detaching units don't always continue with their command q
        Spring.GiveOrderToUnit(unitID, CMD.WAIT, {}, {})
        Spring.GiveOrderToUnit(unitID, CMD.WAIT, {}, {})
        --

        -- if the unit has no orders, tell it to move a little away from the airbase
        local q = Spring.GetUnitCommands(unitID, 0)
        if q==0 then
            local px,_,pz = Spring.GetUnitPosition(airbaseID)
            local theta = math.random()*2*math.pi
            local r = 2.5 * Spring.GetUnitRadius(airbaseID)
            local tx,tz = px+r*math.sin(theta), pz+r*math.cos(theta)
            local ty = Spring.GetGroundHeight(tx,tz)
            local uDID = Spring.GetUnitDefID(unitID)
            local cruiseAlt = UnitDefs[uDID].wantedHeight
            Spring.GiveOrderToUnit(unitID, CMD.MOVE, {tx,ty,tz}, {})
        end
    end

    function HealUnit(unitID, airbaseID, resourceFrames, h, mh)
        if resourceFrames <= 0 then return end
        local airbaseDefID = Spring.GetUnitDefID(airbaseID)
        local unitDefID = Spring.GetUnitDefID(unitID)
        local buildSpeed = UnitDefs[airbaseDefID].buildSpeed
        local timeToBuild = UnitDefs[unitDefID].buildTime / buildSpeed
        local healthGain = timeToBuild / resourceFrames
        local newHealth = math.min(h+healthGain, mh)
        Spring.SetUnitHealth(unitID, newHealth)
    end

    function RemoveOrderFromQueue(unitID, cmdID)
        -- hack
        -- we need this because CommandFallback is only called every slow update
        -- and we need to remove commands from the front of the queue when events *actually* happen
        --    i.e. in gameframes in between slow update
        -- doing anything else fails on edge cases e.g. unitID is recycle from a landingPlane that dies
        --    into a second place that becomes a landedPlane *all* in between slow updates
        Spring.GiveOrderToUnit(unitID, CMD.REMOVE, {cmdID}, {"alt"})
    end

    --endregion

    --region ################ Spring Events and CallIns
    function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
        if IsPlane(unitDefID) then             -- Insert LandAtAirbase Commands
            Spring.InsertUnitCmdDesc(unitID, landAtSpecificAirbaseCmd)
            Spring.InsertUnitCmdDesc(unitID, landAtAnyAirbaseCmd)
        end

        -- (MaDDoX) Not sure if below is needed..
        local _, _, _, _, buildProgress = Spring.GetUnitHealth(unitID)
        if buildProgress == 1.0 then
            gadget:UnitFinished(unitID, unitDefID, unitTeam)
        end
    end

    function gadget:UnitFinished(unitID, unitDefID, unitTeam)
        local function AddAirBase(unitID)
            -- add the pads of this airbase to our register
            local airbasePads = {}
            local pieceMap = Spring.GetUnitPieceMap(unitID)
            for pieceName, pieceNum in pairs(pieceMap) do
                if pieceName:find("land") then
                    airbasePads[pieceNum] = false -- value is whether or not the pad is reserved
                end
            end
            airbases[unitID] = airbasePads
        end
        if not airbaseDefIDs[unitDefID] then
            return end
        AddAirBase(unitID)
    end

    function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
        if not IsPlane(unitDefID) and not airbases[unitID] then return end

        RemoveLandingPlane(unitID)
        airbases[unitID] = nil
        landedPlanes[unitID] = nil
        pendingLanders[unitID] = nil
        cancelledLanders[unitID] = nil
    end

    ---------------------------------------
    -- custom command handling

    function gadget:CommandFallback(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
        -- handle our two custom commands

        if cmdID == CMD_LAND_AT_SPECIFIC_AIRBASE then
            if landedPlanes[unitID] then              -- this order is now completed
                return true, true end

            if landingPlanes[unitID] then             -- this order is not yet completed, call CommandFallback again
                return true, false end

            -- this order has just reached the top of the command queue and we are not a landingPlane;
            -- process the order and make us into a landing plane!

            -- find out if the desired airbase has a free pad
            local airbaseID = cmdParams[1]
            local pieceNum = CanLandAt(unitID, airbaseID)
            if not pieceNum then
                return true, false  -- not possible to land here
            end

            -- reserve pad
            airbases[airbaseID][pieceNum] = unitID
            landingPlanes[unitID] = {airbaseID, pieceNum}
            pendingLanders[unitID] = nil
            --SendToUnsynced("SetUnitLandGoal", unitID, airbaseID, pieceNum)
            return true, false
        end

        if cmdID == CMD_LAND_AT_AIRBASE then
            if landingPlanes[unitID] then
                return true, true end                 -- finished processing

            pendingLanders[unitID] = true
            return true, false
        end

        return false
    end

    ---------------------------------------
    -- main
    local CMD_SET_WANTED_MAX_SPEED = CMD.SET_WANTED_MAX_SPEED
    local CMD_INSERT = CMD.INSERT
    local CMD_REMOVE = CMD.REMOVE

    -- TODO: Set restoreState appropriately
    function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions)
        -- If out of ammo, ignore the combat command
        local ammo, maxAmmo = getAmmo(unitID)
        --if combatCommands[cmdID] and isnumber(ammo) and ammo < 1 then --or cmdID == CMD.STOP
        if combatCommands[cmdID] and (ammo ~= nil) then
            local n_ammo = tonumber(ammo)
            if n_ammo and (n_ammo < 1) then
                return false end
        end
        -- If command == return to airbase (any) and the unit is at full health & armed, ignore
        -- This way, if you select a bunch of planes and tell them to return, only the right ones will
        if cmdID == CMD_LAND_AT_AIRBASE then --and not cmdOptions.shift then
            local health, maxHealth = Spring.GetUnitHealth(unitID)
            health = tonumber(health)
            maxHealth = tonumber(maxHealth)
            ammo = tonumber(ammo)
            maxAmmo = tonumber(maxAmmo)
            if not health or not maxHealth then
                return true end
            -- Scouts, transports:
            if not ammo or not maxAmmo then
                return health < maxHealth end
            -- Combat planes:
            return ammo < maxAmmo or health < maxHealth
            ----if cmdIgnoreSelf then  --don't re-read rewritten bomber's command
            ----   return true
            ----end
            --local restoreState = spGetUnitRulesParam(unitID, "restorestate")     -- "noammo" in ZeroK's source
            --
            ---- don't rearm unless damaged or need ammo
            --if not restoreState or restoreState == Restore.Done then
            --   local health, maxHealth = Spring.GetUnitHealth(unitID)
            --   if (cmdID == CMD_REARM or cmdID == CMD_FIND_PAD) and not cmdOptions.shift and health > maxHealth - 1 then
            --      return false
            --   end
            ---- don't find new pad if already on the pad currently refueling or repairing.
            --elseif restoreState == Restore.Rearming or restoreState == Restore.Repairing then
            --   if (cmdID == CMD_REARM or cmdID == CMD_FIND_PAD) and not cmdOptions.shift then
            --      return false
            --   end
            --   if restoreState == Restore.Rearming then              -- don't leave in the middle of rearming, allow command and skip CancelAirpadReservation
            --      return true
            --   end
            --elseif restoreState == Restore.OutOfAmmo then            -- don't fight without ammo, go get ammo first!
            --if not restoreState or restoreState == Restore.Done then
            -- TODO: Check if there are no available landing pads and deal damage along time if that's the case
        end
        return true
        ----if bomberToPad[unitID] or bomberLanding[unitID] then
        ----   if not cmdOptions.shift then
        ----      CancelAirpadReservation(unitID) --don't leave airpad reservation hanging, empty them when bomber is given other task
        ----   end
        ----end
        --
    end

    -- Idle (empty-queue) out-of-ammo units must take a rearm order automatically
    function gadget:UnitIdle(unitID, unitDefID, team)
        if isRearmable(unitDefID) and getAmmo(unitID) == 0 then
            pendingLanders[unitID] = true
        end
    end

    -- Now we actually do what a fully rearmed/repaired plane wants to do, and release the pad for others
    local function PlaneReady(unitID)
        local idx = Spring.FindUnitCmdDesc ( unitID, cmd_fly )

        local unitCmdDescs = Spring.GetUnitCmdDescs (unitID, idx, idx)
        --Spring.Echo("UnitCmdDesc Name: "..unitCmdDescs[1].params[1])
        --{ [1] = { "id"          = number, "type"        = number, "name"        = string, "action"      = string, "tooltip"     = string, "texture"     = string,
        --          "cursor"      = string, "hidden"      = boolean, "disabled"    = boolean, "showUnique"  = boolean, "onlyTexture" = boolean,
        --"params"      = { [1] = string, ... } }, ... }

        -- if this unitID was in a pad, detach the unit and free that pad
        local airbaseID = Spring.GetUnitTransporter(unitID)
        if not airbaseID then
            return
        end
        local airbasePads = airbases[airbaseID]
        if not airbasePads then
            return
        end
        for pieceNum, reservedBy in pairs(airbasePads) do
            if reservedBy == unitID then
                airbasePads[pieceNum] = false
                --Spring.Echo("Released pad: "..pieceNum)
            end
        end

        -- If fly/land button == 'fly' detach, otherwise don't (keep it docked)
        if unitCmdDescs[1].params[1] == "0" then    -- LAND: 1, FLY: 0
            Spring.UnitDetach(unitID)
        else
            --Spring.SetUnitLoadingTransport(unitID, airbaseID)=true
            Spring.UnitDetach(unitID)
            local x,y,z = Spring.GetUnitPosition(airbaseID)
            --Spring.GiveOrderToUnit(unitID, CMD.PATROL, Spring.GetUnitPosition(airbaseID),{"shift"})
            Spring.GiveOrderToUnit(unitID, CMD_INSERT, {-1, CMD.PATROL, CMD.OPT_INTERNAL, x,y,z }, {"alt"} )
        end

    end

    -- Called by unit_bomber_control once rearm is done
    local function RearmDone(unitID)
        landedPlanes[unitID] = nil
        PlaneReady(unitID)
    end

    --- if a plane is given a command, assume the user wants that command to be actioned and release control
    -- (unless it's one of our custom commands, etc)
    function gadget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)

        if not IsPlane(unitDefID) then
            return end
        if cmdID == CMD_LAND_AT_AIRBASE or cmdID == CMD_REMOVE then
            return end
        if cmdID == CMD_LAND_AT_SPECIFIC_AIRBASE then
            return end --fixme: case of wanting to force land at a different pad than current reserved
        if cmdID == CMD_SET_WANTED_MAX_SPEED then
            return end -- i hate SET_WANTED_MAX_SPEED
        if cmdID == CMD_INSERT and (cmdParams[2] == CMD_LAND_AT_AIRBASE or cmdParams[2] == CMD_LAND_AT_SPECIFIC_AIRBASE ) then
            return end

        -- release control of this plane
        if landingPlanes[unitID] then
            RemoveLandingPlane(unitID)
        elseif landedPlanes[unitID] then
            RearmDone(unitID)
        end

        -- and remove it from our book-keeping
        -- (in many situations, unless the user changes the RepairAt level, it will be quickly reinserted, but we have to assume that's what they want!)
        landingPlanes[unitID] = nil
        landedPlanes[unitID] = nil
        pendingLanders[unitID] = nil
    end

    --- When a plane is damaged, check to see if it needs repair, move to pendingLanders if so
    function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID)
        if IsPlane(unitDefID) and not landingPlanes[unitID] and not landedPlanes[unitID] and NeedsRepair(unitID) then
            pendingLanders[unitID] = true
        end
        --Spring.Echo("damaged", unitID)
    end

    ---- TODO: Check if it shouldn't be storedReloadFrame <= weaponReloadFrame..
    --local function CheckReload(unitID, weaponReloadFrame, weaponNum)
    --   if weaponReloadFrame == 0 or not vehicles[unitID] or not vehicles[unitID].reloadFrame then
    --      return false
    --   end
    --   local storedReloadFrame = vehicles[unitID].reloadFrame[weaponNum]
    --   Spring.Echo("Reload: (stored,weapon) "..storedReloadFrame,weaponReloadFrame)
    --   if storedReloadFrame == weaponReloadFrame then
    --      return false end
    --   vehicles[unitID].reloadFrame[weaponNum] = weaponReloadFrame
    --   return true
    --end

    -- Checks for and updates all re-armable weapons
    --local function ProcessWeapons(unitID)
    --   local unitDefID = GetUnitDefID(unitID)
    --   local weaponsWithAmmo = tonumber(UnitDefs[unitDefID].customParams.weaponswithammo) or 2
    --   local unitAmmo = GetUnitRulesParam(unitID, "ammo")
    --   local weaponFired = false
    --   local weapNum = 1
    --   local weaponReloadFrame = 0
    --
    --   while not weaponFired and weapNum <= weaponsWithAmmo do
    --      weaponReloadFrame = GetUnitWeaponState(unitID, weapNum, "reloadState")
    --      weaponFired = weaponFired or CheckReload(unitID, weaponReloadFrame, weapNum)
    --      weapNum = weapNum + 1
    --   end
    --   if weaponFired then
    --      --[[local howitzer = WeaponDefs[UnitDefs[unitDefID].weapons[1].weaponDef].customParams.howitzer
    --      if howitzer then
    --          SetUnitExperience(unitID, 0)
    --      end]]
    --      if unitAmmo == 1 then
    --         reloadFrames[unitID] = weaponReloadFrame
    --         for weapNum = 1, weaponsWithAmmo do
    --            SetUnitWeaponState(unitID, weapNum, {reloadTime = 99999, reloadState = weaponReloadFrame + 99999})
    --         end
    --      end
    --      if unitAmmo > 0 then
    --         vehicles[unitID].ammoLevel = unitAmmo - 1
    --         SetUnitRulesParam(unitID, "ammo", unitAmmo - 1)
    --      end
    --   end
    --end

    -- Main Update loop --
    function gadget:GameFrame(n)

        -- assign airbases & pads to planes in pendingLanders, if possible
        -- once done, move plane to landingPlanes
        -- TODO: pendingLanders (not cancelled) without available pad should be set to landing
        local function AssignPadToLanders()
            local function FindAirBase(unitID)
                -- find the nearest airbase with a free pad
                local minDist = math.huge
                local closestAirbaseID
                local closestPieceNum
                for airbaseID, _ in pairs(airbases) do
                    local pieceNum = CanLandAt(unitID, airbaseID)
                    if pieceNum then
                        local dist = Spring.GetUnitSeparation(unitID, airbaseID)
                        if dist < minDist then
                            minDist = dist
                            closestAirbaseID = airbaseID
                            closestPieceNum = pieceNum
                        end
                    end
                end
                return closestAirbaseID, closestPieceNum
            end
            for unitID, _ in pairs(pendingLanders) do
                local airbaseID, pieceNum = FindAirBase(unitID)
                if airbaseID then
                    -- reserve pad, give landing order to unit
                    airbases[airbaseID][pieceNum] = unitID
                    landingPlanes[unitID] = {airbaseID, pieceNum}
                    pendingLanders[unitID] = nil
                    spSetUnitLoadingTransport(unitID, airbaseID)
                    --spGiveOrderToUnit(unitID, CMD.INSERT, {0, CMD_LAND_AT_SPECIFIC_AIRBASE, 0, airbaseID}, {"alt"})
                    RemoveOrderFromQueue(unitID, CMD_LAND_AT_AIRBASE) -- hack!
                    spGiveOrderToUnit(unitID, CMD.INSERT, {0, CMD_LAND_AT_SPECIFIC_AIRBASE, -1, airbaseID}, {"alt"})
                end
            end
        end

        -- //every 72 frames// planes/pads may die at any time, and UnitDestroyed will take care of the book-keeping
        -- very occasionally, check all units to see if any planes (outside of our records) that need repair
        -- add them to pending landers, if so
        local function CheckAll()
            -- check all units to see if any need healing
            local allUnits = Spring.GetAllUnits()
            for _,unitID in ipairs(allUnits) do
                local unitDefID = Spring.GetUnitDefID(unitID)
                if IsPlane(unitDefID) and not landingPlanes[unitID]
                        and not landedPlanes[unitID] and not cancelledLanders[unitID] then
                    if NeedsRepair(unitID) or NeedsRearm(unitID) then
                        pendingLanders[unitID] = true
                    end
                end
            end
        end

        local function isAirFrozen(unitID)
            return spGetUnitRulesParam(unitID, "airfrozen") == 1
        end

        -- fly towards pad; once 'close enough' snap into pads, then move into landedPlanes
        local function updateLandingPlanes()
            for unitID, t in pairs(landingPlanes) do
                local airbaseID, padPieceNum = t[1], t[2]
                local px, py, pz = spGetUnitPiecePosDir(airbaseID, padPieceNum)
                local dist = GetDistanceToPoint(unitID, px,py,pz)
                if dist then
                    -- check if we're close enough, attach if so
                    local r = spGetUnitRadius(unitID)
                    local airbaseDefID = spGetUnitDefID(airbaseID)
                    --if airbaseDefID and dist >= airbaseDefIDs[airbaseDefID] then
                    --   Spring.Echo(" dist & mindist: ",dist, airbaseDefIDs[airbaseDefID]) end
                    if airbaseDefID and dist < airbaseDefIDs[airbaseDefID] then
                        -- land onto pad
                        landingPlanes[unitID] = nil
                        pendingLanders[unitID] = nil  -- Safe check (MaDDoX)
                        cancelledLanders[unitID] = nil
                        landedPlanes[unitID] = airbaseID
                        --Spring.Echo(" landed: ",unitID)
                        spUnitAttach(airbaseID, unitID, padPieceNum)          -- Attach to pad
                        spSetUnitLoadingTransport(unitID, nil)
                        RemoveOrderFromQueue(unitID, CMD_LAND_AT_SPECIFIC_AIRBASE)
                    else
                        -- fly towards pad (the pad may move!)
                        local uDefID = spGetUnitDefID(unitID)
                        if UnitDefs[uDefID].canFly and not isAirFrozen(unitID) then
                            spSetUnitLandGoal(unitID, px, py, pz, r)
                        end
                    end
                end
            end
        end

        -- Heal landedPlanes; Rearm after fully healed; Release if fully healed+rearmed
        local function HealAndRearmPlanes()
            local function ammoIsFull(unitID)
                local ud = UnitDefs[spGetUnitDefID(unitID)]
                local ammo = Spring.GetUnitRulesParam(unitID,"ammo")
                --Spring.Echo(" Current ammo: "..Spring.GetUnitRulesParam(unitID,"ammo"))
                if ammo and ud.customParams and ud.customParams.maxAmmo then
                    return ammo < ud.customParams.maxAmmo
                end
            end

            for unitID, airbaseID in pairs(landedPlanes) do
                if not GG.PlanesToRearm[unitID] then      -- If not re-arming already
                    local h,mh = Spring.GetUnitHealth(unitID)
                    if h and h==mh then        -- fully healed, try Rearming
                        if ammoIsFull(unitID) then
                            RearmDone(unitID)
                        else
                            if (Script.LuaRules('RearmBomber')) then
                                Script.LuaRules.RearmBomber(unitID, n)
                            end
                        end
                    elseif h then     -- still needs healing
                        local resourceFrames = (n-previousHealFrame)/30
                        HealUnit(unitID, airbaseID, resourceFrames, h, mh)
                    end
                end
            end
            previousHealFrame = n
        end

        if n % 72==0 then
            CheckAll()
        end

        if n % 16==0 then
            AssignPadToLanders()
        end

        if n%2==0 then
            updateLandingPlanes()
        end

        if n%8==0 then
            HealAndRearmPlanes()
        end
    end

    local function RequestRearm(unitID)
        pendingLanders[unitID] = true
    end

    function gadget:Initialize()
        startFrame = GetGameFrame()

        gadgetHandler:RegisterGlobal("RearmDone", RearmDone)
        gadgetHandler:RegisterGlobal("RequestRearm", RequestRearm)

        for unitDefID, unitDef in pairs(UnitDefs) do
            if isAirBase(unitDef.id) then
                airbaseDefIDs[unitDefID] = airbaseDefIDs[unitDefID] or snapDist
            end
        end

        -- dummy UnitCreated events for existing units, to handle luarules reload
        -- release any planes currently attached to anything else
        local allUnits = Spring.GetAllUnits()
        for i=1,#allUnits do
            local unitID = allUnits[i]
            local unitDefID = spGetUnitDefID(unitID)
            --local teamID = Spring.GetUnitTeam(unitID)
            gadget:UnitCreated(unitID, unitDefID)

            local transporterID = Spring.GetUnitTransporter(unitID)
            if transporterID and IsPlane(unitDefID) then
                Spring.UnitDetach(unitID)
            end
        end

    end

    --endregion

else
    --------------------------------------------------------------------------------
    --- Unsynced
    --------------------------------------------------------------------------------

    --region ################# Unsynced Spring Events
    local landAtAirBaseCmdColor = {0.50, 1.00, 1.00, 0.8} -- same colour as repair

    function gadget:Initialize()
        Spring.SetCustomCommandDrawData(CMD_LAND_AT_SPECIFIC_AIRBASE, "landatairbase", landAtAirBaseCmdColor, false)
        Spring.SetCustomCommandDrawData(CMD_LAND_AT_AIRBASE, "landatspecificairbase", landAtAirBaseCmdColorr, false)
        Spring.AssignMouseCursor("landatspecificairbase", "cursorrepair", false, false)
    end

    local spGetMouseState = Spring.GetMouseState
    local spTraceScreenRay = Spring.TraceScreenRay
    local spAreTeamsAllied = Spring.AreTeamsAllied
    local spGetUnitTeam = Spring.GetUnitTeam
    local spGetUnitDefID = Spring.GetUnitDefID
    local spGetUnitPiecePosDir = Spring.GetUnitPiecePosDir
    local spGetUnitPosition = Spring.GetUnitPosition
    local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
    local spIsUnitSelected = Spring.IsUnitSelected
    local spGetSelectedUnits = Spring.GetSelectedUnits

    local myTeamID = Spring.GetMyTeamID()
    local myAllyTeamID = Spring.GetMyAllyTeamID()
    local amISpec = Spring.GetSpectatingState()

    local strUnit = "unit"

    function gadget:PlayerChanged()
        myTeamID = Spring.GetMyTeamID()
        myAllyTeamID = Spring.GetMyAllyTeamID()
        amISpec = Spring.GetSpectatingState()
    end

    function gadget:DefaultCommand()
        local mx, my = spGetMouseState()
        local s, targetID = spTraceScreenRay(mx, my)
        if s ~= strUnit then
            return false
        end

        if not spAreTeamsAllied(myTeamID, spGetUnitTeam(targetID)) then
            return false
        end

        local targetDefID = spGetUnitDefID(targetID)
        if not (isAirBase(targetDefID) or airbaseDefIDs[targetDefID]) then
            return false
        end

        local sUnits = spGetSelectedUnits()
        for i=1,#sUnits do
            local unitID = sUnits[i]
            if UnitDefs[spGetUnitDefID(unitID)].canFly then
                return CMD_LAND_AT_SPECIFIC_AIRBASE
            end
        end
        return false
    end

    --endregion

    --------------------------------------------------------------------------------
end

