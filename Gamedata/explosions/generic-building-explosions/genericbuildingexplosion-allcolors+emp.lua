-- genericbuildingexplosion (all colors, normal + emp)
-- Programmatically generated: edit the tables below, not the output.

-- Per-color values. Add/remove a color here and the loop at the bottom
-- emits the full small/medium/large/huge set for it, in both normal and -emp variants.
local colors = {
  green = {
    wavemap   = [[0 1 0 0.05  0 0 0 0.0]],
    groundRGB = { 0, 1, 0 },
    poofsmap  = [[1.0 1.0 1.0 0.04  0.5 1.0 0.5 0.01  0.1 0.1 0.1 0.01]],
    outerTex  = [[greennovaexplo]],
  },
  orange = {
    wavemap   = [[1 0.5 0 0.05  0 0 0 0.0]],
    groundRGB = { 1, 0.5, 0 },
    poofsmap  = [[1.0 1.0 1.0 0.04  1.0 0.5 0.0 0.01  0.1 0.1 0.1 0.01]],
    outerTex  = [[orangenovaexplo]],
  },
  purple = {
    wavemap   = [[0.10999999940395 0 0.28999999165535 0.05  0 0 0 0.0]],
    groundRGB = { 0.50999999940395, 0, 0.68999999165535 },
    poofsmap  = [[1.0 1.0 1.0 0.04  0.11 0 0.29 0.01  0.1 0.1 0.1 0.01]],
    outerTex  = [[purplenovaexplo]],
  },
  red = {
    wavemap   = [[1 0 0 0.05  0 0 0 0.0]],
    groundRGB = { 1, 0, 0 },
    poofsmap  = [[1.0 1.0 1.0 0.04  1.0 0.5 0.5 0.01  0.1 0.1 0.1 0.01]],
    outerTex  = [[rednovaexplo]],
  },
  white = {
    wavemap   = [[1 1 1 0.05  0 0 0 0.0]],
    groundRGB = { 1, 1, 1 },
    poofsmap  = [[1.0 1.0 1.0 0.04  1.0 1.0 1.0 0.01  0.1 0.1 0.1 0.01]],
    outerTex  = [[brightblueexplo]],
  },
  blue = {
    wavemap   = [[0 0 1 0.05  0 0 0 0.0]],
    groundRGB = { 0, 0, 1 },
    poofsmap  = [[1.0 1.0 1.0 0.04  0.5 0.5 1.0 0.01  0.1 0.1 0.1 0.01]],
    outerTex  = [[bluenovaexplo]],
  },
}

-- Per-size scaling values. Everything that changes between small/medium/large/huge lives here.
local sizes = {
  small = {
    -- centerflare
    centerSizegrowth    = 5,
    -- explosionwave / groundflash
    circlegrowth        = 0.5,
    flashsize           = 200,
    -- outerflash
    outerSizegrowth     = 10,
    -- orangeexplosionspikes
    spikeSpeed          = 12,
    -- smoke speed spread (r-X rX pattern)
    smokeSpread         = 0.5,
    -- kickedupdirt / kickedupwater
    dirtParticles       = 8,
    dirtSize            = 8,
    dirtSizeSpread      = 4,
    dirtSpeed           = 5,
    dirtSpeedSpread     = 3,
    dirtSizegrowth      = 1.5,
    -- fireball
    fireballSize        = 40,
  },
  medium = {
    centerSizegrowth    = 8,
    circlegrowth        = 1,
    flashsize           = 400,
    outerSizegrowth     = 15,
    spikeSpeed          = 16,
    smokeSpread         = 1,
    dirtParticles       = 10,
    dirtSize            = 10,
    dirtSizeSpread      = 5,
    dirtSpeed           = 7,
    dirtSpeedSpread     = 3,
    dirtSizegrowth      = 1.5,
    fireballSize        = 80,
  },
  large = {
    centerSizegrowth    = 12,
    circlegrowth        = 2,
    flashsize           = 600,
    outerSizegrowth     = 30,
    spikeSpeed          = 20,
    smokeSpread         = 2,
    dirtParticles       = 12,
    dirtSize            = 12,
    dirtSizeSpread      = 6,
    dirtSpeed           = 10,
    dirtSpeedSpread     = 4,
    dirtSizegrowth      = 1.5,
    fireballSize        = 160,
  },
  huge = {
    centerSizegrowth    = 18,
    circlegrowth        = 3,
    flashsize           = 800,
    outerSizegrowth     = 40,
    spikeSpeed          = 26,
    smokeSpread         = 3,
    dirtParticles       = 14,
    dirtSize            = 14,
    dirtSizeSpread      = 7,
    dirtSpeed           = 14,
    dirtSpeedSpread     = 4,
    dirtSizegrowth      = 1.5,
    fireballSize        = 240,
  },
}

