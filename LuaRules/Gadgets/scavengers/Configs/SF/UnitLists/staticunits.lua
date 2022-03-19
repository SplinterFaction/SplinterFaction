local function getUnitIDList(unitNameList)
	local unitDefIDList = {}
	for _, unitName in ipairs(unitNameList) do
		local unitDefID = UnitDefNames[unitName].id
		unitDefIDList[unitDefID] = true
	end

	return unitDefIDList
end

local scavSpawnEffectUnit = "scavengerdroppod_scav"
local scavSpawnBeacon = "scavengerdroppodbeacon_scav"
local friendlySpawnEffectUnit = "scavengerdroppodfriendly"

local scavSpawnEffectUnitID = UnitDefNames[scavSpawnEffectUnit].id
local scavSpawnBeaconID = UnitDefNames[scavSpawnBeacon].id
local friendlySpawnEffectUnitID = UnitDefNames[friendlySpawnEffectUnit].id

local noSelfDestruct = {
	"lootboxgold_scav",
	"lootboxplatinum_scav",
	"lootboxsilver_scav",
	"lootboxbronze_scav",
}

local walls = {

}

local stockpilers = {
}

local nukes = {
	"esilo_scav",
	"esiloplanetcracker_scav",
}

local beaconCaptureExclusions = {
}

local beaconDefencesLand = {
	T0 = {
		-- T0
		"elightturret2_scav",
		"elaserbattery_scav",
	},

	T1 = {
		-- T0
		"elightturret2_scav",
		"elaserbattery_scav",
	},

	T2 = {
		-- T0
		"eheavyturret2_scav",
		"eflakturret_scav",
		"ekmar_scav",
	},

	T3 = {
		"eheavyturret2_scav",
		"eflakturret_scav",
		"ekmar_scav",
	},

	T4 = {
		"eartyturret_scav",
		"eartyturretvulcan_scav",
		"esilo_scav",
	},
}

local beaconDefencesSea = {
	T0 = {

	},

	T1 = {

	},

	T2 = {

	},
  
	T3 = {

	},

	T4 = {

	},
}

local noSelfDestructID = getUnitIDList(noSelfDestruct)
local wallsID = getUnitIDList(walls)
local stockpilersID = getUnitIDList(stockpilers)
local nukesID = getUnitIDList(nukes)
local beaconCaptureExclusionsID = getUnitIDList(beaconCaptureExclusions)

return {
	scavSpawnEffectUnit = scavSpawnEffectUnit,
	scavSpawnEffectUnitID = scavSpawnEffectUnitID,
	friendlySpawnEffectUnit = friendlySpawnEffectUnit,
	friendlySpawnEffectUnitID = friendlySpawnEffectUnitID,
	scavSpawnBeacon = scavSpawnBeacon,
	scavSpawnBeaconID = scavSpawnBeaconID,
	NoSelfDestruct = noSelfDestruct,
	NoSelfDestructID = noSelfDestructID,
	Walls = walls,
	WallsID = wallsID,
	Stockpilers = stockpilers,
	StockpilersID = stockpilersID,
	Nukes = nukes,
	NukesID = nukesID,
	BeaconCaptureExclusions = beaconCaptureExclusions,
	BeaconCaptureExclusionsID = beaconCaptureExclusionsID,
	BeaconDefencesLand = beaconDefencesLand,
	BeaconDefencesSea = beaconDefencesSea,
}