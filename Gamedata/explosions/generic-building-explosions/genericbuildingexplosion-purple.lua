-- genericbuildingexplosion-purple
-- Programmatically generated: edit the tables below, not the output.

local color = {
  -- explosionwave colormap and groundflash RGB (kept in sync)
  wavemap    = [[0.10999999940395 0 0.28999999165535 0.05  0 0 0 0.0]],
  groundRGB  = { 0.50999999940395, 0, 0.68999999165535 },
  -- unitpoofs mid-stop color
  poofsmap   = [[1.0 1.0 1.0 0.04  0.11 0 0.29 0.01  0.1 0.1 0.1 0.01]],
  -- outerflash texture (color-specific nova texture)
  outerTex   = [[purplenovaexplo]],
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

local function makeExplosion(s, isEmp)
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
        colormap            = color.wavemap, -- same as groundflash colors
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
        [1] = color.groundRGB[1],
        [2] = color.groundRGB[2],
        [3] = color.groundRGB[3],
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
    kickedupwater = {
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
        texture       = color.outerTex,
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
        colormap            = color.poofsmap,
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
  }
  return t
end

-- Build and return the final table
local result = {}
for sizeName, sizeParams in pairs(sizes) do
  result["genericbuildingexplosion-" .. sizeName .. "-purple"] = makeExplosion(sizeParams, false)
end
return result
