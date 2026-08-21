-- DeferredLightsGL4WeaponsConfig.lua (SplinterFaction)
--
-- Weapon-related lights for gfx_deferred_rendering_gl4.lua:
--   projectileDefLights[weaponDefID]  light that follows a projectile in flight
--   muzzleFlashLights[weaponDefID]    light spawned at Barrelfire
--   explosionLights[weaponDefID]      light spawned at Explosion
--   gibLight                          light on piece projectiles (death gibs)
--
-- Structure:
--   1. Base light classes (BaseClasses), size ladder (SizeRadius), colour sets.
--   2. AssignLightsToAllWeapons(): every weaponDef gets a class by weaponType,
--      scaled by damage / areaOfEffect / size / colour. This is BAR's generic
--      auto-assignment, kept intact.
--   3. SF post-pass: apply the expl_light_* / light_* customParams that SF
--      weapondefs already carry (they were honoured by the legacy
--      gfx_light_effects.lua, and this keeps that tuning meaningful).
--   4. SF name-keyed manual overrides for individual weapons.
--
-- Original: Beherith / Icexuick, GNU GPL v2.
--------------------------------------------------------------------------------

local exampleLight = {
	lightType = "point", -- or cone or beam
	pieceName = nil, -- optional
	yOffset = 10, -- optional, gives extra Y height
	fraction = 3, -- optional, only every nth projectile gets the effect (randomly)
	lightConfig = {
		posx = 0,
		posy = 0,
		posz = 0,
		radius = 0,
		r = 1,
		g = 1,
		b = 1,
		a = 1,
		color2r = 1,
		color2g = 1,
		color2b = 1,
		colortime = 15, -- point lights only, colortime in seconds for unit-attached
		dirx = 0,
		diry = 0,
		dirz = 1,
		theta = 0.5, -- cone lights only, specify direction and half-angle in radians
		pos2x = 100,
		pos2y = 100,
		pos2z = 100, -- beam lights only, specifies the endpoint of the beam
		modelfactor = 1,
		specular = 1,
		scattering = 1,
		lensflare = 1,
		lifetime = 0,
		sustain = 1,
		selfshadowing = 0,
	},
}

-- Local Variables

--------------------------------------------------------------------------------
-- Config

-- Config order is:
-- Auto-assign a lightclass to each weaponDefID
-- Override on a per-weaponDefID basis, and copy table before overriding

