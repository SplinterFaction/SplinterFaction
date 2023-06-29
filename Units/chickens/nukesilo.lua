-- UNITDEF -- ESILO --
--------------------------------------------------------------------------------

unitName                    = [[nukesilo]]

--------------------------------------------------------------------------------

name = [[Eradicator]]
description = [[Nuclear Strike Facility]]

buildpic = [[esilo.png]]

weapon1 = [[nukemissile]]

footprintx = 16
footprintz = 16

buildCostMetal = 20000
objectname = [[esilo2.s3o]]
script = [[esilo2.cob]]
deathexplosion = [[nukemissile]]

VFS.Include("units-configs-basedefs/basedefs/chickens/nukesilo_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------