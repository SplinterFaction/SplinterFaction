-- UNITDEF -- ESILOPLANETCRACKER --
--------------------------------------------------------------------------------

unitName                    = [[esiloplanetcracker]]

--------------------------------------------------------------------------------

name = [[Planetcracker]]
description = [[World Destroying Nuclear Missile Facility]]

buildpic = [[esiloplanetcracker.png]]

armortype = [[building]]
techrequired = [[tech3]]

weapon1 = [[planetcracker]]

footprintx = 32
footprintz = 32

buildCostMetal = 100000
objectname = [[esiloplanetcracker.s3o]]
script = [[esilo2.cob]]
deathexplosion = [[planetcracker]]

weaponmodel = [[planetcrackernuke.s3o]]

VFS.Include("units-configs-basedefs/basedefs/buildings/esilo_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------