--------------------------------------------------------------------------------

unitName = "lozgeostub"

--------------------------------------------------------------------------------

buildCostMetal = 100

humanName = [[Geothermal Construction Stub]]

objectName = "geothermal-stub.s3o"
script = "geothermal-stub_lus.lua"

tech = [[tech0]]

explodeAs = [[smallbuildingexplosiongeneric]]

VFS.Include("units-configs-basedefs/configs/explosion_lighting_configs.lua")
VFS.Include("units-configs-basedefs/basedefs/Loz Alliance - Faction 2/lozgeostub_basedef.lua")

--------------------------------------------------------------------------------

return lowerkeys({ [unitName]     = unitDef })

--------------------------------------------------------------------------------
