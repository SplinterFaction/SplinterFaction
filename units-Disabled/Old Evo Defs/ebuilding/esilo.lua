-- UNITDEF -- ESILO --
--------------------------------------------------------------------------------

unitName                    = [[esilo]]

--------------------------------------------------------------------------------

name = [[Eradicator]]
description = [[Nuclear Strike Facility]]

buildpic = [[esilo.png]]

armortype = [[building]]
techrequired = [[tech3]]

weapon1 = [[nukemissile]]

footprintx = 16
footprintz = 16

buildCostMetal = 1750
objectname = [[esilo2.s3o]]
script = [[esilo2.cob]]
deathexplosion = [[nukemissile]]

weaponmodel = [[enuke.s3o]]

VFS.Include("units-configs-basedefs/basedefs/buildings/esilo_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------