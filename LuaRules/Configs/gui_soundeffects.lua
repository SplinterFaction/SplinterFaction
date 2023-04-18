
CommandSoundEffects = {
	[CMD.RESURRECT]		= {'cmd_resurrect', 0.1},
	[CMD.RECLAIM]		= {'cmd_reclaim', 0.1},
	[CMD.REPAIR]		= {'cmd_repair', 0.1},
	[CMD.REPEAT]		= {'cmd_repeat', 0.1},
	[CMD.ATTACK]		= {'cmd_attack', 0.1},
	[CMD.PATROL]		= {'cmd_patrol', 0.1},
	[CMD.FIGHT]			= {'cmd_fight', 0.1},
	[CMD.GUARD]			= {'cmd_guard', 0.1},
	[CMD.SELFD]			= {'cmd_selfd', 0.1},
	[CMD.STOP]			= {'cmd_stop', 0.1},
	[CMD.WAIT]			= {'cmd_wait', 0.1},
	[CMD.DGUN]			= {'cmd_dgun', 0.1},
	[CMD.MOVE]			= {'cmd_move', 0.1},
	[-1]				= {'cmd_build', 0.1},	-- build (cmd < 0 == -unitdefid)
	[33410] 			= {'cmd_morph_pause', 0.1}, -- CMD_MORPH_PAUSE
	[34410] 			= {'cmd_morph_queue', 0.1}, -- CMD_MORPH_QUEUE
}

for i = 31410,32409 do -- CMD_MORPH
	CommandSoundEffects[i] = {'cmd_morph', 0.1}
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
		if udef.customParams.factionname and udef.customParams.factionname == "Federation of Kala" then
			if udef.customParams.requiretech == "tech1" then
				--Spring.Echo("[RESPONSEDOUND FALLBACK]: ARMADA", udef.name)
				GUIUnitSoundEffects[udef.name] = {
					BaseSoundSelectType = "unit_select_small",
					BaseSoundMovementType = "mappoint",
				}
			end
		elseif udef.customParams.factionname and udef.customParams.factionname == "Loz Alliance" then
			--Spring.Echo("[RESPONSEDOUND FALLBACK]: CORTEX", udef.name)
			GUIUnitSoundEffects[udef.name] = {
				BaseSoundSelectType = "unitsselect",
				BaseSoundMovementType = "unitselect",
			}
		elseif udef.customParams.factionname and udef.customParams.factionname == "Neutral" then
			--Spring.Echo("[RESPONSEDOUND FALLBACK]: CORTEX", udef.name)
			GUIUnitSoundEffects[udef.name] = {
				BaseSoundSelectType = "unitselect",
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
