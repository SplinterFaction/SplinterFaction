
function widget:GetInfo()
	return {
		name      = 'Geovent Spot Highlight',
		desc      = 'Draws yellow column on Geothermal spots',
		author    = 'Niobium, modified by GoogleFrog, heavily modified by Scary',
		version   = '1.0',
		date      = 'Mar, 2011',
		license   = 'GNU GPL, v2 or later',
		layer     = 99999999,
		enabled   = true,  --  loaded by default?
	}
end

----------------------------------------------------------------
-- Globals
----------------------------------------------------------------
local geoDisplayList

----------------------------------------------------------------
-- Speedups
----------------------------------------------------------------
local glLineWidth = gl.LineWidth
local glDepthTest = gl.DepthTest
local glCallList = gl.CallList
local spGetMapDrawMode = Spring.GetMapDrawMode
local spGetActiveCommand = Spring.GetActiveCommand
local spGetGameFrame        = Spring.GetGameFrame


--local geoDefID = UnitDefNames["egeothermal"].id

local mapX = Game.mapSizeX
local mapZ = Game.mapSizeZ
local mapXinv = 1/mapX
local mapZinv = 1/mapZ

local size = math.max(mapX,mapZ) * 60/4096

----------------------------------------------------------------
-- Functions
----------------------------------------------------------------
local function PillarVerts(x, y, z)
	gl.Color(1, 1, 0, 1)
	gl.Vertex(x, y, z)
	gl.Color(1, 1, 0, 0)
	gl.Vertex(x, y + 300, z)
end

local geos = {}

local function HighlightGeos()
	local features = Spring.GetAllFeatures()
	for i = 1, #features do
		local fID = features[i]
		--The following returns false, which is troubling because the featurerulesparam is set and does exist (otherwise the geokiller gadget in luagaia wouldn't work)
		--local customGeo = Spring.GetFeatureRulesParam(fID, "customGeovent")
		--Spring.Echo("[Highlight Geos] The value of the FeatureRulesParam "customGeovent" is: " .. customGeo)
		if FeatureDefs[Spring.GetFeatureDefID(fID)].geoThermal and Spring.GetFeatureRulesParam(fID, "customGeovent") == 1 then -- This isn't going to work until I figure out why I can't seem to get the featurerulesparam
			local fx, fy, fz = Spring.GetFeaturePosition(fID)
			gl.BeginEnd(GL.LINE_STRIP, PillarVerts, fx, fy, fz)
			geos[#geos+1] = {x = fx, z = fz}
		end
	end
end

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------
local drawGeos = false

function widget:Shutdown()
	if geoDisplayList then
		gl.DeleteList(geoDisplayList)
	end
end

function widget:DrawWorld()
	if chobbyInterface then return end
	if Spring.IsGUIHidden() then return end

	local _, cmdID = spGetActiveCommand()
	drawGeos = spGetMapDrawMode() == 'metal' or (WG.GetWidgetOption and WG.GetWidgetOption('Chili Minimap','Settings/Interface/Map','alwaysDisplayMexes').value)
	
	--if drawGeos then
		
		if not geoDisplayList then
			geoDisplayList = gl.CreateList(HighlightGeos)
		end
		
		glLineWidth(2)
		glDepthTest(true)
		glCallList(geoDisplayList)
		glLineWidth(1)
	--end
end