--------------------------------General Base Light Classes for further usage --------
local BaseClasses = {
	LaserProjectile = {
		lightType = "beam", -- or cone or beam
		lightConfig = {
			posx = 0,
			posy = 10,
			posz = 0,
			radius = 100,
			r = 1,
			g = 1,
			b = 1,
			a = 0.75,
			color2r = 0.2,
			color2g = 0.2,
			color2b = 0.2,
			colortime = 1.6,
			pos2x = 100,
			pos2y = 1000,
			pos2z = 100, -- beam lights only, specifies the endpoint of the beam
			modelfactor = 1,
			specular = 0.5,
			scattering = 2.5,
			lensflare = 1,
			lifetime = 15,
			sustain = 1.5,
			selfshadowing = 0,
		},
	},

	GreenLaserProjectile = {
		lightType = "beam", -- or cone or beam
		lightConfig = {
			posx = 0,
			posy = 10,
			posz = 0,
			radius = 100,
			r = 1,
			g = 1,
			b = 1,
			a = 1.0,
			color2r = 0.2,
			color2g = 0.2,
			color2b = 0.2,
			colortime = 9,
			pos2x = 100,
			pos2y = 1000,
			pos2z = 100, -- beam lights only, specifies the endpoint of the beam
			modelfactor = 0.3,
			specular = 0.4,
			scattering = 2.0,
			lensflare = 1,
			lifetime = 20,
			sustain = 2,
			selfshadowing = 0,
		},
	},

	BlueLaserProjectile = {
		lightType = "beam", -- or cone or beam
		lightConfig = {
			posx = 0,
			posy = 10,
			posz = 0,
			radius = 100,
			r = 1,
			g = 1,
			b = 1,
			a = 0.75,
			color2r = 0.2,
			color2g = 0.2,
			color2b = 0.2,
			colortime = 1.6,
			pos2x = 100,
			pos2y = 1000,
			pos2z = 100, -- beam lights only, specifies the endpoint of the beam
			modelfactor = 1,
			specular = 0.5,
			scattering = 1.5,
			lensflare = 1,
			lifetime = 15,
			sustain = 1.5,
			selfshadowing = 0,
		},
	},

	CannonProjectile = {
		lightType = "point", -- or cone or beam
		lightConfig = {
			posx = 0,
			posy = 10,
			posz = 0,
			radius = 125,
			r = 1,
			g = 0.8,
			b = 0.45,
			a = 0.11,
			--color2r = 0.5, color2g = 0.4, color2b = 0.23, colortime = 1.5, -- point lights only, colortime in seconds for unit-attached
			modelfactor = 0.5,
			specular = 0.6,
			scattering = 0.5,
			lensflare = 0,
			lifetime = 0,
			sustain = 0,
			selfshadowing = 0,
		},
	},

	LRPCProjectile = {
		lightType = "point", -- or cone or beam
		lightConfig = {
			posx = 0,
			posy = 0,
			posz = 0,
			radius = 150,
			--pos2x = 100, pos2y = 100, pos2z = 100,
			--dirx = 1, diry = 0, dirz = 1, theta = 0.4,
			r = 1.2,
			g = 0.80,
			b = 0.3,
			a = 0.2,
			color2r = 0.9,
			color2g = 0.45,
			color2b = 0.15,
			colortime = 60, -- point lights only, colortime in seconds for unit-attached
			modelfactor = 0.1,
			specular = -0.2,
			scattering = 0.6,
			lensflare = 2,
			lifetime = 0,
			sustain = 0,
			selfshadowing = 0,
		},
	},

	MissileProjectile = {
		lightType = "point", -- or cone or beam
		lightConfig = {
			posx = 0,
			posy = 0,
			posz = 0,
			radius = 150,
			r = 1,
			g = 0.7,
			b = 0.2,
			a = 0.15,
			color2r = 0.6,
			color2g = 0.4,
			color2b = 0.10,
			colortime = 1.6, -- point lights only, colortime in seconds for unit-attached
			modelfactor = 0.3,
			specular = 0.1,
			scattering = 0.6,
			lensflare = 8,
			lifetime = 0,
			sustain = 0,
			selfshadowing = 0,
		},
	},

	MissileProjectileEMP = {
		lightType = "point", -- or cone or beam
		lightConfig = {
			posx = 0,
			posy = 0,
			posz = 0,
			radius = 150,
			r = 1,
			g = 1,
			b = 2,
			a = 0.7,
			color2r = 0.2,
			color2g = 0.2,
			color2b = 0.5,
			colortime = 8, -- point lights only, colortime in seconds for unit-attached
			modelfactor = 0.3,
			specular = 0.1,
			scattering = 0.5,
			lensflare = 8,
			lifetime = 0,
			sustain = 0,
			selfshadowing = 3,
		},
	},

	LaserAimProjectile = {
		lightType = "cone", -- or cone or beam
		lightConfig = {
			posx = 0,
			posy = 0,
			posz = 0,
			radius = 500,
			r = 5,
			g = 0,
			b = 0,
			a = 1,
			dirx = 1,
			diry = 0,
			dirz = 1,
			theta = 0.02, -- cone lights only, specify direction and half-angle in radians
			modelfactor = 10,
			specular = 0.5,
			scattering = 1,
			lensflare = 1,
			lifetime = 0,
			sustain = 1,
			selfshadowing = 0,
		},
	},

	TorpedoProjectile = {
		lightType = "cone", -- or cone or beam
		delayUntilSubmerged = true,
		delayWaterline = 2,
		delayFrames = 8,
		lightConfig = {
			posx = 0,
			posy = 0,
			posz = 0,
			radius = 77,
			r = 1.15,
			g = 0.32,
			b = 0.03,
			a = 1,
			dirx = 1,
			diry = 0,
			dirz = 1,
			theta = 0.15, -- cone lights only, specify direction and half-angle in radians
			modelfactor = 1,
			specular = 0,
			scattering = 1,
			lensflare = 1,
			lifetime = 0,
			sustain = 1,
			selfshadowing = 4,
		},
	},

	FlameProjectile = {
		lightType = "point", -- or cone or beam
		fraction = 3, -- only spawn every nth light
		lightConfig = {
			posx = 0,
			posy = 15,
			posz = 0,
			radius = 25,
			r = 0.2,
			g = 0.12,
			b = 0.05,
			a = 0.2,
			color2r = 1.0,
			color2g = 0.45,
			color2b = 0.22,
			colortime = 33, -- point lights only, colortime in seconds for unit-attached
			modelfactor = -0.2,
			specular = -0.3,
			scattering = 0.05,
			lensflare = 0,
			lifetime = 33,
			sustain = 10,
			selfshadowing = 0,
		},
	},

	Explosion = { -- spawned on explosions
		lightType = "point", -- or cone or beam
		yOffset = 0, -- Y offsets are only ever used for explosions!
		lightConfig = {
			posx = 0,
			posy = 0,
			posz = 0,
			radius = 240,
			dirx = 0,
			diry = 10,
			dirz = 0,
			theta = 0.93, -- Give explosions a bit of a vertical bounce component
			r = 2,
			g = 2,
			b = 2,
			a = 0.6,
			color2r = 0.7,
			color2g = 0.55,
			color2b = 0.28,
			colortime = 0.1, -- point lights only, colortime in seconds for unit-attached
			modelfactor = 0.15,
			specular = 0.15,
			scattering = 0.4,
			lensflare = 1,
			lifetime = 12,
			sustain = 3,
			selfshadowing = 4,
		},
	},
	ExplosionXL = { -- spawned on explosions
		lightType = "point", -- or cone or beam
		yOffset = 0, -- Y offsets are only ever used for explosions!
		lightConfig = {
			posx = 0,
			posy = 0,
			posz = 0,
			radius = 240,
			dirx = 0,
			diry = 5,
			dirz = 0,
			theta = 0.93, -- Give explosions a bit of a vertical bounce component
			r = 2,
			g = 2,
			b = 2,
			a = 0.6,
			color2r = 0.7,
			color2g = 0.55,
			color2b = 0.28,
			colortime = 0.1, -- point lights only, colortime in seconds for unit-attached
			modelfactor = 0.15,
			specular = 0.15,
			scattering = 0.4,
			lensflare = 1,
			lifetime = 12,
			sustain = 3,
			selfshadowing = 4,
		},
	},

	ExplosionEMP = { -- spawned on explosions
		lightType = "point", -- or cone or beam
		yOffset = 12, -- Y offsets are only ever used for explosions!
		lightConfig = {
			posx = 0,
			posy = 0,
			posz = 0,
			radius = 140,
			--dirx = 0, diry = 0.018, dirz = 0, theta = 0.93,
			dirx = 0,
			diry = 0.2,
			dirz = 0,
			theta = 0.93,
			r = 2,
			g = 2,
			b = 4,
			a = 1.2,
			color2r = 0.3,
			color2g = 0.3,
			color2b = 0.6,
			colortime = 1.5, -- point lights only, colortime in seconds for unit-attached
			modelfactor = 0.3,
			specular = -0.5,
			scattering = 0.5,
			lensflare = 0,
			lifetime = 90,
			sustain = 50,
			selfshadowing = 2,
		},
	},

	MuzzleFlash = { -- spawned on projectilecreated
		lightType = "point", -- or cone or beam
		lightConfig = {
			posx = 0,
			posy = 0,
			posz = 0,
			radius = 150,
			r = 2,
			g = 2,
			b = 2,
			a = 0.7,
			color2r = 0.75,
			color2g = 0.72,
			color2b = 0.6,
			colortime = 0, -- point lights only, colortime in seconds for unit-attached
			modelfactor = 0.8,
			specular = 0.5,
			scattering = 0.6,
			lensflare = 8,
			lifetime = 6,
			sustain = 0.0035,
			selfshadowing = 4,
		},
	},

	MuzzleFlashCone = { -- not used yet - no idea
		lightType = "cone", -- or cone or beam
		lightConfig = {
			posx = 0,
			posy = 0,
			posz = 0,
			radius = 150,
			r = 2,
			g = 2,
			b = 2,
			a = 0.7,
			dirx = 1,
			diry = 0,
			dirz = 1,
			theta = 0.15,
			color2r = 0.75,
			color2g = 0.72,
			color2b = 0.6,
			colortime = 0, -- point lights only, colortime in seconds for unit-attached
			modelfactor = 0.8,
			specular = 0.5,
			scattering = 0.6,
			lensflare = 8,
			lifetime = 6,
			sustain = 0.0035,
			selfshadowing = 0,
		},
	},
}

