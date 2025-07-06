local resources = {
      graphics = {
          decals = {
          },
         trees = {
			bark     = 'default/Bark.bmp',
            leaf     = 'default/bleaf.bmp',
            gran1    = 'default/gran.bmp',
            gran2    = 'default/gran2.bmp',
            birch1   = 'default/birch1.bmp',
            birch2   = 'default/birch2.bmp',
            birch3   = 'default/birch3.bmp',
         },
         maps = {
            detailtex   = 'default/detailtex2.bmp',
            watertex	= 'default/ocean.jpg',
         },
         groundfx = {
            groundflash = 'default/groundflash.tga',
            groundring  = 'default/groundring.tga',
            seismic     = 'default/circles.tga',
         },
         projectiletextures = {
            bubbletexture       = 'default/wake.tga',
            circularthingy		= 'default/circularthingy.tga',
            laserend			= 'default/laserend.tga',
            laserfalloff		= 'default/laserfalloff.tga',
            randdots			= 'default/randdots.tga',
            smoketrail			= 'default/smoketrail.tga',
            wake				= 'default/wake.tga',
            flare				= 'default/flare.tga',
            explo				= 'default/explo.tga',
            explofade			= 'default/explofade.tga',
            heatcloud			= 'default/explo.tga',
            flame				= 'default/flame.tga',
            muzzleside			= 'default/muzzleside.tga',
            muzzlefront			= 'default/muzzlefront.tga',
            largebeam			= 'default/largelaserfalloff.tga',
		-- Put these in "ProjectileTextures"
			--Chicken Defense effects
			uglynovaexplo='CC/uglynovaexplo.tga',
			orangesmoke3='GPL/smoke_orange.png',
			sporetrail='GPL/sporetrail.tga',
			blooddrop='PD/blooddrop.tga',
			bloodblast='PD/bloodblast.tga',
			bloodsplat='PD/bloodsplat.tga',
			blooddropwhite='PD/blooddropwhite.tga',
			bloodblastwhite='PD/bloodblastwhite.tga',
			null='PD/null.tga',
            flareprojectiletexture = 'default/randdots.tga',
         },
      }
   }

local function AutoAdd(subDir, map, filter)
  local dirList = VFS.DirList("bitmaps/" .. subDir, nil, nil, true)
  for _, fullPath in ipairs(dirList) do
    local path, key, ext = fullPath:match("bitmaps/(.*/(.*)%.(.*))")
    if not fullPath:match("/%.svn") then
    local subTable = resources["graphics"][subDir] or {}
    resources["graphics"][subDir] = subTable
      if not filter or filter == ext then
        if not map then
          table.insert(subTable, path)
        else -- a mapped subtable
          subTable[key] = path
        end
      end
    end
  end
end

-- Add default caustics, smoke and scars
AutoAdd("caustics", false)
AutoAdd("smoke", false, "tga")
AutoAdd("scars", false)
AutoAdd("decals", false)
-- Add mod groundfx and projectiletextures
AutoAdd("groundfx", true)
AutoAdd("projectiletextures", true)


return resources

