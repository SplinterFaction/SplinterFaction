--------------------------------------------------------------------------------

unitName = [[fedbertha]]

--------------------------------------------------------------------------------

humanName = [[Big Bertha]]

objectName = [[fedbertha.s3o]]
script = [[fedbertha_lus.lua]]

tech = [[tech3]]

VFS.Include("units-configs-basedefs/basedefs/Federation of Kala - Faction 1/buildings/fedbertha_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------