local SizeRadius = {
	Pico = 26,
	Nano = 34,
	Micro = 44,
	Tiniest = 56,
	Tiny = 72,
	Smallest = 90,
	Smaller = 115,
	Small = 140,
	Smallish = 165,
	SmallMedium = 190,
	Medium = 220,
	Mediumer = 260,
	MediumLarge = 300,
	Large = 400,
	Larger = 500,
	Largest = 650,
	Mega = 800,
	MegaXL = 1000,
	MegaXXL = 1500,
	Giga = 2000,
	Tera = 3500,
	Planetary = 5000,
}
local ColorSets = { -- TODO add advanced dual-color sets!
	Red = { r = 1, g = 0, b = 0 },
	Green = { r = 0, g = 1, b = 0 },
	Blue = { r = 0, g = 0, b = 1 },
	Purple = { r = 0.7, g = 0.3, b = 1 },
	Yellow = { r = 1, g = 1, b = 0 },
	White = { r = 1, g = 1, b = 1 },
	Plasma = { r = 1, g = 0.8, b = 0.45 },
	HeatRay = { r = 0.88, g = 0.65, b = 0.10 },
	Emg = { r = 0.42, g = 0.32, b = 0.07 },
	Fire = { r = 0.8, g = 0.3, b = 0.05 },
	Warm = { r = 0.7, g = 0.7, b = 0.1 },
	Cold = { r = 0.5, g = 0.75, b = 1.0 },
	Emp = { r = 0.5, g = 0.5, b = 1.0 },
	Team = { r = -1, g = -1, b = -1 },
}

local globalDamageMult = tonumber(Spring.GetModOptions().multiplier_weapondamage) or 1

