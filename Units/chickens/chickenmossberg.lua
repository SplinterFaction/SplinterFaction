--------------------------------------------------------------------------------

unitName = "chickenmossberg"

--------------------------------------------------------------------------------

humanName = [[Mossberg]]

objectName = "chickenmossberg.s3o"
script = "chickenmossberg.cob"


VFS.Include("Units-Configs-Basedefs/basedefs/chickens/chickenmossberg_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------