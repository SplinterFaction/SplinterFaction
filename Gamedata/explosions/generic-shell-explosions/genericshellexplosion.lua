-- genericshellexplosion-small
-- genericshellexplosion
-- genericshellexplosion-medium
-- genericshellexplosion-large

return {
  ["genericshellexplosion-small"] = {
    useDefaultExplosions = false,
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
        gravity             = [[0,0,0]],
        numparticles        = 1,
        particlelife        = 15,
        particlelifespread  = 9,
        particlesize        = 35,
        particlesizespread  = 0,
        particlespeed       = 0,
        particlespeedspread = 0,
        rotParams           = [[-24 r48, -60 r120, -180 r360]],
        animParams          = [[7,7,30]], --[xTiles, yTiles, animLength in game frames]
        pos                 = [[0,0,0]],
        sizegrowth          = -0.5,
        sizemod             = 1,
        texture             = [[generated-impact3]],
        drawOrder           = 0,
        -- castshadow          = true,
      },
    },
  },

  ["genericshellexplosion-medium"] = {
    useDefaultExplosions = false,
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
        gravity             = [[0,0,0]],
        numparticles        = 1,
        particlelife        = 15,
        particlelifespread  = 9,
        particlesize        = 60,
        particlesizespread  = 0,
        particlespeed       = 0,
        particlespeedspread = 0,
        rotParams           = [[-24 r48, -60 r120, -180 r360]],
        animParams          = [[7,7,30]], --[xTiles, yTiles, animLength in game frames]
        pos                 = [[0,0,0]],
        sizegrowth          = -0.5,
        sizemod             = 1,
        texture             = [[generated-impact3]],
        drawOrder           = 0,
        -- castshadow          = true,
      },
    },
  },

  ["genericshellexplosion-large"] = {
    useDefaultExplosions = false,
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
        gravity             = [[0,0,0]],
        numparticles        = 1,
        particlelife        = 15,
        particlelifespread  = 9,
        particlesize        = 80,
        particlesizespread  = 0,
        particlespeed       = 0,
        particlespeedspread = 0,
        rotParams           = [[-24 r48, -60 r120, -180 r360]],
        animParams          = [[7,7,30]], --[xTiles, yTiles, animLength in game frames]
        pos                 = [[0,0,0]],
        sizegrowth          = -0.5,
        sizemod             = 1,
        texture             = [[generated-impact3]],
        drawOrder           = 0,
        -- castshadow          = true,
      },
    },
  },

}

