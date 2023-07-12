function gadget:GetInfo()
	return {
		name = "turretLauncher",
		desc = "Implements the turret launcher",
		author = "KDR_11k (David Becker)",
		date = "2007-11-18",
		license = "None",
		layer = 50,
		enabled = true
	}
end

if (gadgetHandler:IsSyncedCode()) then

--SYNCED

local Weapon
local createList = {}

function gadget:Initialize()
    for _,def in pairs(WeaponDefs) do
	    if def.customParams.turretlauncherweapon == "true" then
            Weapon = def.id
		    Spring.Echo("[TurretLauncher] Watched weapon is: " .. Weapon)
	    end
    end
	if Weapon ~= nil then
		Script.SetWatchWeapon(Weapon, true)
	end
end

function gadget:Explosion(w, x, y, z, owner)
	if w == Weapon and owner then
		if not Spring.GetGroundBlocked(x,z) then
			table.insert(createList, {owner = owner, x=x,y=y,z=z})
			return true
		end
	end
	return false
end

function gadget:GameFrame(f)
	for i,c in pairs(createList) do
		Spring.CreateUnit("sensortower", c.x, c.y, c.z, 0, Spring.GetUnitTeam(c.owner))
		createList[i]=nil
	end
end

end
