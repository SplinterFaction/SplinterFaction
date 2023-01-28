

return {
  ["blacksmoke"] = {
    smoke = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 2,
      ground             = true,
      water				 = true,
      underwater		 = false,
      properties = {
        airdrag            = 0.7,
        --alwaysvisible      = true,
        colormap           = [[0.2 0.2 0.2 1    0.2 0.2 0.2 1   0.2 0.2 0.2 1    0 0 0 0]],
        directional        = true,
        emitrot            = 0,
        emitrotspread      = 0,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0, 0]],
        numparticles       = 1,
        particlelife       = 20,
        particlelifespread = 5,
        particlesize       = 1,
        particlesizespread = 0,
        particlespeed      = 0,
        particlespeedspread = 0,
        sizegrowth         = 2,
        sizemod            = 1,
        rotParams           = [[0, 0, 0]],
        animParams          = [[4,4,8]], --[xTiles, yTiles, animLength in game frames]
        pos                 = [[0,4,0]],
        texture            = [[generated-smokerising]],
        useairlos          = false,
      },
    },
  },

  ["blacksmokesmall"] = {
    smoke = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 2,
      ground             = true,
      water				 = true,
      underwater		 = false,
      properties = {
        airdrag            = 0.7,
        --alwaysvisible      = true,
        colormap           = [[0.2 0.2 0.2 1    0.2 0.2 0.2 1   0.2 0.2 0.2 1    0 0 0 0]],
        directional        = true,
        emitrot            = 0,
        emitrotspread      = 0,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0, 0]],
        numparticles       = 1,
        particlelife       = 20,
        particlelifespread = 5,
        particlesize       = 1,
        particlesizespread = 0,
        particlespeed      = 0,
        particlespeedspread = 0,
        sizegrowth         = 1,
        sizemod            = 1,
        rotParams           = [[0, 0, 0]],
        animParams          = [[4,4,8]], --[xTiles, yTiles, animLength in game frames]
        pos                 = [[0,4,0]],
        texture            = [[generated-smokerising]],
        useairlos          = false,
      },
    },
  },
}

