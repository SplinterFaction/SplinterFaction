local function getUnitIDList(unitNameList)
	local unitDefIDList = {}
	for _, unitName in ipairs(unitNameList) do
		local unitDefID = UnitDefNames[unitName].id
		unitDefIDList[unitDefID] = true
	end

	return unitDefIDList
end

local constructors = {
	"fedcommander_scav",
	"lozcommander_scav",
	"fedcommander_up1_scav",
	"lozcommander_up1_scav",
	"fedcommander_up2_scav",
	"lozcommander_up2_scav",
	"fedcommander_up3_scav",
	"lozcommander_up3_scav",
	"fedengineer_scav",
	"lozengineer_scav",
}

local constructorsT1 = {
	"fedcommander_up1_scav",
	"lozcommander_up1_scav",
	"fedengineer_scav",
	"lozengineer_scav",
}

local constructorsT2 = {
	"fedcommander_up2_scav",
	"lozcommander_up2_scav",
	"fedengineer_scav",
	"lozengineer_scav",
}

local constructorsT3 = {
	"fedcommander_up3_scav",
	"lozcommander_up3_scav",
	"fedengineer_scav",
	"lozengineer_scav",
}

local constructorsT4 = {
	"fedcommander_up3_scav",
	"lozcommander_up3_scav",
	"fedengineer_scav",
	"lozengineer_scav",
}

local swapUnitsToScav = {

}

local swapUnitsFromScav = {

}


local playerCommanders = {
	"fedcommander",
	"lozcommander",
}

local assisters = {
	"fedorb_scav",
	"lozorb_scav",
}

local resurrectors = {
	"fedorb_scav",
	"lozorb_scav",
}

local resurrectorsSea = {
	"fedorb_scav",
	"lozorb_scav",
}

local collectors = {
	"fedorb_scav",
	"lozorb_scav",
}

local constructorsID = getUnitIDList(constructors)
local constructorsT1ID = getUnitIDList(constructorsT1)
local constructorsT2ID = getUnitIDList(constructorsT2)
local constructorsT3ID = getUnitIDList(constructorsT3)
local constructorsT4ID = getUnitIDList(constructorsT4)
local playerCommandersID = getUnitIDList(playerCommanders)
local assistersID = getUnitIDList(assisters)
local resurrectorsID = getUnitIDList(resurrectors)
local resurrectorsSeaID = getUnitIDList(resurrectorsSea)
local collectorsID = getUnitIDList(collectors)

return {
	Constructors = constructors,
	ConstructorsID = constructorsID,
	ConstructorsT1 = constructorsT1,
	ConstructorsT1ID = constructorsT1ID,
	ConstructorsT2 = constructorsT2,
	ConstructorsT2ID = constructorsT2ID,
	ConstructorsT3 = constructorsT3,
	ConstructorsT3ID = constructorsT3ID,
	ConstructorsT4 = constructorsT4,
	ConstructorsT4ID = constructorsT4ID,
	SwapUnitsToScav = swapUnitsToScav,
	SwapUnitsFromScav = swapUnitsFromScav,
	PlayerCommanders = playerCommanders,
	PlayerCommandersID = playerCommandersID,
	Assisters = assisters,
	AssistersID = assistersID,
	Resurrectors = resurrectors,
	ResurrectorsID = resurrectorsID,
	ResurrectorsSea = resurrectorsSea,
	ResurrectorsSeaID = resurrectorsSeaID,
	Collectors = collectors,
	CollectorsID = collectorsID,
}