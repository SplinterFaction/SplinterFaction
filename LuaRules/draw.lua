-- $Id: draw.lua 4534 2009-05-04 23:35:06Z licho $

VFS.Include("common/vfs_guard.lua", nil, VFS.ZIP) -- only the game's own Lua runs: see that file

if (select == nil) then
  select = function(n,...) 
    local arg = arg
    if (not arg) then arg = {...}; arg.n = #arg end
    return arg[((n=='#') and 'n')or n]
  end
end


do  --  wrap print() in a closure
  local origPrint = print
  print = function(arg1,...)
    if (arg1) then
      arg1 = '>> ' .. tostring(arg1)
    end
    origPrint(arg1, ...)
  end
end


local allModOptions = Spring.GetModOptions()
function Spring.GetModOption(s,bool,default)
  if (bool) then
    local modOption = allModOptions[s]
    if (modOption==nil) then modOption = (default and "1") end
    return (modOption=="1")
  else
    local modOption = allModOptions[s]
    if (modOption==nil) then modOption = default end
    return modOption
  end
end


if (Spring.GetModOption("camode")=="deploy")or
   (Spring.GetModOption("camode")=="tactics")
then

  -----------------------------
  -- DEPLOYMENT MODE
  -----------------------------
  VFS.Include(Script.GetName() .. "/Deploy/draw.lua", nil, VFS.ZIP_ONLY)
  Spring.Echo("LUARULES-DRAW  (DEPLOYMENT)")

else

  -----------------------------
  -- NORMAL MODE
  -----------------------------
  -- always the archive, dev Lua or not: unsynced gadget code sees the whole
  -- game, so it is never taken from a player's loose files
  VFS.Include(Script.GetName() .. '/gadgets.lua', nil, VFS.ZIP_ONLY)
  Spring.Echo("LUARULES-DRAW  (GADGETS)")

end