local function GetClosestSizeClass(desiredsize)
	local delta = math.huge
	local best = nil
	for classname, size in pairs(SizeRadius) do
		if math.abs(size - desiredsize) < delta then
			delta = math.abs(size - desiredsize)
			best = classname
		end
	end
	return best, SizeRadius[best]
end

local Lifetimes = { Fast = 5, Quick = 10, Moderate = 30, Long = 90, Glacial = 270 }

local lightClasses = {}

local function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == "table" then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		--setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end
local usedclasses = 0
local function GetLightClass(baseClassname, colorkey, sizekey, additionaloverrides)
	local lightClassKey = baseClassname .. (colorkey or "") .. (sizekey or "")
	if additionaloverrides and type(additionaloverrides) == "table" then
		for k, v in pairs(additionaloverrides) do
			lightClassKey = lightClassKey .. "_" .. tostring(k) .. "=" .. tostring(v)
		end
	end

	if lightClasses[lightClassKey] then
		return lightClasses[lightClassKey]
	else
		lightClasses[lightClassKey] = deepcopy(BaseClasses[baseClassname])
		lightClasses[lightClassKey].lightClassName = lightClassKey
		usedclasses = usedclasses + 1
		local lightConfig = lightClasses[lightClassKey].lightConfig
		if sizekey then
			lightConfig.radius = SizeRadius[sizekey]
		end
		if colorkey then
			lightConfig.r = ColorSets[colorkey].r
			lightConfig.g = ColorSets[colorkey].g
			lightConfig.b = ColorSets[colorkey].b
			if lightClasses[lightClassKey].lightType == "point" then
				lightConfig.color2r = ColorSets[colorkey].color2r or lightConfig.color2r
				lightConfig.color2g = ColorSets[colorkey].color2g or lightConfig.color2g
				lightConfig.color2b = ColorSets[colorkey].color2b or lightConfig.color2b
				lightConfig.colortime = ColorSets[colorkey].colortime or lightConfig.colortime
			end
		end
		if additionaloverrides then
			for k, v in pairs(additionaloverrides) do
				lightConfig[k] = v
			end
		end
	end
	return lightClasses[lightClassKey]
end

--------------------------------------------------------------------------------

local gibLight = {
	lightType = "point", -- or cone or beam
	pieceName = nil, -- optional
	lightConfig = {
		posx = 0,
		posy = 0,
		posz = 0,
		radius = 36,
		r = 1,
		g = 0.9,
		b = 0.5,
		a = 0.08,
		color2r = 0.9,
		color2g = 0.75,
		color2b = 0.25,
		colortime = 0.3, -- point lights only, colortime in seconds for unit-attache
		modelfactor = 0.4,
		specular = 0.5,
		scattering = 0.5,
		lensflare = 0,
		lifetime = 300,
		sustain = 3,
		selfshadowing = 0,
	},
}

--------------------------------------------------------------------------------

local muzzleFlashLights = {}
local explosionLights = {}
local projectileDefLights = {
	default = {
		lightType = "point",
		lightConfig = {
			posx = 0,
			posy = 16,
			posz = 0,
			radius = 420,
			color2r = 1,
			color2g = 1,
			color2b = 1,
			colortime = 15,
			r = -1,
			g = 1,
			b = 1,
			a = 1,
			modelfactor = 0.2,
			specular = 1,
			scattering = 1,
			lensflare = 1,
			lifetime = 50,
			sustain = 20,
			selfshadowing = 0,
		},
	},
}

-----------------------------------

