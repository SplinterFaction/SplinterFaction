effectUnitDefs = {
------------------
------------------
	fedairplant = {
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  16, length=60, piece="engine1", onActive=false, emitVector = {0, 0, 1}}},
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  16, length=60, piece="engine2", onActive=false, emitVector = {0, 0, 1}}},
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  16, length=60, piece="engine3", onActive=false, emitVector = {0, 0, 1}}},
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  16, length=60, piece="engine4", onActive=false, emitVector = {0, 0, 1}}},
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  16, length=60, piece="engine5", onActive=false, emitVector = {0, 0, 1}}},
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  16, length=60, piece="engine6", onActive=false, emitVector = {0, 0, 1}}},
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  16, length=60, piece="engine7", onActive=false, emitVector = {0, 0, 1}}},
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  16, length=60, piece="engine8", onActive=false, emitVector = {0, 0, 1}}},
	},

	lozairplant = {
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  16, length=60, piece="engine1", onActive=false, emitVector = {0, 0, 1}}},
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  16, length=60, piece="engine2", onActive=false, emitVector = {0, 0, 1}}},
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  16, length=60, piece="engine3", onActive=false, emitVector = {0, 0, 1}}},
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  16, length=60, piece="engine4", onActive=false, emitVector = {0, 0, 1}}},
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  16, length=60, piece="engine5", onActive=false, emitVector = {0, 0, 1}}},
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  16, length=60, piece="engine6", onActive=false, emitVector = {0, 0, 1}}},
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  16, length=60, piece="engine7", onActive=false, emitVector = {0, 0, 1}}},
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  16, length=60, piece="engine8", onActive=false, emitVector = {0, 0, 1}}},
	},

	neutralscoutdrone = {
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  2, length=15, piece="engine1", onActive=true}},
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  2, length=15, piece="engine2", onActive=true}},
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  2, length=15, piece="engine3", onActive=true}},
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  2, length=15, piece="engine4", onActive=true}},
	},

	lozwasp = {
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  2, length=15, piece="engine1", onActive=true}},
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  2, length=15, piece="engine2", onActive=true}},
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  2, length=15, piece="engine3", onActive=true}},
		{class='AirJet',	options={color={1,0.5,0.0,0.75},	width =  2, length=15, piece="engine4", onActive=true}},
	},


------------------
------------------
  
	ekmar = {
	--{class='ShieldSphere',options=ShieldSphere400},
--	  {class='Bursts',options=shieldBursts200},
--    {class='StaticParticles', options=corfusNova},
--    {class='StaticParticles', options=corfusNova2},
--    {class='StaticParticles', options=corfusNova3},
--    {class='StaticParticles', options=corfusNova4},

--    {class='Bursts', options=efusion2Bursts},
    {class='ShieldJitter', options={delay=0,life=math.huge, pos={0,20,0.0}, size=1005, precision=0, strength   = 0.001, repeatEffect=true}},
  },
  
	ecommandershield = {
	--{class='ShieldSphere',options=ShieldSphere400},
--	  {class='Bursts',options=shieldBursts200},
--    {class='StaticParticles', options=corfusNova},
--    {class='StaticParticles', options=corfusNova2},
--    {class='StaticParticles', options=corfusNova3},
--    {class='StaticParticles', options=corfusNova4},

--    {class='Bursts', options=efusion2Bursts},
    {class='ShieldJitter', options={delay=0,life=math.huge, pos={0,20,0.0}, size=405, precision=0, strength   = 0.001, repeatEffect=true}},
  },
  
	blackholepowerplant = {
		{class='Bursts',options=cafusBursts},
		{class='StaticParticles',options=cafusCorona},
		{class='ShieldSphere',options=cafusShieldSphere},
		{class='ShieldJitter',	options={layer=-16, life=math.huge, pos={0,158,0}, size=100, precision=22, repeatEffect=true}},
	},
 }

effectUnitDefsXmas = {
	-- armcom = {
		-- {class='SantaHat',	options={color={0,0.7,0,1.0}, pos={0,4,0.35}, emitVector={0.3,1.0,0.2},	width =  2.7, height=6, ballSize=0.7, piece="head"}},
	-- },
	-- corcom = {
		-- {class='SantaHat',	options={pos={0,6,2}, emitVector={0.4,1.0,0.2},	width =  2.7, height=6, ballSize=0.7, piece="head"}},
	-- },
}