-- loader module that can be called from other parts of the code
-- for example, unitdefs_post
local groupDefs = {}
-- let's append all the side's group units to the list
-- first find all the subtables
Spring.Log('group defs loader', 'info', "Loading side starting unit tables...")
local SideFiles = VFS.DirList("luarules/configs/side_group_defs", "*.lua")
Spring.Log('group defs loader', 'info', "Found "..#SideFiles.." tables")
-- then add their contents to the main table
for _, SideFile in pairs(SideFiles) do
	Spring.Log('group defs loader', 'info', " - Processing "..SideFile)
	local tmpTable = VFS.Include(SideFile)
	if tmpTable then
		local tmpCount = 0
		for morphName, subTable in pairs(tmpTable) do
			if groupDefs[morphName] == nil then
				groupDefs[morphName] = {}
			end
			local tmpSubTable = groupDefs[morphName]
			-- add everything to it
			for paramName, param in pairs(subTable) do
				if paramName then
					tmpSubTable[paramName] = param
				else
					table.insert(tmpSubTable, param)
				end
			end
			tmpCount = tmpCount + 1
		end
		Spring.Log('group defs loader', 'info', " -- Added "..tmpCount.." entries")
		tmpTable = nil
	end
end

return groupDefs