local function AssignLightsToAllWeapons()
	for weaponID = 0, #WeaponDefs do
		local weaponDef = WeaponDefs[weaponID]
		local damage = 100
		for cat = 0, #weaponDef.damages do
			if Game.armorTypes[cat] and Game.armorTypes[cat] == "default" then
				damage = weaponDef.damages[cat]
				break
			end
		end

		-- correct damage multiplier modoption to more sane value
		damage = (damage / globalDamageMult) + ((damage * (globalDamageMult - 1)) * 0.25)

		local radius = (
			(weaponDef.damageAreaOfEffect * 2) + (weaponDef.damageAreaOfEffect * weaponDef.edgeEffectiveness * 1.35)
		)
		local orgMult = math.max(0.1, math.min(damage / 1600, 0.6)) + (radius / 2800)
		local life = 8 + (5 * (radius / 2000) + (orgMult * 5))
		radius = ((orgMult * 75) + (radius * 2.4)) * 0.33

		local r, g, b = 1, 0.8, 0.45
		local weaponVisuals = weaponDef.visuals
		if weaponVisuals ~= nil and weaponVisuals.colorR ~= nil then
			r = weaponVisuals.colorR
			g = weaponVisuals.colorG
			b = weaponVisuals.colorB
		end
		local muzzleFlash = true
		local explosionLight = true
		local sizeclass = GetClosestSizeClass(radius)
		local t = {}
		local aa = string.find(weaponDef.cegTag, "aa")
		if aa then
			r, g, b = 1, 0.5, 0.6
			t.color2r, t.color2g, t.color2b = 1, 0.5, 0.6
		end
		if weaponDef.paralyzer then
			r, g, b = 0.5, 0.5, 1
			t.color2r, t.color2g, t.color2b = 0.25, 0.25, 1
		end
		local scavenger = string.find(weaponDef.name, "_scav")
		if scavenger then
			r, g, b = 0.3, 0.1, 0.7
			t.color2r, t.color2g, t.color2b = 0.3, 0.1, 0.7
		end
		t.r, t.g, t.b = r, g, b

		-- if string.find(weaponDef.name, 'juno') then
		-- 	radius = 140
		-- 	orgMult = 1
		-- 	r, g, b = 0.45, 1, 0.45
		-- end

		if weaponDef.type == "BeamLaser" then
			--muzzleFlash = true -- doesn't work

			if not weaponDef.paralyzer then
				local muzzleFlash = true
				t.color2r, t.color2g, t.color2b = (r * 0.1), (g * 0.1), (b * 0.1)
				t.r, t.g, t.b = math.min(1, r + 0.25), math.min(1, g + 0.25), math.min(1, b + 0.25)
				t.life = 4
				t.colortime = 10 + (weaponDef.beamtime * 50)
				t.sustain = 1.5 + (weaponDef.beamtime * 10)
			end

			radius = (6.3 * (weaponDef.size * weaponDef.size)) + (4 * radius * orgMult)
			t.a = (orgMult * 0.14) / (0.25 + weaponDef.beamtime)
			--projectileDefLights[weaponID].yOffset = 64

			if weaponDef.paralyzer then
				radius = radius * 0.5
			end

			sizeclass = GetClosestSizeClass(radius)

			if damage < 100 then
				--life = 5
				projectileDefLights[weaponID] = GetLightClass("LaserProjectile", nil, sizeclass, t)
				projectileDefLights[weaponID].lightConfig.selfshadowing = 5 -- Screen Space Light Shadows
			elseif damage < 500 then
				projectileDefLights[weaponID] = GetLightClass("GreenLaserProjectile", nil, sizeclass, t)
				projectileDefLights[weaponID].lightConfig.selfshadowing = 5 -- Screen Space Light Shadows
			else
				projectileDefLights[weaponID] = GetLightClass("BlueLaserProjectile", nil, sizeclass, t)
				projectileDefLights[weaponID].lightConfig.selfshadowing = 5 -- Screen Space Light Shadows
			end

			if not weaponDef.paralyzer then
				radius = ((orgMult * 2500) + radius) * 0.2
				sizeclass = GetClosestSizeClass(radius)
			end
		elseif weaponDef.type == "LaserCannon" then
			radius = (4 * (weaponDef.size * weaponDef.size * weaponDef.size)) + (3 * radius * orgMult)
			t.a = (orgMult * 0.1) + weaponDef.duration

			sizeclass = GetClosestSizeClass(radius)
			projectileDefLights[weaponID] = GetLightClass("CannonProjectile", "Warm", sizeclass, t)
			--projectileDefLights[weaponID].lightConfig.selfshadowing = 1 -- Screen Space Light Shadows
		elseif weaponDef.type == "LightningCannon" then
			if not scavenger then
				t.r, t.g, t.b = 0.2, 0.45, 1
			end
			t.a = 0.13 + (orgMult * 0.5)
			sizeclass = GetClosestSizeClass(33 + (radius * 2.5))
			projectileDefLights[weaponID] = GetLightClass("LaserProjectile", "Cold", sizeclass, t)
		elseif weaponDef.type == "MissileLauncher" then
			t.a = orgMult * 0.33
			if string.find(weaponDef.name, "advsam") then --for LRAA
				radius = radius * 0.45
				t.a = orgMult * 0.44
			end
			sizeclass = GetClosestSizeClass(radius)
			projectileDefLights[weaponID] = GetLightClass("MissileProjectile", "Warm", sizeclass, t)
		elseif weaponDef.type == "StarburstLauncher" then
			t.a = orgMult * 0.44

			if weaponDef.interceptor == 1 then
				--t.a = orgMult * 1.33
				t.r, t.g, t.b = 0.5, 0.75, 1.0
				t.color2r, t.color2g, t.color2b = 0.22, 0.37, 0.79
				projectileDefLights[weaponID] = GetLightClass("MissileProjectile", "Cold", sizeclass, t)
			elseif weaponDef.paralyzer then
				t.a = orgMult * 1.2
				sizeclass = GetClosestSizeClass(radius * 0.4)
				projectileDefLights[weaponID] = GetLightClass("MissileProjectileEMP", "Warm", sizeclass, t)
			else
				sizeclass = GetClosestSizeClass(radius)
				radius = ((orgMult * 75) + (radius * 4)) * 0.4
				life = 8 + (5 * (radius / 2000) + (orgMult * 5))
				projectileDefLights[weaponID] = GetLightClass("MissileProjectile", "Warm", sizeclass, t)
			end
		elseif weaponDef.type == "Cannon" then
			t.a = orgMult * 0.17
			radius = (radius + (weaponDef.size * 35)) * 0.48
			sizeclass = GetClosestSizeClass(radius)
			projectileDefLights[weaponID] = GetLightClass("CannonProjectile", "Plasma", sizeclass, t)
			radius = (
				(weaponDef.damageAreaOfEffect * 2)
				+ (weaponDef.damageAreaOfEffect * weaponDef.edgeEffectiveness * 1.35)
			)
			projectileDefLights[weaponID].lightConfig.selfshadowing = 1 -- Screen Space Light Shadows
		elseif weaponDef.type == "DGun" then
			muzzleFlash = true --doesnt work
			sizeclass = "Medium"
			t.a = orgMult * 0.66 * 1.5
			projectileDefLights[weaponID] = GetLightClass("CannonProjectile", "Warm", sizeclass, t)
			projectileDefLights[weaponID].yOffset = 32
			projectileDefLights[weaponID].lightConfig.selfshadowing = 1 -- Screen Space Light Shadows
			--Spring.Echo(WeaponDefNames[weaponID], weaponDef.type, weaponDef.name)
		elseif weaponDef.type == "TorpedoLauncher" then
			-- Torpedo projectile lights are assigned here, but activation is delayed until water entry.
			projectileDefLights[weaponID] = GetLightClass("TorpedoProjectile", nil, nil, {})
		elseif weaponDef.type == "Shield" then
			sizeclass = "Large"
			projectileDefLights[weaponID] = GetLightClass("CannonProjectile", "Cold", sizeclass, t)

		-- elseif weaponDef.type == 'AircraftBomb' then
		-- 	t.a = life * 1.8
		-- 	projectileDefLights[weaponID] = GetLightClass("MissileProjectile", "Warm", sizeclass, t)
		elseif weaponDef.type == "Flame" then
			--sizeclass = "Small"
			sizeclass = GetClosestSizeClass(radius * 2.5)
			--t.a = orgMult * 0.17
			projectileDefLights[weaponID] = GetLightClass("FlameProjectile", nil, sizeclass, t)
		end

		if muzzleFlash then
			if aa then
				t.r, t.g, t.b = 1, 0.7, 0.85
			end
			if scavenger then
				t.r, t.g, t.b = 0.35, 0.15, 0.7
			end
			t.a = orgMult * 2.3
			t.colortime = 2.5

			if string.find(weaponDef.name, "flak") then
				radius = radius * 0.25
				--t.a = orgMult*0.8
			end

			if string.find(weaponDef.name, "legflak") then
				radius = radius * 3
				t.a = orgMult * 1.2
			end

			local adjusted_radius = radius * 0.65

			if damage < 150 then -- increase muzzleflash for low-damage units to remain visible
				adjusted_radius = adjusted_radius * 2.9 -- Increase for low-damage weapons
				t.colortime = 2.0
			end

			muzzleFlashLights[weaponID] = GetLightClass("MuzzleFlash", "White", GetClosestSizeClass(adjusted_radius), t)
			muzzleFlashLights[weaponID].yOffset = muzzleFlashLights[weaponID].lightConfig.radius / 5
		end

		if explosionLight then
			if aa then
				t.r, t.g, t.b = 1, 0.7, 0.85
			end
			if scavenger then
				t.r, t.g, t.b = 0.3, 0.1, 0.7
			end
			t.lifetime = life
			t.colortime = 35 / life --t.colortime = life * 0.17
			t.a = orgMult * 1.1

			if weaponDef.type == "DGun" then
				t.a = orgMult * 0.17
				--Spring.Echo('-==DGUN==-', weaponDef.name, radius, lightclass, sizeclass, t.a)
			elseif weaponDef.type == "Flame" then
				t.a = orgMult * 0.22
			elseif weaponDef.type == "MissileLauncher" then
				if string.find(weaponDef.name, "advsam") then --for LRAA
					--damage = 1000
					--radius = 675
					orgMult = 0.25
					radius = radius * 0.5
					--t.a = orgMult * 2.44
					--Spring.Echo(WeaponDefNames[weaponID], weaponDef.type, weaponDef.name)
					--Spring.Echo('-==--===-', weaponDef.name, radius, lightClassName, sizeclass, t.a)
					sizeclass = GetClosestSizeClass(radius)
					explosionLights[weaponID] = GetLightClass("Explosion", nil, sizeclass, t)
				end
			elseif weaponDef.type == "TorpedoLauncher" then
				-- t.r = t.r * 0.5	-- make more red
				-- t.g = t.g * 0.5	-- make more red
				-- t.b = t.b * 1.4	-- make more red
				-- t.color2r = 0.9
				-- t.color2g = 0.6
				-- t.color2b = 0.8
			elseif weaponDef.type == "BeamLaser" then
				local mult = 0.85
				t.color2r, t.color2g, t.color2b = r * mult, g * mult, b * mult
				t.colortime = 8
				t.lifetime = life * 0.6
				t.a = 0.02 + ((orgMult * 0.055) / weaponDef.beamtime) + (weaponDef.range * 0.000035)
				radius = 1.2
						* ((weaponDef.damageAreaOfEffect * 4) + (weaponDef.damageAreaOfEffect * weaponDef.edgeEffectiveness * 1.1))
					+ (weaponDef.range * 0.08)
				if string.find(weaponDef.name, "heat") then
					radius = (radius / 2.5)
					t.a = 0.01 + ((orgMult * 0.035) / weaponDef.beamtime) + (weaponDef.range * 0.000025)
					t.color2r = 1.2
					t.color2g = 0.5
					t.color2b = 0.2
					t.colortime = 0.3
					t.lifetime = 4
				end
				sizeclass = GetClosestSizeClass(radius)
			elseif weaponDef.type == "LightningCannon" then
				t.a = orgMult * 1.25
				t.color2r = 0.1
				t.color2g = 0.3
				t.color2b = 0.9
				sizeclass = GetClosestSizeClass(radius * 1.2)
			else
				if weaponDef.type == "AircraftBomb" then
					if weaponDef.paralyzer then
						t.r = t.r * 1.7 -- make more red
						t.g = t.g * 0.4 -- make more red
						t.b = t.b * 0.4 -- make more red
						life = life * 1.1 -- too high and it will flicker somehow!
						orgMult = orgMult * 0.15
						t.colortime = 31 / life
					else
						t.r = t.r * 1.7 -- make more red
						t.g = t.g * 0.4 -- make more red
						t.b = t.b * 0.4 -- make more red
						life = life * 1.2
						t.colortime = 19 / life
					end
					t.lifetime = life
				end
				radius = (
					(weaponDef.damageAreaOfEffect * 1.9)
					+ (weaponDef.damageAreaOfEffect * weaponDef.edgeEffectiveness * 1.35)
				)
				if string.find(weaponDef.name, "juno") then
					radius = 675
					orgMult = 0.25
					t.r = 1.05
					t.g = 1.3
					t.b = 0.6
					t.color2r = 0.32
					t.color2g = 0.5
					t.color2b = 0.12
					t.colortime = 200
					t.lifetime = 500
				end
				if weaponDef.customParams.unitexplosion then
					radius = radius * 1.25
					-- make more white
					t.r = (1.7 + t.r) / 2.7
					t.g = (1.7 + t.g) / 2.7
					t.b = (1.7 + t.b) / 2.7
					-- t.r = 3
					-- t.g = 3
					-- t.b = 3
					-- t.color2r = (1.5 + t.color2r) / 2.3
					-- t.color2g = (1.5 + t.color2g) / 2.3
					-- t.color2b = (1.5 + t.color2b) / 2.3
					t.a = orgMult * 2.8
					t.lifetime = life * 1.15
					--t.colortime = 8
				else
					-- make more white
					t.r = (1.4 + t.r) / 1.8
					t.g = (1.4 + t.g) / 1.8
					t.b = (1.4 + t.b) / 1.8
					t.a = orgMult * 1.3 --make all explosions bit stronger
				end
				local mult = 0.6

				t.color2r, t.color2g, t.color2b = r * mult, g * mult, b * mult
				sizeclass = GetClosestSizeClass(radius)
			end
			if not weaponDef.customParams.noexplosionlight then
				explosionLights[weaponID] = GetLightClass("Explosion", nil, sizeclass, t)
				explosionLights[weaponID].yOffset = explosionLights[weaponID].lightConfig.radius / 5
			end
		end
	end
	-- Spring.Echo("DLGL4 weapons conf using", usedclasses, "light types")
