-----------------------------
-----------------------------
--Buildlists for factories

Shared.buildListf1landfac = {
	[[fedak]],
	[[fedstorm]],
	[[fedthud]],
	[[fedcrasher]],
	[[fedbear]],
	[[fedcobra]],
	[[fedavalanche]],
	[[fedphalanx]],
	[[fedgoliath]],
	[[fedjuggernaut]],
	[[fedengineer]],
	[[fedengineer_up1]],
	[[fedengineer_up2]],
	[[fedengineer_up3]],
}

Shared.buildListf2landfac = {
	[[lozflea]],
	[[lozdiamondback]],
	[[lozroach]],
	[[lozscorpion]],
	[[lozreaper]],
	[[lozluger]],
	[[lozpulverizer]],
	[[lozmammoth]],
	[[lozsilverback]],
	[[lozengineer]],
	[[lozengineer_up1]],
	[[lozengineer_up2]],
	[[lozengineer_up3]],
}

-----------------------------
-----------------------------
--Buildlists for mobile builders

Shared.buildListFedt0 = {
	[[f1landfac]],
	[[emetalextractor]],
	[[esolar2]],
	[[estorage]],
	[[eradar2]],
	[[emine]],
	[[elightturret2]],
	[[elaserbattery]],
	[[fedengineer]],
}

Shared.buildListFedt1 = {
	[[f1landfac]],
	[[emetalextractor_up1]],
	[[esolar2]],
	[[egeothermal]],
	[[estorage]],
	[[eradar2]],
	[[eradar2_up1]],
	[[ejammer2]],
	[[ekmar]],
	[[emine]],
	[[elightturret2]],
	[[eheavyturret2]],
	[[elaserbattery]],
	[[eflakturret]],
	[[healstation]],
	[[eshieldgen]],
	[[fedengineer_up1]],
}

Shared.buildListFedt2 = {
	[[f1landfac]],
	[[emetalextractor_up2]],
	[[esolar2]],
	[[egeothermal]],
	[[efusion2]],
	[[megapowerplant]],
	[[estorage]],
	[[eradar2]],
	[[eradar2_up1]],
	[[ejammer2]],
	[[ekmar]],
	[[shieldbattery]],
	[[emine]],
	[[elightturret2]],
	[[eheavyturret2]],
	[[elaserbattery]],
	[[eflakturret]],
	[[eartyturret]],
	[[eartyturretvulcan]],
	-- [[meteorcommand]],
	[[healstation]],
	[[eshieldgen]],
	[[esilo]],
	-- [[esiloplanetcracker]],
	[[fedengineer_up2]],
}

Shared.buildListFedt3 = {
	[[f1landfac]],
	[[emetalextractor_up3]],
	[[esolar2]],
	[[egeothermal]],
	[[efusion2]],
	[[megapowerplant]],
	[[estorage]],
	[[eradar2]],
	[[eradar2_up1]],
	[[ejammer2]],
	[[ekmar]],
	[[shieldbattery]],
	[[emine]],
	[[elightturret2]],
	[[eheavyturret2]],
	[[elaserbattery]],
	[[eflakturret]],
	[[eartyturret]],
	[[eartyturretvulcan]],
	-- [[meteorcommand]],
	[[healstation]],
	[[eshieldgen]],
	[[esilo]],
	-- [[esiloplanetcracker]],
	[[fedanarchid]],
	[[fedengineer_up3]],
}

Shared.fedAirPlantBuildList = {
	[[fedgunship]],
	[[fedbomber]],

}

Shared.buildListLoz = {
}

Shared.buildListLozt0 = {
	[[f2landfac]],
	[[emetalextractor]],
	[[esolar2]],
	[[estorage]],
	[[eradar2]],
	[[emine]],
	[[elightturret2]],
	[[elaserbattery]],
	[[lozengineer]],
}

Shared.buildListLozt1 = {
	[[f2landfac]],
	[[emetalextractor_up1]],
	[[esolar2]],
	[[egeothermal]],
	[[estorage]],
	[[eradar2]],
	[[eradar2_up1]],
	[[ejammer2]],
	[[ekmar]],
	[[emine]],
	[[elightturret2]],
	[[eheavyturret2]],
	[[elaserbattery]],
	[[eflakturret]],
	[[healstation]],
	[[eshieldgen]],
	[[lozengineer_up1]],
}

Shared.buildListLozt2 = {
	[[f2landfac]],
	[[emetalextractor_up2]],
	[[esolar2]],
	[[egeothermal]],
	[[efusion2]],
	[[megapowerplant]],
	[[estorage]],
	[[eradar2]],
	[[eradar2_up1]],
	[[ejammer2]],
	[[ekmar]],
	[[shieldbattery]],
	[[emine]],
	[[elightturret2]],
	[[eheavyturret2]],
	[[elaserbattery]],
	[[eflakturret]],
	[[eartyturret]],
	[[eartyturretvulcan]],
	-- [[meteorcommand]],
	[[healstation]],
	[[eshieldgen]],
	[[esilo]],
	-- [[esiloplanetcracker]],
	[[lozengineer_up2]],

}

Shared.buildListLozt3 = {
	[[f2landfac]],
	[[emetalextractor_up3]],
	[[esolar2]],
	[[egeothermal]],
	[[efusion2]],
	[[megapowerplant]],
	[[estorage]],
	[[eradar2]],
	[[eradar2_up1]],
	[[ejammer2]],
	[[ekmar]],
	[[shieldbattery]],
	[[emine]],
	[[elightturret2]],
	[[eheavyturret2]],
	[[elaserbattery]],
	[[eflakturret]],
	[[eartyturret]],
	[[eartyturretvulcan]],
	-- [[meteorcommand]],
	[[healstation]],
	[[eshieldgen]],
	[[esilo]],
	-- [[esiloplanetcracker]],
	[[lozeurypterid]],
	[[lozengineer_up3]],
}

--[[
Shared.buildListTurret = {}
for i = 1, #Shared.buildList do
	Shared.buildListTurret[i] = Shared.buildList[i]
end
for i = 1, #turrets do
	Shared.buildListTurret[#Shared.buildListTurret + 1] = turrets[i]
end

local factory = {

}

Shared.buildListFactory = {}
for i = 1, #Shared.buildList do
	Shared.buildListFactory[i] = Shared.buildList[i]
end
for i = 1, #factory do
	Shared.buildListFactory[#Shared.buildListFactory + 1] = factory[i]
end
]]--