-- s = size params, c = color params, isEmp = emp variant flag.
-- isEmp drives the whole variant difference:
--   * electricstorm block is added only for emp
--   * kickedupwater block is added only for non-emp
--   * kickedupdirt swaps colormap/texture and gains water flags for emp
local function makeExplosion(s, c, isEmp)
  local t = {
    centerflare = {
      air        = true,
      class      = [[heatcloud]],
      count      = 1,
      ground     = true,
      water      = true,
      underwater = true,
      properties = {
        alwaysvisible = true,
        heat          = 10,
        heatfalloff   = 1.3,
        maxheat       = 20,
        pos           = [[r-2 r2, 5, r-2 r2]],
        size          = 1,
        sizegrowth    = s.centerSizegrowth,
        speed         = [[0, 1 0, 0]],
        texture       = [[flare]],
      },
    },

    -- put this next to groundflash
    explosionwave = {
      air        = true,
      class      = [[CSimpleParticleSystem]],
      count      = 1,
      ground     = false,
      water      = true,
      underwater = true,
      properties = {
        airdrag             = 0.87,
        alwaysvisible       = true,
        colormap            = c.wavemap, -- same as groundflash colors
        directional         = false,
        emitrot             = 90,
        emitrotspread       = 5,
        emitvector          = [[0, 0, 0]],
        gravity             = [[0, 0, 0]],
        numparticles        = 1,
        particlelife        = 200, -- same as groundflash ttl
        particlelifespread  = 0,
        particlesize        = 8,   -- groundflash flashsize 25 = 1, so if flashsize is 200, particlesize here would be 8
        particlesizespread  = 1,
        particlespeed       = 8,
        particlespeedspread = 6,
        pos                 = [[0, 1, 0]],
        sizegrowth          = s.circlegrowth, -- same as groundflash circlegrowth
        sizemod             = 1.0,
        texture             = [[explosionwave]],
      },
    },

    groundflash = {
      air           = true,
      alwaysvisible = true,
      circlealpha   = 0.6,
      circlegrowth  = s.circlegrowth,
      flashalpha    = 0.6,
      flashsize     = s.flashsize,
      ground        = true,
      ttl           = 200,
      water         = true,
      underwater    = true,
      color = {
        [1] = c.groundRGB[1],
        [2] = c.groundRGB[2],
        [3] = c.groundRGB[3],
      },
    },

    smoke = {
      air        = true,
      count      = 8,
      ground     = true,
      water      = true,
      underwater = true,
      properties = {
        agespeed      = 0.01,
        alwaysvisible = true,
        color         = 0.1,
        pos           = [[r-60 r60, 24, r-60 r60]],
        size          = 10,
        sizeexpansion = 0.6,
        speed         = [[r-3 r]] .. s.smokeSpread .. [[, 0.1 r1, r-3 r]] .. s.smokeSpread,
        startsize     = 10,
      },
    },

    kickedupdirt = {
      air        = true,
      class      = [[CSimpleParticleSystem]],
      count      = 1,
      ground     = true,
      water      = isEmp and true or nil,
      underwater = isEmp and true or nil,
      properties = {
        airdrag             = 0.87,
        alwaysvisible       = true,
        colormap            = isEmp and [[0.75 0.75 1 0.05  0 0 0 0.0]] or [[0.25 0.25 0.25 0.5  0 0 0 0.0]],
        directional         = false,
        emitrot             = 90,
        emitrotspread       = 20,
        emitvector          = [[0, 1, 0]],
        gravity             = [[0, -0.05, 0]],
        numparticles        = s.dirtParticles,
        particlelife        = 5,
        particlelifespread  = 15,
        particlesize        = s.dirtSize,
        particlesizespread  = s.dirtSizeSpread,
        particlespeed       = s.dirtSpeed,
        particlespeedspread = s.dirtSpeedSpread,
        pos                 = [[0, 1, 0]],
        sizegrowth          = s.dirtSizegrowth,
        sizemod             = 1.0,
        texture             = isEmp and [[whitelightb]] or [[bigexplosmoke]],
      },
    },

    orangeexplosionspikes = {
      air        = true,
      class      = [[CSimpleParticleSystem]],
      count      = 1,
      ground     = true,
      water      = true,
      underwater = true,
      properties = {
        airdrag             = 0.9,
        alwaysvisible       = true,
        colormap            = [[0.7 0.8 0.9 0.03   0.9 0.5 0.2 0.01]],
        directional         = true,
        emitrot             = 45,
        emitrotspread       = 32,
        emitvector          = [[0, 1, 0]],
        gravity             = [[0, -0.01, 0]],
        numparticles        = 16,
        particlelife        = 10,
        particlelifespread  = 0,
        particlesize        = 1,
        particlesizespread  = 0,
        particlespeed       = s.spikeSpeed,
        particlespeedspread = 2,
        pos                 = [[0, 2, 0]],
        sizegrowth          = 1,
        sizemod             = 1,
        texture             = [[flashside2]],
        useairlos           = false,
      },
    },

    outerflash = {
      air        = true,
      class      = [[heatcloud]],
      count      = 2,
      ground     = true,
      water      = true,
      underwater = true,
      properties = {
        alwaysvisible = true,
        heat          = 10,
        heatfalloff   = 1.1,
        maxheat       = 20,
        pos           = [[r-2 r2, 5, r-2 r2]],
        size          = 1,
        sizegrowth    = s.outerSizegrowth,
        speed         = [[0, 1 0, 0]],
        texture       = c.outerTex,
      },
    },

    unitpoofs = {
      air        = true,
      class      = [[CSimpleParticleSystem]],
      count      = 1,
      ground     = true,
      water      = true,
      underwater = true,
      properties = {
        airdrag             = 0.2,
        alwaysvisible       = true,
        colormap            = c.poofsmap,
        directional         = false,
        emitrot             = 45,
        emitrotspread       = 32,
        emitvector          = [[0, 1, 0]],
        gravity             = [[0, 0.05, 0]],
        numparticles        = 8,
        particlelife        = 5,
        particlelifespread  = 16,
        particlesize        = 20,
        particlesizespread  = 0,
        particlespeed       = 48,
        particlespeedspread = 1,
        pos                 = [[0, 2, 0]],
        sizegrowth          = 0.8,
        sizemod             = 1,
        texture             = [[randomdots]],
        useairlos           = false,
      },
    },

    fireball = {
      class      = [[CSimpleParticleSystem]],
      count      = 1,
      air        = true,
      ground     = true,
      water      = true,
      underwater = true,
      properties = {
        airdrag             = 0.97,
        colormap            = [[1 1 1 0.1   1 1 1 0.1   1 1 1 0.1   1 1 1 0.1   0 0 0 0]],
        directional         = false,
        emitrot             = 0,
        emitrotspread       = 0,
        emitvector          = [[0,0,0]],
        gravity             = [[0,0.1,0]],
        numparticles        = 1,
        particlelife        = 30,
        particlelifespread  = 9,
        particlesize        = s.fireballSize,
        particlesizespread  = 0,
        particlespeed       = 0,
        particlespeedspread = 0,
        rotParams           = [[-24 r48, -60 r120, -180 r360]],
        animParams          = [[7,7,40]], --[xTiles, yTiles, animLength in game frames]
        pos                 = [[0,0,0]],
        sizegrowth          = 1.5,
        sizemod             = 1,
        texture             = [[generated-buildingexplosion-static]],
        drawOrder           = 0,
        -- castshadow          = true,
      },
    },
    brightflare = {
      air                = true,
      class              = [[CBitmapMuzzleFlame]],
      count              = 1,
      ground             = true,
      underwater         = true,
      water              = true,
      properties = {
        colormap            = [[1 1 1 0.1   1 1 1 0.1   1 1 1 0.1   1 1 1 0.1   0 0 0 0]],
        dir                = [[0, 1, 0]],
        --gravity            = [[0.0, 0.1, 0.0]],
        frontoffset        = 0,
        animParams          = [[6,6,40]], --[xTiles, yTiles, animLength in game frames]
        fronttexture       = [[generated-furnace]],
        length             = 40,
        sidetexture        = [[none]],
        size               = s.fireballSize,
        sizegrowth         = 0,
        ttl                = 30,
        pos                = [[0, 3, 0]],
        --rotParams          = [[-10 r20, -20 r40, -180 r360]],
        drawOrder          = 0,
      },
    },
  }

  if isEmp then
    -- emp-only: lightning bolts scattered around the impact
    t.electricstorm = {
      air        = true,
      class      = [[CExpGenSpawner]],
      count      = 30,
      ground     = true,
      water      = true,
      underwater = true,
      properties = {
        delay              = [[10 r200]],
        explosiongenerator = [[custom:lightning_stormbolt]],
        pos                = [[-100 r300, 1, -100 r300]],
      },
    }
  else
    -- non-emp-only: water splash (emp uses the kickedupdirt water flags instead)
    t.kickedupwater = {
      class      = [[CSimpleParticleSystem]],
      count      = 1,
      water      = true,
      underwater = true,
      properties = {
        airdrag             = 0.87,
        alwaysvisible       = true,
        colormap            = [[0.7 0.7 0.9 0.35  0 0 0 0.0]],
        directional         = false,
        emitrot             = 90,
        emitrotspread       = 20,
        emitvector          = [[0, 1, 0]],
        gravity             = [[0, -0.05, 0]],
        numparticles        = s.dirtParticles,
        particlelife        = 5,
        particlelifespread  = 15,
        particlesize        = s.dirtSize,
        particlesizespread  = s.dirtSizeSpread,
        particlespeed       = s.dirtSpeed,
        particlespeedspread = s.dirtSpeedSpread,
        pos                 = [[0, 1, 0]],
        sizegrowth          = s.dirtSizegrowth,
        sizemod             = 1.0,
        texture             = [[wake]],
      },
    }
  end

  return t
end

-- Build and return the final table.
-- Keys stay identical to the old per-color files:
--   genericbuildingexplosion-<size>-<color>       (normal)
--   genericbuildingexplosion-<size>-<color>-emp   (emp)
local result = {}
for colorName, c in pairs(colors) do
  for sizeName, s in pairs(sizes) do
    local base = "genericbuildingexplosion-" .. sizeName .. "-" .. colorName
    result[base]            = makeExplosion(s, c, false)
    result[base .. "-emp"]  = makeExplosion(s, c, true)
  end
end
return result
