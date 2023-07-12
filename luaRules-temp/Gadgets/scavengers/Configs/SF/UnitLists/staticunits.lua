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
	"fedbertha_scav",
	"lozintimidator_scav",
}

local beaconCaptureExclusions = {
}

local beaconDefencesLand = {
	T0 = {
		-- T0
		[[fedmenlo_scav]],
		[[lozjericho_scav]],
		[[fedwasp_scav]],
		[[lozrazor_scav]],
	},

	T1 = {
		-- T0
		[[fedmenlo_scav]],
		[[lozjericho_scav]],
		[[fedwasp_scav]],
		[[lozrazor_scav]],
	},

	T2 = {
		-- T0
		[[fedimmolator_scav]],
		[[lozinferno_scav]],
		[[fedjavelin_scav]],
		[[lozrattlesnake_scav]],
	},

	T3 = {
		[[fedguardian_scav]],
		[[lozannihilator_scav]],
	},

	T4 = {
		[[fedbertha_scav]],
		[[lozannihilator_scav]],
	},
}

local beaconDefencesSea = {
	T0 = {
		[[airscout_scav]],
	},

	T1 = {
		[[airscout_scav]],
	},

	T2 = {
		[[airscout_scav]],
	},
  
	T3 = {
		[[airscout_scav]],
	},

	T4 = {
		[[airscout_scav]],
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