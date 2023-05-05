--------------------------------------------------------------------------------

unitName = "chickenbasher"

--------------------------------------------------------------------------------

humanName = [[Basher]]

objectName = "chickenbasher.s3o"
script = "chickenbasher.cob"


VFS.Include("Units-Configs-Basedefs/basedefs/chickens/chickenbasher_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------