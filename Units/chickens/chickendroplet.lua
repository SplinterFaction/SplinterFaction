--------------------------------------------------------------------------------

unitName = "chickendroplet"

--------------------------------------------------------------------------------

humanName = [[Droplet]]

objectName = "chickendroplet.s3o"
script = "chickendroplet.cob"


VFS.Include("Units-Configs-Basedefs/basedefs/chickens/chickendroplet_basedef.lua")

unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------