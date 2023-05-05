--------------------------------------------------------------------------------

unitName = "chickenrecluse"

--------------------------------------------------------------------------------

humanName = [[Recluse]]

objectName = "chickenrecluse.s3o"
script = "chickenrecluse.cob"


VFS.Include("Units-Configs-Basedefs/basedefs/chickens/chickenrecluse_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------