-- genericscavengerbuildingexplosion-small-purple
-- genericscavengerbuildingexplosion-large-purple
-- genericscavengerbuildingexplosion-medium-purple
-- genericscavengerbuildingexplosion-huge-purple

return {
  ["genericscavengerbuildingexplosion-small-purple"] = {
    centerflare = {
      air                = true,
      class              = [[heatcloud]],
      count              = 1,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        alwaysvisible      = true,
        heat               = 10,
        heatfalloff        = 1.3,
        maxheat            = 20,
        pos                = [[r-2 r2, 5, r-2 r2]],
        size               = 1,
        sizegrowth         = 5,
        speed              = [[0, 1 0, 0]],
        texture            = [[flare]],
      },
    },
	
	electricstorm = {
      air                = true,
      class              = [[CExpGenSpawner]],
      count              = 10,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        delay              = [[10 r200]],
        explosiongenerator = [[custom:scavenger_lightning_stormbolt]],
        pos                = [[-100 r200, 1, -100 r200]],
      },
    },
	
	-- put this next to groundflash
	explosionwave = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        airdrag            = 0.87,
        alwaysvisible      = true,
        colormap           = [[0.10999999940395 0 0.28999999165535 0.05	0 0 0 0.0]], -- same as groundflash colors
        directional        = false,
        emitrot            = 90,
        emitrotspread      = 5,
        emitvector         = [[0, 0, 0]],
        gravity            = [[0, 0, 0]],
        numparticles       = 1,
        particlelife       = [[200]], -- same as groundflash ttl
        particlelifespread = 0,
        particlesize       = 8, -- groundflash flashsize 25 = 1, so if flashsize is 200, particlesize here would be 8
        particlesizespread = 1,
        particlespeed      = [[8]],
        particlespeedspread = 6,
        pos                = [[0, 1, 0]],
        sizegrowth         = 0.5, -- same as groundflash circlegrowth
        sizemod            = 1.0,
        texture            = [[explosionwave]],
	  },
    },
	
    groundflash = {
      air                = true,
      alwaysvisible      = true,
      circlealpha        = 0.6,
      circlegrowth       = 0.5,
      flashalpha         = 0.6,
      flashsize          = 200,
      ground             = true,
      ttl                = 200,
      water              = true, 
	  underwater         = true,
      color = {
        [1]  = 0.50999999940395,
        [2]  = 0,
        [3]  = 0.68999999165535,
      },
    },
	
	smoke = {
      air                = true,
      count              = 8,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        agespeed           = 0.01,
        alwaysvisible      = true,
        color              = 0.1,
        pos                = [[r-60 r60, 24, r-60 r60]],
        size               = 10,
        sizeexpansion      = 0.6,
        speed              = [[r-3 r0.5, 0.1 r1, r-3 r0.5]],
        startsize          = 10,
      },
    },
	
    kickedupdirt = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0.87,
        alwaysvisible      = true,
        colormap           = [[0.25 0.25 0.25 0.5	0 0 0 0.0]],
        directional        = false,
        emitrot            = 90,
        emitrotspread      = 5,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.5, 0]],
        numparticles       = 30,
        particlelife       = 2,
        particlelifespread = 30,
        particlesize       = 2,
        particlesizespread = 1,
        particlespeed      = 2,
        particlespeedspread = 6,
        pos                = [[0, 1, 0]],
        sizegrowth         = 0.5,
        sizemod            = 1.0,
        texture            = [[bigexplosmoke]],
      },
    },
    kickedupwater = {
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      water              = true, 
	  underwater         = true,
      properties = {
        airdrag            = 0.87,
        alwaysvisible      = true,
        colormap           = [[0.7 0.7 0.9 0.35	0 0 0 0.0]],
        directional        = false,
        emitrot            = 90,
        emitrotspread      = 5,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.5, 0]],
        numparticles       = 30,
        particlelife       = 2,
        particlelifespread = 30,
        particlesize       = 2,
        particlesizespread = 1,
        particlespeed      = 2,
        particlespeedspread = 6,
        pos                = [[0, 1, 0]],
        sizegrowth         = 0.5,
        sizemod            = 1.0,
        texture            = [[wake]],
      },
    },
    orangeexplosionspikes = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        airdrag            = 0.9,
        alwaysvisible      = true,
        colormap           = [[0.7 0.8 0.9 0.03   0.9 0.5 0.2 0.01]],
        directional        = true,
        emitrot            = 45,
        emitrotspread      = 32,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.01, 0]],
        numparticles       = 16,
        particlelife       = 10,
        particlelife       = 10,
        particlelifespread = 0,
        particlesize       = 1,
        particlesizespread = 0,
        particlespeed      = 12,
        particlespeedspread = 2,
        pos                = [[0, 2, 0]],
        sizegrowth         = 1,
        sizemod            = 1,
        texture            = [[flashside2]],
        useairlos          = false,
      },
    },
    outerflash = {
      air                = true,
      class              = [[heatcloud]],
      count              = 2,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        alwaysvisible      = true,
        heat               = 10,
        heatfalloff        = 1.1,
        maxheat            = 20,
        pos                = [[r-2 r2, 5, r-2 r2]],
        size               = 1,
        sizegrowth         = 10,
        speed              = [[0, 1 0, 0]],
        texture            = [[purplenovaexplo]],
      },
    },
    unitpoofs = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        airdrag            = 0.2,
        alwaysvisible      = true,
        colormap           = [[1.0 1.0 1.0 0.04	0.11 0 0.29 0.01	0.1 0.1 0.1 0.01]],
        directional        = false,
        emitrot            = 45,
        emitrotspread      = 32,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.05, 0]],
        numparticles       = 8,
        particlelife       = 5,
        particlelifespread = 16,
        particlesize       = 20,
        particlesizespread = 0,
        particlespeed      = 48,
        particlespeedspread = 1,
        pos                = [[0, 2, 0]],
        sizegrowth         = 0.8,
        sizemod            = 1,
        texture            = [[randomdots]],
        useairlos          = false,
      },
    },
  },

  ["genericscavengerbuildingexplosion-large-purple"] = {
    centerflare = {
      air                = true,
      class              = [[heatcloud]],
      count              = 1,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        alwaysvisible      = true,
        heat               = 10,
        heatfalloff        = 1.3,
        maxheat            = 20,
        pos                = [[r-2 r2, 5, r-2 r2]],
        size               = 1,
        sizegrowth         = 12,
        speed              = [[0, 1 0, 0]],
        texture            = [[flare]],
      },
    },
	
	electricstorm = {
      air                = true,
      class              = [[CExpGenSpawner]],
      count              = 10,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        delay              = [[10 r200]],
        explosiongenerator = [[custom:scavenger_lightning_stormbolt]],
        pos                = [[-100 r200, 1, -100 r200]],
      },
    },
	
	-- put this next to groundflash
	explosionwave = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        airdrag            = 0.87,
        alwaysvisible      = true,
        colormap           = [[0.10999999940395 0 0.28999999165535 0.05	0 0 0 0.0]], -- same as groundflash colors
        directional        = false,
        emitrot            = 90,
        emitrotspread      = 5,
        emitvector         = [[0, 0, 0]],
        gravity            = [[0, 0, 0]],
        numparticles       = 1,
        particlelife       = [[200]], -- same as groundflash ttl
        particlelifespread = 0,
        particlesize       = 8, -- groundflash flashsize 25 = 1, so if flashsize is 200, particlesize here would be 8
        particlesizespread = 1,
        particlespeed      = [[8]],
        particlespeedspread = 6,
        pos                = [[0, 1, 0]],
        sizegrowth         = 2, -- same as groundflash circlegrowth
        sizemod            = 1.0,
        texture            = [[explosionwave]],
	  },
    },
	
    groundflash = {
      air                = true,
      alwaysvisible      = true,
      circlealpha        = 0.6,
      circlegrowth       = 2,
      flashalpha         = 0.6,
      flashsize          = 600,
      ground             = true,
      ttl                = 200,
      water              = true, 
	  underwater         = true,
      color = {
        [1]  = 0.50999999940395,
        [2]  = 0,
        [3]  = 0.68999999165535,
      },
    },
	
	smoke = {
      air                = true,
      count              = 8,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        agespeed           = 0.01,
        alwaysvisible      = true,
        color              = 0.1,
        pos                = [[r-60 r60, 24, r-60 r60]],
        size               = 10,
        sizeexpansion      = 0.6,
        speed              = [[r-3 r2, 0.1 r1, r-3 r2]],
        startsize          = 10,
      },
    },
	
    kickedupdirt = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0.87,
        alwaysvisible      = true,
        colormap           = [[0.25 0.25 0.25 0.5	0 0 0 0.0]],
        directional        = false,
        emitrot            = 90,
        emitrotspread      = 5,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.5, 0]],
        numparticles       = 120,
        particlelife       = 2,
        particlelifespread = 30,
        particlesize       = 2,
        particlesizespread = 1,
        particlespeed      = 10,
        particlespeedspread = 6,
        pos                = [[0, 1, 0]],
        sizegrowth         = 0.5,
        sizemod            = 1.0,
        texture            = [[bigexplosmoke]],
      },
    },
    kickedupwater = {
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      water              = true, 
	  underwater         = true,
      properties = {
        airdrag            = 0.87,
        alwaysvisible      = true,
        colormap           = [[0.7 0.7 0.9 0.35	0 0 0 0.0]],
        directional        = false,
        emitrot            = 90,
        emitrotspread      = 5,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.5, 0]],
        numparticles       = 120,
        particlelife       = 2,
        particlelifespread = 30,
        particlesize       = 2,
        particlesizespread = 1,
        particlespeed      = 10,
        particlespeedspread = 6,
        pos                = [[0, 1, 0]],
        sizegrowth         = 0.5,
        sizemod            = 1.0,
        texture            = [[wake]],
      },
    },
    orangeexplosionspikes = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        airdrag            = 0.9,
        alwaysvisible      = true,
        colormap           = [[0.7 0.8 0.9 0.03   0.9 0.5 0.2 0.01]],
        directional        = true,
        emitrot            = 45,
        emitrotspread      = 32,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.01, 0]],
        numparticles       = 16,
        particlelife       = 10,
        particlelife       = 10,
        particlelifespread = 0,
        particlesize       = 1,
        particlesizespread = 0,
        particlespeed      = 20,
        particlespeedspread = 2,
        pos                = [[0, 2, 0]],
        sizegrowth         = 1,
        sizemod            = 1,
        texture            = [[flashside2]],
        useairlos          = false,
      },
    },
    outerflash = {
      air                = true,
      class              = [[heatcloud]],
      count              = 2,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        alwaysvisible      = true,
        heat               = 10,
        heatfalloff        = 1.1,
        maxheat            = 20,
        pos                = [[r-2 r2, 5, r-2 r2]],
        size               = 1,
        sizegrowth         = 30,
        speed              = [[0, 1 0, 0]],
        texture            = [[purplenovaexplo]],
      },
    },
    unitpoofs = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        airdrag            = 0.2,
        alwaysvisible      = true,
        colormap           = [[1.0 1.0 1.0 0.04	0.11 0 0.29 0.01	0.1 0.1 0.1 0.01]],
        directional        = false,
        emitrot            = 45,
        emitrotspread      = 32,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.05, 0]],
        numparticles       = 8,
        particlelife       = 5,
        particlelifespread = 16,
        particlesize       = 20,
        particlesizespread = 0,
        particlespeed      = 48,
        particlespeedspread = 1,
        pos                = [[0, 2, 0]],
        sizegrowth         = 0.8,
        sizemod            = 1,
        texture            = [[randomdots]],
        useairlos          = false,
      },
    },
  },

  ["genericscavengerbuildingexplosion-medium-purple"] = {
    centerflare = {
      air                = true,
      class              = [[heatcloud]],
      count              = 1,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        alwaysvisible      = true,
        heat               = 10,
        heatfalloff        = 1.3,
        maxheat            = 20,
        pos                = [[r-2 r2, 5, r-2 r2]],
        size               = 1,
        sizegrowth         = 8,
        speed              = [[0, 1 0, 0]],
        texture            = [[flare]],
      },
    },
	
	electricstorm = {
      air                = true,
      class              = [[CExpGenSpawner]],
      count              = 10,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        delay              = [[10 r200]],
        explosiongenerator = [[custom:scavenger_lightning_stormbolt]],
        pos                = [[-100 r200, 1, -100 r200]],
      },
    },
	
	-- put this next to groundflash
	explosionwave = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        airdrag            = 0.87,
        alwaysvisible      = true,
        colormap           = [[0.10999999940395 0 0.28999999165535 0.05	0 0 0 0.0]], -- same as groundflash colors
        directional        = false,
        emitrot            = 90,
        emitrotspread      = 5,
        emitvector         = [[0, 0, 0]],
        gravity            = [[0, 0, 0]],
        numparticles       = 1,
        particlelife       = [[200]], -- same as groundflash ttl
        particlelifespread = 0,
        particlesize       = 8, -- groundflash flashsize 25 = 1, so if flashsize is 200, particlesize here would be 8
        particlesizespread = 1,
        particlespeed      = [[8]],
        particlespeedspread = 6,
        pos                = [[0, 1, 0]],
        sizegrowth         = 1, -- same as groundflash circlegrowth
        sizemod            = 1.0,
        texture            = [[explosionwave]],
	  },
    },
	
    groundflash = {
      air                = true,
      alwaysvisible      = true,
      circlealpha        = 0.6,
      circlegrowth       = 1,
      flashalpha         = 0.6,
      flashsize          = 400,
      ground             = true,
      ttl                = 200,
      water              = true, 
	  underwater         = true,
      color = {
        [1]  = 0.50999999940395,
        [2]  = 0,
        [3]  = 0.68999999165535,
      },
    },
	
	smoke = {
      air                = true,
      count              = 8,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        agespeed           = 0.01,
        alwaysvisible      = true,
        color              = 0.1,
        pos                = [[r-60 r60, 24, r-60 r60]],
        size               = 10,
        sizeexpansion      = 0.6,
        speed              = [[r-3 r1, 0.1 r1, r-3 r1]],
        startsize          = 10,
      },
    },
	
    kickedupdirt = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0.87,
        alwaysvisible      = true,
        colormap           = [[0.25 0.25 0.25 0.5	0 0 0 0.0]],
        directional        = false,
        emitrot            = 90,
        emitrotspread      = 5,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.5, 0]],
        numparticles       = 60,
        particlelife       = 2,
        particlelifespread = 30,
        particlesize       = 2,
        particlesizespread = 1,
        particlespeed      = 5,
        particlespeedspread = 6,
        pos                = [[0, 1, 0]],
        sizegrowth         = 0.5,
        sizemod            = 1.0,
        texture            = [[bigexplosmoke]],
      },
    },
    kickedupwater = {
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      water              = true, 
	  underwater         = true,
      properties = {
        airdrag            = 0.87,
        alwaysvisible      = true,
        colormap           = [[0.7 0.7 0.9 0.35	0 0 0 0.0]],
        directional        = false,
        emitrot            = 90,
        emitrotspread      = 5,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.5, 0]],
        numparticles       = 60,
        particlelife       = 2,
        particlelifespread = 30,
        particlesize       = 2,
        particlesizespread = 1,
        particlespeed      = 5,
        particlespeedspread = 6,
        pos                = [[0, 1, 0]],
        sizegrowth         = 0.5,
        sizemod            = 1.0,
        texture            = [[wake]],
      },
    },
    orangeexplosionspikes = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        airdrag            = 0.9,
        alwaysvisible      = true,
        colormap           = [[0.7 0.8 0.9 0.03   0.9 0.5 0.2 0.01]],
        directional        = true,
        emitrot            = 45,
        emitrotspread      = 32,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.01, 0]],
        numparticles       = 16,
        particlelife       = 10,
        particlelife       = 10,
        particlelifespread = 0,
        particlesize       = 1,
        particlesizespread = 0,
        particlespeed      = 16,
        particlespeedspread = 2,
        pos                = [[0, 2, 0]],
        sizegrowth         = 1,
        sizemod            = 1,
        texture            = [[flashside2]],
        useairlos          = false,
      },
    },
    outerflash = {
      air                = true,
      class              = [[heatcloud]],
      count              = 2,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        alwaysvisible      = true,
        heat               = 10,
        heatfalloff        = 1.1,
        maxheat            = 20,
        pos                = [[r-2 r2, 5, r-2 r2]],
        size               = 1,
        sizegrowth         = 15,
        speed              = [[0, 1 0, 0]],
        texture            = [[purplenovaexplo]],
      },
    },
    unitpoofs = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        airdrag            = 0.2,
        alwaysvisible      = true,
        colormap           = [[1.0 1.0 1.0 0.04	0.11 0 0.29 0.01	0.1 0.1 0.1 0.01]],
        directional        = false,
        emitrot            = 45,
        emitrotspread      = 32,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.05, 0]],
        numparticles       = 8,
        particlelife       = 5,
        particlelifespread = 16,
        particlesize       = 20,
        particlesizespread = 0,
        particlespeed      = 48,
        particlespeedspread = 1,
        pos                = [[0, 2, 0]],
        sizegrowth         = 0.8,
        sizemod            = 1,
        texture            = [[randomdots]],
        useairlos          = false,
      },
    },
  },

  ["genericscavengerbuildingexplosion-huge-purple"] = {
    centerflare = {
      air                = true,
      class              = [[heatcloud]],
      count              = 1,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        alwaysvisible      = true,
        heat               = 10,
        heatfalloff        = 1.3,
        maxheat            = 20,
        pos                = [[r-2 r2, 5, r-2 r2]],
        size               = 1,
        sizegrowth         = 18,
        speed              = [[0, 1 0, 0]],
        texture            = [[flare]],
      },
    },
	
	electricstorm = {
      air                = true,
      class              = [[CExpGenSpawner]],
      count              = 10,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        delay              = [[10 r200]],
        explosiongenerator = [[custom:scavenger_lightning_stormbolt]],
        pos                = [[-100 r200, 1, -100 r200]],
      },
    },
	
	-- put this next to groundflash
	explosionwave = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        airdrag            = 0.87,
        alwaysvisible      = true,
        colormap           = [[0.10999999940395 0 0.28999999165535 0.05	0 0 0 0.0]], -- same as groundflash colors
        directional        = false,
        emitrot            = 90,
        emitrotspread      = 5,
        emitvector         = [[0, 0, 0]],
        gravity            = [[0, 0, 0]],
        numparticles       = 1,
        particlelife       = [[200]], -- same as groundflash ttl
        particlelifespread = 0,
        particlesize       = 8, -- groundflash flashsize 25 = 1, so if flashsize is 200, particlesize here would be 8
        particlesizespread = 1,
        particlespeed      = [[8]],
        particlespeedspread = 6,
        pos                = [[0, 1, 0]],
        sizegrowth         = 3, -- same as groundflash circlegrowth
        sizemod            = 1.0,
        texture            = [[explosionwave]],
	  },
    },
	
    groundflash = {
      air                = true,
      alwaysvisible      = true,
      circlealpha        = 0.6,
      circlegrowth       = 3,
      flashalpha         = 0.6,
      flashsize          = 800,
      ground             = true,
      ttl                = 200,
      water              = true, 
	  underwater         = true,
      color = {
        [1]  = 0.50999999940395,
        [2]  = 0,
        [3]  = 0.68999999165535,
      },
    },
	
	smoke = {
      air                = true,
      count              = 8,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        agespeed           = 0.01,
        alwaysvisible      = true,
        color              = 0.1,
        pos                = [[r-60 r60, 24, r-60 r60]],
        size               = 10,
        sizeexpansion      = 0.6,
        speed              = [[r-3 r3, 0.1 r1, r-3 r3]],
        startsize          = 10,
      },
    },
	
    kickedupdirt = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0.87,
        alwaysvisible      = true,
        colormap           = [[0.25 0.25 0.25 0.5	0 0 0 0.0]],
        directional        = false,
        emitrot            = 90,
        emitrotspread      = 5,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.5, 0]],
        numparticles       = 160,
        particlelife       = 2,
        particlelifespread = 30,
        particlesize       = 2,
        particlesizespread = 1,
        particlespeed      = 14,
        particlespeedspread = 6,
        pos                = [[0, 1, 0]],
        sizegrowth         = 0.5,
        sizemod            = 1.0,
        texture            = [[bigexplosmoke]],
      },
    },
    kickedupwater = {
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      water              = true, 
	  underwater         = true,
      properties = {
        airdrag            = 0.87,
        alwaysvisible      = true,
        colormap           = [[0.7 0.7 0.9 0.35	0 0 0 0.0]],
        directional        = false,
        emitrot            = 90,
        emitrotspread      = 5,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.5, 0]],
        numparticles       = 160,
        particlelife       = 2,
        particlelifespread = 30,
        particlesize       = 2,
        particlesizespread = 1,
        particlespeed      = 14,
        particlespeedspread = 6,
        pos                = [[0, 1, 0]],
        sizegrowth         = 0.5,
        sizemod            = 1.0,
        texture            = [[wake]],
      },
    },
    orangeexplosionspikes = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        airdrag            = 0.9,
        alwaysvisible      = true,
        colormap           = [[0.7 0.8 0.9 0.03   0.9 0.5 0.2 0.01]],
        directional        = true,
        emitrot            = 45,
        emitrotspread      = 32,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.01, 0]],
        numparticles       = 16,
        particlelife       = 10,
        particlelife       = 10,
        particlelifespread = 0,
        particlesize       = 1,
        particlesizespread = 0,
        particlespeed      = 26,
        particlespeedspread = 2,
        pos                = [[0, 2, 0]],
        sizegrowth         = 1,
        sizemod            = 1,
        texture            = [[flashside2]],
        useairlos          = false,
      },
    },
    outerflash = {
      air                = true,
      class              = [[heatcloud]],
      count              = 2,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        alwaysvisible      = true,
        heat               = 10,
        heatfalloff        = 1.1,
        maxheat            = 20,
        pos                = [[r-2 r2, 5, r-2 r2]],
        size               = 1,
        sizegrowth         = 40,
        speed              = [[0, 1 0, 0]],
        texture            = [[purplenovaexplo]],
      },
    },
    unitpoofs = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        airdrag            = 0.2,
        alwaysvisible      = true,
        colormap           = [[1.0 1.0 1.0 0.04	0.11 0 0.29 0.01	0.1 0.1 0.1 0.01]],
        directional        = false,
        emitrot            = 45,
        emitrotspread      = 32,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.05, 0]],
        numparticles       = 8,
        particlelife       = 5,
        particlelifespread = 16,
        particlesize       = 20,
        particlesizespread = 0,
        particlespeed      = 48,
        particlespeedspread = 1,
        pos                = [[0, 2, 0]],
        sizegrowth         = 0.8,
        sizemod            = 1,
        texture            = [[randomdots]],
        useairlos          = false,
      },
    },
  },

}

