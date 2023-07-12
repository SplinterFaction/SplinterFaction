Spring.Utilities = Spring.Utilities or {}
if not Spring.Utilities.Base64Decode then
	VFS.Include("common/luaUtilities/base64.lua", nil, VFS.GAME)
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
--deep not safe with circular tables! defaults To false
function Spring.Utilities.CopyTable(tableToCopy, deep, appendTo)
	local copy = appendTo or {}
	for key, value in pairs(tableToCopy) do
		if (deep and type(value) == "table") then
			copy[key] = Spring.Utilities.CopyTable(value, true)
		else
			copy[key] = value
		end
	end
	return copy
end