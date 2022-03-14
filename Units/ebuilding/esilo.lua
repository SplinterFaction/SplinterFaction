-- UNITDEF -- ESILO --
--------------------------------------------------------------------------------

unitName                    = [[esilo]]

--------------------------------------------------------------------------------

name = [[Eradicator: Nuclear Strike Facility]]

armortype					 = [[building]]
techrequired				 = [[tech3]]

weapon1 = [[nukemissile]]

buildCostMetal = 1750
objectname = [[esilo2.s3o]]
script = [[esilo2.cob]]
deathexplosion = [[nukemissile]]

VFS.Include("units-configs-basedefs/basedefs/buildings/esilo_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------