-- Enables Lua unit scripts by including the gadget from springcontent.sdz

-- Uncomment to override the directory which is scanned for *.lua unit scripts.
--UNITSCRIPT_DIR = "scripts/"

-- not "return VFS.Include(...)": as a tail call the include would lose this
-- gadget's environment (see common/vfs_guard.lua)
local result = VFS.Include("LuaGadgets/Gadgets/unit_script.lua", nil, VFS.ZIP_ONLY)
return result