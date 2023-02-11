--[[

Syntax:

local groupDefs = {
	["group_spawner"] = {
		"group_member_1",
		"group_member_2",
		...
		"group_member_n",
	},
	... -- more group spawners
}

where:

  group_spawner is the unitname of the unit that spawns the
group upon completion. This unit has to be build from a factory.
When it is created, it will spawn the units specified in its
squad_member array.

  squad_member_n is the unit name of one unit to spawn in
the group. There can be as many group_members as needed. The
members of the group will keep individual control, ie. untied
to the spawner unit. Nevertheless, the whole group inherits the
orders and states of the factory, just like the original unit.

]]--

local groupDefs = VFS.Include("luarules/configs/group_defs_loader.lua")

-------------------------------------------------
-- Dont touch below here
-------------------------------------------------

if UnitDefNames then
    local groupDefIDs = { }

    for i, group in pairs(groupDefs) do
        unitDef = UnitDefNames[i]
        if unitDef ~= nil then
            groupDefIDs[unitDef.id] = group
        else
            Spring.Log('group defs', 'error', "  Bad unitName! " .. i)
        end
    end

    for i, group in pairs(groupDefIDs) do
        groupDefs[i] = group
    end
end

return groupDefs