end
AssignLightsToAllWeapons()


--------------------------------------------------------------------------------
-- 3. SF post-pass: customParams honoured by the legacy light_effects widget
--
-- Explosion lights:
--   expl_light_skip          = true    no explosion light at all
--   expl_light_color         = "r g b" (string, space separated)
--   expl_light_radius        = elmos   absolute radius
--   expl_light_radius_mult   = x       multiply auto radius
--   expl_light_opacity       = a       absolute brightness (alpha)
--   expl_light_mult          = x       multiply auto brightness
--   expl_light_life          = frames  absolute lifetime
--   expl_light_life_mult     = x       multiply auto lifetime
--
-- Projectile lights:
--   light_skip               = true
--   light_color              = "r g b"
--   light_radius / light_radius_mult
--   light_opacity / light_mult
--
-- Muzzle flashes:
--   muzzle_light_skip        = true
--   muzzle_light_mult        = x
--------------------------------------------------------------------------------

local function parseColor(str)
	if type(str) ~= "string" then
		return nil
	end
	local r, g, b = str:match("([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)")
	if r and g and b then
		return tonumber(r), tonumber(g), tonumber(b)
	end
	return nil
end

-- Light classes are shared between weapons; copy before mutating.
local function privateCopy(lightTable)
	local c = deepcopy(lightTable)
	c.lightClassName = nil
	c.initComplete = nil
	c.lightParamTable = nil
	return c
