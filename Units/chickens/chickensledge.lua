--------------------------------------------------------------------------------

unitName = "chickensledge"

--------------------------------------------------------------------------------

humanName = [[Sledge]]

objectName = "chickensledge.s3o"
script = "chickensledge.cob"


VFS.Include("Units-Configs-Basedefs/basedefs/chickens/chickensledge_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------