

-- This is unused for Spring versions <= 0.76
-- This replaces LuaCob for Spring versions > 0.76

function gadget:GetInfo()
	return {
		name = "LuaCOB",
		desc = "All the former LuaCOB stuff",
		author = "?",
		date = "January 2008",
		license = "Public domain",
		layer = 21,
		enabled = true
	}
end

if (gadgetHandler:IsSyncedCode()) then

	--SYNCED

	local destroyQueue = {}
	local createQueue={}
	local customtoggleQueue={}

	local Spring_SetUnitCOBValue = Spring.SetUnitCOBValue or Spring.UnitScript.SetUnitCOBValue

	function gadget:GameFrame(t)
		for i,u in pairs(destroyQueue) do
			Spring.DestroyUnit(u, true, false, u) --using selfD to prevent plane crashing anim
			destroyQueue[i]=nil
		end
		for i,u in pairs(createQueue) do
			Spring.CreateUnit(u.target,u.x,u.y,u.z,0,u.team)
			createQueue[i] = nil
		end
		for i,u in pairs(customtoggleQueue) do
			Spring.GiveOrderToUnit(u.unit,CMD.INSERT,{-1,u.cmdid,CMD.OPT_SHIFT,u.state},{"alt"})
			customtoggleQueue[i] = nil
		end
	end

	local function Destroy(u, ud, team)
		table.insert(destroyQueue, u)
	end

	local function GetCentralHeading(unit, ud, team)
		local x=0
		local z=0
		local count = 0
		for _,u in ipairs(Spring.GetAllUnits()) do
			local tempx, tempz
			tempx, _, tempz = Spring.GetUnitPosition(u)
			x = x + tempx
			z = z + tempz
			count = count + 1
		end
		local ux, uz
		ux, _, uz = Spring.GetUnitPosition(unit)
		return Spring.GetHeadingFromVector(x/count-ux, x/count-uz)
	end

	local function CheckUnitPower(u, ud, team, level)
		return GG.TechCheck("power",team,level,u)
	end

	function gadget:Initialize()
		gadgetHandler:RegisterGlobal("Destroy", Destroy)
		gadgetHandler:RegisterGlobal("GetCentralHeading", GetCentralHeading)
		gadgetHandler:RegisterGlobal("CheckUnitPower", CheckUnitPower)
	end

end
