
function gadget:GetInfo()
    return {
        name      = "Explosion_lights",
        desc      = "",
        author    = "Floris",
        date      = "April 2017",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

if gadgetHandler:IsSyncedCode() then

    -- SF: every weapon explosion is relayed. The lights/distortion configs
    -- (DeferredLightsGL4WeaponsConfig / DistortionGL4WeaponsConfig) decide
    -- per weapon what, if anything, to show; the old per-type watch list here
    -- silently dropped StarburstLauncher, AircraftBomb, TorpedoLauncher,
    -- LightningCannon and DGun explosions before they ever reached a widget.
    local cannonWeapons = {}   -- weapons that get a barrelfire (muzzle) event
    local watchedProjectiles = {}

    function gadget:Initialize()
        for wdid, wd in pairs(WeaponDefs) do
            Script.SetWatchExplosion(wdid, true)
            local wtype = wd.type
            if wtype == "Cannon" or wtype == "LaserCannon" or wtype == "DGun" then
                local minDamage = (wtype == "LaserCannon") and 10 or 20
                if (wd.damages[0] or 0) >= minDamage then
                    cannonWeapons[wdid] = true
                    watchedProjectiles[wdid] = true
                    Script.SetWatchProjectile(wdid, true)
                end
            end
        end
    end
    function gadget:Shutdown()
        for wdid in pairs(WeaponDefs) do
            Script.SetWatchExplosion(wdid, false)
        end
        for wdid in pairs(watchedProjectiles) do
            Script.SetWatchProjectile(wdid, false)
        end
    end

    function gadget:Explosion(weaponID, px, py, pz, ownerID)
        SendToUnsynced("explosion_light", px, py, pz, weaponID, ownerID)
    end

    function gadget:ProjectileCreated(projectileID, ownerID, weaponID)		-- needs: Script.SetWatchProjectile(weaponDefID, true)
		if cannonWeapons[weaponID] then	-- optionally disable this to pass through missiles too
			local px, py, pz = Spring.GetProjectilePosition(projectileID)
			SendToUnsynced("barrelfire_light", px, py, pz, weaponID, ownerID)
		end
    end

else

-------------------------------------------------------------------------------
-- Unsynced
-------------------------------------------------------------------------------

    local myAllyID = Spring.GetMyAllyTeamID()
    local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
	local spIsPosInLos = Spring.IsPosInLos
	local spGetSpectatingState = Spring.GetSpectatingState

    function gadget:PlayerChanged(playerID)
        if playerID == Spring.GetMyPlayerID() then
            myAllyID = Spring.GetMyAllyTeamID()
        end
    end

    local function SpawnExplosion(_,px,py,pz, weaponID, ownerID)
        if Script.LuaUI("GadgetWeaponExplosion") or Script.LuaUI("GadgetWeaponExplosionGrass") then
            if ownerID ~= nil then
                if spGetUnitAllyTeam(ownerID) == myAllyID or spIsPosInLos(px, py, pz, myAllyID) or select(2, spGetSpectatingState()) then
					if Script.LuaUI("GadgetWeaponExplosion") then
						Script.LuaUI.GadgetWeaponExplosion(px, py, pz, weaponID, ownerID)
					end
					if Script.LuaUI("GadgetWeaponExplosionGrass") then
						Script.LuaUI.GadgetWeaponExplosionGrass(px, py, pz, weaponID, ownerID)
					end
                end
            elseif Script.LuaUI("GadgetWeaponExplosion") then
                -- dont know when this happens and if we should show the explosion...
                Script.LuaUI.GadgetWeaponExplosion(px, py, pz, weaponID)
            end
        end
    end

    local function SpawnBarrelfire(_,px,py,pz, weaponID, ownerID)
        if Script.LuaUI("GadgetWeaponBarrelfire") then
            if ownerID ~= nil then
                if spGetUnitAllyTeam(ownerID) == myAllyID or spIsPosInLos(px, py, pz, myAllyID) then
                    Script.LuaUI.GadgetWeaponBarrelfire(px, py, pz, weaponID, ownerID)
                end
            else
                -- dont know when this happens and if we should show the explosion...
                Script.LuaUI.GadgetWeaponBarrelfire(px, py, pz, weaponID)
            end
        end
    end

    function gadget:Initialize()
        gadgetHandler:AddSyncAction("explosion_light", SpawnExplosion)
        gadgetHandler:AddSyncAction("barrelfire_light", SpawnBarrelfire)
    end

    function gadget:Shutdown()
        gadgetHandler.RemoveSyncAction("explosion_light")
        gadgetHandler.RemoveSyncAction("barrelfire_light")
    end
end