end

local function applySFCustomParams()
	for weaponID = 0, #WeaponDefs do
		local weaponDef = WeaponDefs[weaponID]
		local cp = weaponDef.customParams or {}

		-- explosion
		if cp.expl_light_skip then
			explosionLights[weaponID] = nil
		elseif explosionLights[weaponID] then
			local touched = false
			local lt = explosionLights[weaponID]
			local lc
			local function own()
				if not touched then
					lt = privateCopy(lt)
					explosionLights[weaponID] = lt
					lc = lt.lightConfig
					touched = true
				end
			end
			local r, g, b = parseColor(cp.expl_light_color)
			if r then
				own()
				lc.r, lc.g, lc.b = r, g, b
				lc.color2r, lc.color2g, lc.color2b = r * 0.6, g * 0.6, b * 0.6
			end
			if cp.expl_light_radius then
				own()
				lc.radius = tonumber(cp.expl_light_radius) or lc.radius
			end
			if cp.expl_light_radius_mult then
				own()
				lc.radius = lc.radius * (tonumber(cp.expl_light_radius_mult) or 1)
			end
			if cp.expl_light_opacity then
				own()
				lc.a = tonumber(cp.expl_light_opacity) or lc.a
			end
			if cp.expl_light_mult then
				own()
				lc.a = lc.a * (tonumber(cp.expl_light_mult) or 1)
			end
			if cp.expl_light_life then
				own()
				lc.lifetime = tonumber(cp.expl_light_life) or lc.lifetime
			end
			if cp.expl_light_life_mult then
				own()
				lc.lifetime = lc.lifetime * (tonumber(cp.expl_light_life_mult) or 1)
			end
			if touched then
				lt.yOffset = lc.radius / 5
				if lc.lifetime and lc.lifetime > 0 then
					lc.colortime = 35 / lc.lifetime
				end
			end
		end

		-- projectile
		if cp.light_skip then
			projectileDefLights[weaponID] = nil
		elseif projectileDefLights[weaponID] then
			local touched = false
			local lt = projectileDefLights[weaponID]
			local lc
			local function own()
				if not touched then
					lt = privateCopy(lt)
					projectileDefLights[weaponID] = lt
					lc = lt.lightConfig
					touched = true
				end
			end
			local r, g, b = parseColor(cp.light_color)
			if r then
				own()
				lc.r, lc.g, lc.b = r, g, b
			end
			if cp.light_radius then
				own()
				lc.radius = tonumber(cp.light_radius) or lc.radius
			end
			if cp.light_radius_mult then
				own()
				lc.radius = lc.radius * (tonumber(cp.light_radius_mult) or 1)
			end
			if cp.light_opacity then
				own()
				lc.a = tonumber(cp.light_opacity) or lc.a
			end
			if cp.light_mult then
				own()
				lc.a = lc.a * (tonumber(cp.light_mult) or 1)
			end
		end

		-- muzzle flash
		if cp.muzzle_light_skip then
			muzzleFlashLights[weaponID] = nil
		elseif muzzleFlashLights[weaponID] and cp.muzzle_light_mult then
			local lt = privateCopy(muzzleFlashLights[weaponID])
			lt.lightConfig.a = lt.lightConfig.a * (tonumber(cp.muzzle_light_mult) or 1)
			muzzleFlashLights[weaponID] = lt
		end
	end
