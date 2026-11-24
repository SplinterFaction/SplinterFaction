if AllowUnsafeChanges then AllowUnsafeChanges("USE AT YOUR OWN PERIL") end

VFS.Include("common/vfs_guard.lua", nil, VFS.ZIP) -- only the game's own Lua runs: see that file
VFS.Include("LuaRules/gadgets.lua", nil, VFS.ZIP)