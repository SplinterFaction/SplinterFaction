-- UNITDEF --FEDBOMBER --
--------------------------------------------------------------------------------

unitName = "fedbomber"

--------------------------------------------------------------------------------

isUpgraded = [[0]]

humanName = [[Broadsword]]

objectName = "fedbomber.s3o"
script = "fedbomber.cob"


tech = [[tech2]]
armortype = [[air]]

VFS.Include("Units-Configs-Basedefs/basedefs/Federation of Kala - Faction 1/Tier 2/fedbomber_basedef.lua")

unitDef.weaponDefs = weaponDefs

--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
