--------------------------------------------------------------------------------

unitName = "chickenvulture"

--------------------------------------------------------------------------------

humanName = [[Vulture]]

objectName = "chickenvulture.s3o"
script = "chickenvulture.cob"


VFS.Include("Units-Configs-Basedefs/basedefs/chickens/chickenvulture_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------