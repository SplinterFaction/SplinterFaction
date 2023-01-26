return {
  ["railgun"] = {
    dirtg = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0,
        alwaysvisible      = true,
        colormap           = [[1 1 1 0.01	0.5 0.5 1 0.01	0.5 0 0 0.01  0.5 0 0 0.01]],
        directional        = true,
        emitrot            = 0,
        emitrotspread      = 0,
        emitvector         = [[dir]],
        gravity            = [[0, 0, 0]],
        numparticles       = 1,
        particlelife       = 5,
        particlelifespread = 5,
        particlesize       = [[1]],
        particlesizespread = 5,
        particlespeed      = 0,
        particlespeedspread = 1,
        pos                = [[0, 0, 0]],
        sizegrowth         = 0.5,
        sizemod            = 1.0,
        texture            = [[lightring]],
        useairlos          = false,
      },
    },
  },
}

