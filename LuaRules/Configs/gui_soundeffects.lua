
CommandSoundEffects = {
	[CMD.RESURRECT]		= {'cmd_resurrect', 1},
	[CMD.RECLAIM]		= {'cmd_reclaim', 1},
	[CMD.REPAIR]		= {'cmd_repair', 1},
	[CMD.REPEAT]		= {'cmd_repeat', 1},
	[CMD.ATTACK]		= {'cmd_attack', 1},
	[CMD.PATROL]		= {'cmd_patrol', 1},
	[CMD.FIGHT]			= {'cmd_fight', 1},
	[CMD.GUARD]			= {'cmd_guard', 1},
	[CMD.SELFD]			= {'cmd_selfd', 1},
	[CMD.STOP]			= {'cmd_stop', 1},
	[CMD.WAIT]			= {'cmd_wait', 1},
	[CMD.DGUN]			= {'cmd_dgun', 1},
	[CMD.MOVE]			= {'cmd_move', 1},
	[-1]				= {'cmd_build', 1},	-- build (cmd < 0 == -unitdefid)
	[33410] 			= {'cmd_morph_pause', 1}, -- CMD_MORPH_PAUSE
	[34410] 			= {'cmd_morph_queue', 1}, -- CMD_MORPH_QUEUE
}

for i = 31410,32409 do -- CMD_MORPH
	CommandSoundEffects[i] = {'cmd_morph', 1}
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

		if udef.customParams.unittype == "mobile" then
			if udef.customParams.requiretech == "tech0" or udef.customParams.requiretech == "tech1" then
				--Spring.Echo("[RESPONSEDOUND FALLBACK]: ARMADA", udef.name)
				GUIUnitSoundEffects[udef.name] = {
					BaseSoundSelectType = "unit_select_small",
					BaseSoundMovementType = "unit_movement_small",
					BaseSoundWeaponType = "unit_weapon_small",
				}
			end
			if udef.customParams.requiretech == "tech2" then
				--Spring.Echo("[RESPONSEDOUND FALLBACK]: ARMADA", udef.name)
				GUIUnitSoundEffects[udef.name] = {
					BaseSoundSelectType = "unit_select_medium",
					BaseSoundMovementType = "unit_movement_medium",
					BaseSoundWeaponType = "unit_weapon_medium",
				}
			end
			if udef.customParams.requiretech == "tech3" then
				--Spring.Echo("[RESPONSEDOUND FALLBACK]: ARMADA", udef.name)
				GUIUnitSoundEffects[udef.name] = {
					BaseSoundSelectType = "unit_select_large",
					BaseSoundMovementType = "unit_movement_large",
					BaseSoundWeaponType = "unit_weapon_large",
				}
			end
			if udef.customParams.requiretech == "tech4" then
				--Spring.Echo("[RESPONSEDOUND FALLBACK]: ARMADA", udef.name)
				GUIUnitSoundEffects[udef.name] = {
					BaseSoundSelectType = "unit_select_large",
					BaseSoundMovementType = "unit_movement_large",
					BaseSoundWeaponType = "unit_weapon_large",
				}
			end
		elseif udef.customParams.unittype == "mobile" then
			--Spring.Echo("[RESPONSEDOUND FALLBACK]: ARMADA", udef.name)
			GUIUnitSoundEffects[udef.name] = {
				BaseSoundSelectType = "unit_select_small",
				BaseSoundMovementType = "unit_movement_small",
				BaseSoundWeaponType = "unit_weapon_small",
			}
		end

		if udef.customParams.unittype == "building" then
			if udef.customParams.unitrole == "Economy" then
				GUIUnitSoundEffects[udef.name] = {
					BaseSoundSelectType = "building_select_eco",
					BaseSoundMovementType = "building_movement_generic",
					BaseSoundWeaponType = "building_weapon_generic",
				}
			end
			if udef.customParams.unitrole == "Factory" then
				GUIUnitSoundEffects[udef.name] = {
					BaseSoundSelectType = "building_select_factory",
					BaseSoundMovementType = "building_movement_generic",
					BaseSoundWeaponType = "building_weapon_generic",
				}
			end
			if udef.customParams.unitrole_sound == "turret" then
				GUIUnitSoundEffects[udef.name] = {
					BaseSoundSelectType = "building_select_factory",
					BaseSoundMovementType = "building_movement_generic",
					BaseSoundWeaponType = "building_weapon_generic",
				}
			end

		elseif udef.customParams.unittype == "building" then
			GUIUnitSoundEffects[udef.name] = {
				BaseSoundSelectType = "building_select_generic",
				BaseSoundMovementType = "building_movement_generic",
				BaseSoundWeaponType = "building_weapon_generic",
			}
		end

		if udef.customParams.unitrole == "Commander" then
			GUIUnitSoundEffects[udef.name] = {
				BaseSoundSelectType = "commander_select_generic",
				BaseSoundMovementType = "commander_movement_generic",
				BaseSoundWeaponType = "commander_weapon_generic",
			}
		end
	end
end
