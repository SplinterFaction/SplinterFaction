-- nukedatbewmsmall

return {
  ["nukedatbewmsmall"] = {
    alwaysvisible      = true,
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
        gravity             = [[0,0.1,0]],
        numparticles        = 1,
        particlelife        = 30,
        particlelifespread  = 9,
        particlesize        = 120,
        particlesizespread  = 0,
        particlespeed       = 0,
        particlespeedspread = 0,
        rotParams           = [[-24 r48, -60 r120, -180 r360]],
        animParams          = [[6,6,40]], --[xTiles, yTiles, animLength in game frames]
        pos                 = [[0,0,0]],
        sizegrowth          = 1.5,
        sizemod             = 1,
        texture             = [[generated-unitexplosion-static]],
        drawOrder           = 0,
        -- castshadow          = true,
      },
    },
    groundflash = {
      air                = true,
      ground             = true,
	  water				 = true,
	  underwater		 = true,
      alwaysvisible      = true,
      circlealpha        = 0.5,
      circlegrowth       = 1,
      flashalpha         = 0.5,
      flashsize          = 500,
      ground             = true,
      ttl                = 300,
      water              = true,
      color = {
        [1]  = 1,
        [2]  = 0.69999998807907,
        [3]  = 0.30000001192093,
      },
    },
    poof01 = {
      class              = [[CSimpleParticleSystem]],
      count              = 2,
	  air                = true,
      ground             = true,
	  water				 = true,
	  underwater		 = true,
      properties = {
        airdrag            = 0.8,
        alwaysvisible      = true,
        colormap           = [[0.8 0.6 0.2 0.01   0 0 0 0.01  0.0 0.0 0.0 0.01]],
        directional        = false,
        emitrot            = 15,
        emitrotspread      = 90,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.05, 0]],
        numparticles       = 150,
        particlelife       = 15,
        particlelifespread = 90,
        particlesize       = 16,
        particlesizespread = 2,
        particlespeed      = 25,
        particlespeedspread = 6,
        pos                = [[0, 2, 0]],
        sizegrowth         = 0,
        sizemod            = 1.0,
        texture            = [[cloudexplo]],
        useairlos          = false,
      },
    },
    poof02 = {
      air                = true,
      ground             = true,
	  water				 = true,
	  underwater		 = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      properties = {
        airdrag            = 0.8,
        alwaysvisible      = true,
        colormap           = [[0.8 0.6 0 0.01 0.4 0.4 0.4 0.01  0.0 0.0 0.0 0.01]],
        directional        = false,
        emitrot            = 45,
        emitrotspread      = 32,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.5, 0]],
        numparticles       = 128,
        particlelife       = 15,
        particlelifespread = 90,
        particlesize       = 16,
        particlesizespread = 1,
        particlespeed      = 28,
        particlespeedspread = 15,
        pos                = [[0, 2, 0]],
        sizegrowth         = 1,
        sizemod            = 1.0,
        texture            = [[bigexplosmoke]],
        useairlos          = false,
      },
    },
    poof03 = {
      air                = true,
      ground             = true,
	  water				 = true,
	  underwater		 = true,
      class              = [[CSimpleParticleSystem]],
      count              = 2,
      properties = {
        airdrag            = 0.8,
        alwaysvisible      = true,
        colormap           = [[0.8 0.6 0 0.01 0 0 0 0.01  0.0 0.0 0.0 0.01]],
        directional        = false,
        emitrot            = 15,
        emitrotspread      = 300,
        emitvector         = [[0, -1, 0]],
        gravity            = [[0, 0.05, 0]],
        numparticles       = 150,
        particlelife       = 15,
        particlelifespread = 90,
        particlesize       = 16,
        particlesizespread = 3,
        particlespeed      = 32,
        particlespeedspread = 6,
        pos                = [[0, 2, 0]],
        sizegrowth         = 0,
        sizemod            = 1.0,
        texture            = [[cloudexplo]],
        useairlos          = false,
      },
    },
    poof04 = {
      air                = true,
      ground             = true,
	  water				 = true,
	  underwater		 = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      properties = {
        airdrag            = 0.8,
        alwaysvisible      = true,
        colormap           = [[0.8 0.6 0 0.01 0.4 0.4 0.4 0.01  0.0 0.0 0.0 0.01]],
        directional        = false,
        emitrot            = 45,
        emitrotspread      = 32,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.2, 0]],
        numparticles       = 20,
        particlelife       = 15,
        particlelifespread = 90,
        particlesize       = 16,
        particlesizespread = 1,
        particlespeed      = 10,
        particlespeedspread = 10,
        pos                = [[0, 2, 0]],
        sizegrowth         = 1,
        sizemod            = 1.0,
        texture            = [[bigexplosmoke]],
        useairlos          = false,
      },
    },
    pop1 = {
      air                = true,
      ground             = true,
	  water				 = true,
	  underwater		 = true,
      alwaysvisible      = true,
      class              = [[heatcloud]],
      count              = 2,
      properties = {
        alwaysvisible      = true,
        heat               = 10,
        heatfalloff        = 0.4,
        maxheat            = 10,
        pos                = [[r-10 r10, 0, r-10 r10]],
        size               = 1,
        sizegrowth         = 10,
        speed              = [[0, 0, 0]],
        texture            = [[bigexplosmoke]],
      },
    },
    pop2 = {
      air                = true,
      ground             = true,
	  water				 = true,
	  underwater		 = true,
      alwaysvisible      = true,
      class              = [[heatcloud]],
      count              = 10,
      properties = {
        alwaysvisible      = true,
        heat               = 10,
        heatfalloff        = 0.6,
        maxheat            = 15,
        pos                = [[r-150 r150, 0, r-300 r150]],
        size               = 1,
        sizegrowth         = 8,
        speed              = [[0, 0, 0]],
        texture            = [[bigexplosmoke]],
      },
    },
  },


  ["nukedatbewmsmaller"] = {
    alwaysvisible      = true,
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
        gravity             = [[0,0.1,0]],
        numparticles        = 1,
        particlelife        = 30,
        particlelifespread  = 9,
        particlesize        = 120,
        particlesizespread  = 0,
        particlespeed       = 0,
        particlespeedspread = 0,
        rotParams           = [[-24 r48, -60 r120, -180 r360]],
        animParams          = [[6,6,40]], --[xTiles, yTiles, animLength in game frames]
        pos                 = [[0,0,0]],
        sizegrowth          = 1.5,
        sizemod             = 1,
        texture             = [[generated-unitexplosion-static]],
        drawOrder           = 0,
        -- castshadow          = true,
      },
    },
    groundflash = {
      air                = true,
      ground             = true,
      water				 = true,
      underwater		 = true,
      alwaysvisible      = true,
      circlealpha        = 0.5,
      circlegrowth       = 1,
      flashalpha         = 0.5,
      flashsize          = 500,
      ground             = true,
      ttl                = 150,
      water              = true,
      color = {
        [1]  = 1,
        [2]  = 0.69999998807907,
        [3]  = 0.30000001192093,
      },
    },
    poof01 = {
      class              = [[CSimpleParticleSystem]],
      count              = 2,
      air                = true,
      ground             = true,
      water				 = true,
      underwater		 = true,
      properties = {
        airdrag            = 0.8,
        alwaysvisible      = true,
        colormap           = [[0.8 0.6 0.2 0.01   0 0 0 0.01  0.0 0.0 0.0 0.01]],
        directional        = false,
        emitrot            = 15,
        emitrotspread      = 90,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.05, 0]],
        numparticles       = 150,
        particlelife       = 15,
        particlelifespread = 90,
        particlesize       = 8,
        particlesizespread = 2,
        particlespeed      = 18,
        particlespeedspread = 4,
        pos                = [[0, 2, 0]],
        sizegrowth         = 0,
        sizemod            = 1.0,
        texture            = [[cloudexplo]],
        useairlos          = false,
      },
    },
    poof02 = {
      air                = true,
      ground             = true,
      water				 = true,
      underwater		 = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      properties = {
        airdrag            = 0.8,
        alwaysvisible      = true,
        colormap           = [[0.8 0.6 0 0.01 0.4 0.4 0.4 0.01  0.0 0.0 0.0 0.01]],
        directional        = false,
        emitrot            = 45,
        emitrotspread      = 32,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.5, 0]],
        numparticles       = 128,
        particlelife       = 15,
        particlelifespread = 90,
        particlesize       = 8,
        particlesizespread = 1,
        particlespeed      = 20,
        particlespeedspread = 7,
        pos                = [[0, 2, 0]],
        sizegrowth         = 1,
        sizemod            = 1.0,
        texture            = [[bigexplosmoke]],
        useairlos          = false,
      },
    },
    poof03 = {
      air                = true,
      ground             = true,
      water				 = true,
      underwater		 = true,
      class              = [[CSimpleParticleSystem]],
      count              = 2,
      properties = {
        airdrag            = 0.8,
        alwaysvisible      = true,
        colormap           = [[0.8 0.6 0 0.01 0 0 0 0.01  0.0 0.0 0.0 0.01]],
        directional        = false,
        emitrot            = 15,
        emitrotspread      = 300,
        emitvector         = [[0, -1, 0]],
        gravity            = [[0, 0.05, 0]],
        numparticles       = 150,
        particlelife       = 15,
        particlelifespread = 90,
        particlesize       = 8,
        particlesizespread = 3,
        particlespeed      = 25,
        particlespeedspread = 3,
        pos                = [[0, 2, 0]],
        sizegrowth         = 0,
        sizemod            = 1.0,
        texture            = [[cloudexplo]],
        useairlos          = false,
      },
    },
    poof04 = {
      air                = true,
      ground             = true,
      water				 = true,
      underwater		 = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      properties = {
        airdrag            = 0.8,
        alwaysvisible      = true,
        colormap           = [[0.8 0.6 0 0.01 0.4 0.4 0.4 0.01  0.0 0.0 0.0 0.01]],
        directional        = false,
        emitrot            = 45,
        emitrotspread      = 32,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.2, 0]],
        numparticles       = 20,
        particlelife       = 15,
        particlelifespread = 90,
        particlesize       = 8,
        particlesizespread = 1,
        particlespeed      = 5,
        particlespeedspread = 5,
        pos                = [[0, 2, 0]],
        sizegrowth         = 1,
        sizemod            = 1.0,
        texture            = [[bigexplosmoke]],
        useairlos          = false,
      },
    },
    pop1 = {
      air                = true,
      ground             = true,
      water				 = true,
      underwater		 = true,
      alwaysvisible      = true,
      class              = [[heatcloud]],
      count              = 2,
      properties = {
        alwaysvisible      = true,
        heat               = 10,
        heatfalloff        = 0.4,
        maxheat            = 10,
        pos                = [[r-10 r10, 0, r-10 r10]],
        size               = 1,
        sizegrowth         = 8,
        speed              = [[0, 0, 0]],
        texture            = [[bigexplosmoke]],
      },
    },
    pop2 = {
      air                = true,
      ground             = true,
      water				 = true,
      underwater		 = true,
      alwaysvisible      = true,
      class              = [[heatcloud]],
      count              = 10,
      properties = {
        alwaysvisible      = true,
        heat               = 10,
        heatfalloff        = 0.6,
        maxheat            = 15,
        pos                = [[r-150 r150, 0, r-300 r150]],
        size               = 1,
        sizegrowth         = 5,
        speed              = [[0, 0, 0]],
        texture            = [[bigexplosmoke]],
      },
    },
  },

}

