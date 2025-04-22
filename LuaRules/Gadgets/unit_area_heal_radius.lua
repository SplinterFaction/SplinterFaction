function gadget:GetInfo()
	return {
		name = "Area Heal Radius",
		desc = "Heals allied units in a radius, with delay after taking damage",
		author = "ChatGPT",
		date = "2025",
		license = "MIT",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local FRAME_INTERVAL = 30  -- 1 second (assuming 30 FPS)

local trackedUnits = {}  -- healer units: [unitID] = {radius, amount, delay, allyTeam}
local lastDamaged = {}   -- damaged units: [unitID] = frame they last took damage

local GetAllUnits = Spring.GetAllUnits
local GetUnitTeam = Spring.GetUnitTeam
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitPosition = Spring.GetUnitPosition
local GetUnitHealth = Spring.GetUnitHealth
local SetUnitHealth = Spring.SetUnitHealth
local SpawnCEG = Spring.SpawnCEG
local AreTeamsAllied = Spring.AreTeamsAllied

local ValidUnitID = Spring.ValidUnitID
local GetUnitIsDead = Spring.GetUnitIsDead
local GetUnitDefID = Spring.GetUnitDefID

local areaRadiusParam = "areaheal_radius"
local areaAmountParam = "areaheal_amount"
local areaDelayParam  = "areaheal_delayafterdamage"

function gadget:Initialize()
	local allUnits = GetAllUnits()
	for _, unitID in ipairs(allUnits) do
		AddUnitIfHealer(unitID)
	end
end

local function AddUnitIfHealer(unitID)
	local defID = GetUnitDefID(unitID)
	if not defID then return end

	local cp = UnitDefs[defID].customParams
	if cp and cp[areaRadiusParam] and cp[areaAmountParam] then
		trackedUnits[unitID] = {
			radius = tonumber(cp[areaRadiusParam]),
			amount = tonumber(cp[areaAmountParam]),
			delay = tonumber(cp[areaDelayParam]) or 0,
			allyTeam = GetUnitAllyTeam(unitID)
		}
	end
end

function gadget:UnitCreated(unitID, unitDefID, team)
	AddUnitIfHealer(unitID)
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	AddUnitIfHealer(unitID)
end

function gadget:UnitDestroyed(unitID, unitDefID, team)
	trackedUnits[unitID] = nil
	lastDamaged[unitID] = nil
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, attackerID, attackerDefID, attackerTeam)
	lastDamaged[unitID] = Spring.GetGameFrame()
end

function gadget:GameFrame(frame)
	if frame % FRAME_INTERVAL ~= 0 then return end

	for healerID, data in pairs(trackedUnits) do
		local hx, hy, hz = GetUnitPosition(healerID)
		if hx then
			local units = GetUnitsInSphere(hx, hy, hz, data.radius)
			for _, targetID in ipairs(units) do
				if ValidUnitID(targetID) and not GetUnitIsDead(targetID) then
					local targetAlly = GetUnitAllyTeam(targetID)
					if AreTeamsAllied(data.allyTeam, targetAlly) then
						local lastHit = lastDamaged[targetID] or -math.huge
						local delayFrames = data.delay * 30

						if frame - lastHit >= delayFrames then
							local hp, maxHP = GetUnitHealth(targetID)
							if hp and maxHP and hp < maxHP then
								local newHP = math.min(hp + data.amount, maxHP)
								SetUnitHealth(targetID, newHP)
								local tx, ty, tz = GetUnitPosition(targetID)
								if tx then
									SpawnCEG("heal", tx, ty + 10, tz)
								end
							end
						end
					end
				end
			end
		end
	end
end
