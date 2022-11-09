-- $Id: modrules.lua 3300 2008-11-25 10:31:04Z lurker $
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    modrules.lua
--  brief:   modrules definitions
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

VFS.Include('init.lua')

local modrules  = {

--   system = {
--		 pathFinderSystem = 1, -- QTPFS
--   },

  movement = {
    allowAirPlanesToLeaveMap = true,  -- defaults to true
	allowAircraftToHitGround = false,
    allowPushingEnemyUnits   = true, -- defaults to false
    allowCrushingAlliedUnits = false, -- defaults to false
    allowUnitCollisionDamage = false, -- defaults to false
	allowUnitCollisionOverlap = true,  -- defaults to true     -- this lets units clump close together when moving, after which they are pushed apart
	allowGroundUnitGravity = false,
  },
  
  construction = {
    constructionDecay      = true, -- defaults to true
    constructionDecayTime  = 10,  -- defaults to 6.66
    constructionDecaySpeed = 1,  -- defaults to 0.03
  },


  reclaim = {
    multiReclaim  = 1,    -- defaults to 0
    reclaimMethod = 0,    -- defaults to 1
    unitMethod    = 0,    -- defaults to 1

    unitEnergyCostFactor    = 0,  -- defaults to 0
    unitEfficiency          = 1,  -- defaults to 1
    featureEnergyCostFactor = 0,  -- defaults to 0

    allowEnemies  = false,  -- defaults to true
    allowAllies   = false,  -- defaults to true
  },


  repair = {
    energyCostFactor = 1,  -- defaults to 0
  },


  resurrect = {
    energyCostFactor = 1,  -- defaults to 0.5
  },


  capture = {
    energyCostFactor = 1,  -- defaults to 0
  },


  sensors = {
    requireSonarUnderWater = false,  -- defaults to true

    los = {
      losMipLevel = 1,  -- defaults to 1
      airMipLevel = 1,  -- defaults to 2
	  radarMipLevel  = 2,
    },
  },

  system = {
    pathFinderSystem = 0,			-- Which pathfinder does the game use? Can be 0 - The legacy default pathfinder, 1 - Quad-Tree Pathfinder System (QTPFS) or -1 - disabled.
    pathFinderUpdateRate = 0.007,	-- default: 0.007.  Controls how often the pathfinder updates; larger values means more rapid updates.
    pathFinderRawDistMult = 100000,	-- default: 1.25.  Engine does raw move with a limited distance, this multiplier adjusts that
    allowTake = true,				-- Enables and disables the /take UI command.
  },

  transportability = {
    transportGround = 1,   -- defaults to true
    transportHover  = 1,   -- defaults to false
    transportShip   = 0,  -- defaults to false
    transportAir    = 0,  -- defaults to false
  },


  flankingBonus = {
    -- defaults to 1
    -- 0: no flanking bonus
    -- 1: global coords, mobile
    -- 2: unit coords, mobile
    -- 3: unit coords, locked
    defaultMode=0,
  },


  experience = {
    experienceMult = 1, -- defaults to 1.0

    -- these are all used in the following form:
    --   value = defValue * (1 + (scale * (exp / (exp + 1))))
    powerScale  = 0,  -- defaults to 1.0
    healthScale = 0,  -- defaults to 0.7
    reloadScale = 0,  -- defaults to 0.4
  },


  fireAtDead = {
    fireAtKilled   = false,  -- defaults to false
    fireAtCrashing = false,   -- defaults to false
  },


  nanospray = {
    allow_team_colors = true,  -- defaults to true
  },

  featureLOS = {
    -- 0 - no default LOS for features
    -- 1 - gaia features always visible
    -- 2 - allyteam/gaia features always visible
    -- 3 - all features always visible
    -- default 3
    featureVisibility = 3,
  },
  
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return modrules

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
