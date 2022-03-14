-- UNITDEF -- ESILOPLANETCRACKER --
--------------------------------------------------------------------------------

unitName                    = [[esiloplanetcracker]]

--------------------------------------------------------------------------------

name = [[Planetcracker: World Destroying Nuclear Missile]]

armortype					 = [[building]]
techrequired				 = [[tech3]]

weapon1 = [[planetcracker]]

buildCostMetal = 1750
objectname = [[esilo2.s3o]]
script = [[esilo2.cob]]
deathexplosion = [[planetcracker]]

VFS.Include("units-configs-basedefs/basedefs/buildings/esilo_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------