end
applySFCustomParams()

--------------------------------------------------------------------------------
-- 4. SF manual overrides, keyed by weapondef name (lowercase, as in WeaponDefNames)
--
-- Each entry is a full light table: { lightType = "point"|"beam"|"cone",
-- yOffset = n, fraction = n, lightConfig = { ... } }. Use GetLightClass() to
-- derive from a base class, e.g.
--
--   explosionLightsNames["lozmortar_shell"] = GetLightClass("Explosion", "Fire", "Medium", { a = 0.8 })
--------------------------------------------------------------------------------

local explosionLightsNames = {}
local muzzleFlashLightsNames = {}
local projectileDefLightsNames = {}

-- (no SF overrides yet)

for name, params in pairs(explosionLightsNames) do
	if WeaponDefNames[name] then
		explosionLights[WeaponDefNames[name].id] = params
	end
end
for name, params in pairs(muzzleFlashLightsNames) do
	if WeaponDefNames[name] then
		muzzleFlashLights[WeaponDefNames[name].id] = params
	end
end
for name, params in pairs(projectileDefLightsNames) do
	if WeaponDefNames[name] then
		projectileDefLights[WeaponDefNames[name].id] = params
	end
end

return {
	muzzleFlashLights = muzzleFlashLights,
	projectileDefLights = projectileDefLights,
	explosionLights = explosionLights,
	gibLight = gibLight,
}
