
CommandSoundEffects = {
	[CMD.RESURRECT]		= {'ack', 0.01},
	[CMD.RECLAIM]		= {'ack', 0.01},
	[CMD.REPAIR]		= {'ack', 0.01},
	[CMD.REPEAT]		= {'ack', 0.01},
	[CMD.ATTACK]		= {'ack', 0.01},
	[CMD.PATROL]		= {'ack', 0.01},
	[CMD.FIGHT]			= {'ack', 0.01},
	[CMD.GUARD]			= {'ack', 0.01},
	[CMD.SELFD]			= {'ack', 0.01},
	[CMD.STOP]			= {'ack', 0.01},
	[CMD.WAIT]			= {'ack', 0.01},
	[CMD.DGUN]			= {'ack', 0.01},
	[CMD.MOVE]			= {'ack', 0.01},
	[-1]				= {'ack', 0.01},	-- build (cmd < 0 == -unitdefid)
	[33410] 			= {'ack', 0.01}, -- CMD_MORPH_PAUSE
	[34410] 			= {'ack', 0.01}, -- CMD_MORPH_QUEUE
}

for i = 31410,32409 do -- CMD_MORPH
	CommandSoundEffects[i] = {'ack', 0.01}
end

GUIUnitSoundEffects = {

	-- ARMADA COMMANDER
	-- armcom = {
	-- 	BaseSoundSelectType = "unitselect",
	-- 	BaseSoundMovementType = "ack",
	-- 	BaseSoundWeaponType = "laser-tiny",
	-- },

}

for _, udef in pairs(UnitDefs) do
	if (not GUIUnitSoundEffects[udef.name]) and string.find(udef.name, "chicken") then
		--Spring.Echo("[RESPONSEDOUND FALLBACK]: Chicken", udef.name)
		GUIUnitSoundEffects[udef.name] = {}
	elseif not GUIUnitSoundEffects[udef.name] then
		if string.find(udef.name, "fed") then
			--Spring.Echo("[RESPONSEDOUND FALLBACK]: ARMADA", udef.name)
			GUIUnitSoundEffects[udef.name] = {
				BaseSoundSelectType = "unitsselect",
				BaseSoundMovementType = "unitselect",
			}
		elseif string.find(udef.name, "loz") then
			--Spring.Echo("[RESPONSEDOUND FALLBACK]: CORTEX", udef.name)
			GUIUnitSoundEffects[udef.name] = {
				BaseSoundSelectType = "unitsselect",
				BaseSoundMovementType = "unitselect",
			}
		else
			if math.random(0,1) == 0 then
				--Spring.Echo("[RESPONSEDOUND FALLBACK]: OTHER, RANDOM ARMADA", udef.name)
				GUIUnitSoundEffects[udef.name] = {
					BaseSoundSelectType = "unitsselect",
					BaseSoundMovementType = "unitselect",
				}
			else
				--Spring.Echo("[RESPONSEDOUND FALLBACK]: OTHER, RANDOM CORTEX", udef.name)
				GUIUnitSoundEffects[udef.name] = {
					BaseSoundSelectType = "unitsselect",
					BaseSoundMovementType = "unitselect",
				}
			end
		end
	end
end
