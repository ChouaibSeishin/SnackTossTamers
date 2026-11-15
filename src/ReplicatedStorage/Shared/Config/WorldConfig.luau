-- WorldConfig (ModuleScript)
-- Studio location: ReplicatedStorage > Shared > Config > WorldConfig
--
-- Single source of truth for the world layout and the six zones.
-- Used by:
--   * ServerStorage > Tools > WorldBuilder   (builds the map from these numbers)
--   * Server code (future): landing position -> distance -> zone
--   * Client code: zone/distance display
--
-- COORDINATE SYSTEM (all values are in studs)
--   * The throwing line is the plane X = ThrowLineX (0). Throws travel toward +X.
--   * Throw distance = landingPosition.X - ThrowLineX
--     (horizontal distance along the field, the same thing the distance markers show).
--   * Z is sideways across the field. Z = FieldCenterZ (0) is the field's center line.
--   * Y is up. The top surface of all walkable/landing ground is Y = GroundY (0).
--   * The Town is behind the line, at negative X.
--
-- NOTE: keep this file free of Luau-only syntax (type annotations, `continue`,
-- `+=`) and Roblox types (Vector3, Color3) so tests/run_tests.lua can run it
-- with plain Lua outside Studio. Colors are {R, G, B} with 0-255 values.

local WorldConfig = {}

WorldConfig.ThrowLineX = 0
WorldConfig.GroundY = 0
WorldConfig.FieldCenterZ = 0

WorldConfig.Field = {
	-- Landing ground runs from X = 0 to X = Length.
	Length = 1400,
	-- Future throws will be clamped to this distance so food never lands on
	-- the Dragon's Nest backdrop (the nest and cliffs sit beyond it).
	MaxLandingDistance = 1300,
	-- Full field width (Z from -Width/2 to +Width/2) inside the boundary walls.
	Width = 240,
	-- |Z| < LaneHalfWidth is the landing lane. Nothing collidable or
	-- raycast-visible may be placed in it except the landing ground itself.
	LaneHalfWidth = 40,
	GroundThickness = 4,
}

WorldConfig.Town = {
	-- Town ground runs from X = -Length to X = 0.
	Length = 180,
}

-- A distance marker every N studs (50, 100, 150, ...).
WorldConfig.DistanceMarkerInterval = 50

-- Zones are ordered and contiguous. A distance d belongs to a zone when
-- MinDistance <= d < MaxDistance. Boundaries follow GAME_DESIGN.md section 3.
-- Material values are Enum.Material names.
WorldConfig.Zones = {
	{
		Id = "Meadow",
		DisplayName = "Meadow",
		MinDistance = 0,
		MaxDistance = 60,
		GroundColor = { 124, 214, 96 },
		LaneColor = { 150, 228, 112 },
		AccentColor = { 255, 206, 72 },
		GroundMaterial = "SmoothPlastic",
	},
	{
		Id = "Forest",
		DisplayName = "Forest",
		MinDistance = 60,
		MaxDistance = 150,
		GroundColor = { 58, 150, 72 },
		LaneColor = { 82, 170, 88 },
		AccentColor = { 156, 102, 60 },
		GroundMaterial = "SmoothPlastic",
	},
	{
		Id = "Desert",
		DisplayName = "Desert",
		MinDistance = 150,
		MaxDistance = 300,
		GroundColor = { 234, 196, 124 },
		LaneColor = { 244, 214, 152 },
		AccentColor = { 232, 120, 56 },
		GroundMaterial = "Sand",
	},
	{
		Id = "SnowPeaks",
		DisplayName = "Snow Peaks",
		MinDistance = 300,
		MaxDistance = 600,
		GroundColor = { 236, 244, 252 },
		LaneColor = { 206, 230, 248 },
		AccentColor = { 84, 170, 236 },
		GroundMaterial = "Snow",
	},
	{
		Id = "Volcano",
		DisplayName = "Volcano",
		MinDistance = 600,
		MaxDistance = 1000,
		GroundColor = { 70, 60, 64 },
		LaneColor = { 96, 80, 82 },
		AccentColor = { 255, 104, 32 },
		GroundMaterial = "Slate",
	},
	{
		Id = "DragonsNest",
		DisplayName = "Dragon's Nest",
		MinDistance = 1000,
		MaxDistance = math.huge,
		GroundColor = { 92, 70, 136 },
		LaneColor = { 116, 90, 162 },
		AccentColor = { 196, 112, 255 },
		GroundMaterial = "Slate",
	},
}

-- Horizontal distance from the throwing line, measured along the field.
-- `position` is a Vector3 (or any table with an X field).
function WorldConfig.getDistanceAlongField(position)
	return position.X - WorldConfig.ThrowLineX
end

-- Returns the zone table for a distance, or nil when the distance is not a
-- valid landing distance (negative, NaN, or not a number).
function WorldConfig.getZoneAtDistance(distance)
	if type(distance) ~= "number" or distance ~= distance or distance < 0 then
		return nil
	end
	for _, zone in ipairs(WorldConfig.Zones) do
		if distance >= zone.MinDistance and distance < zone.MaxDistance then
			return zone
		end
	end
	return nil
end

function WorldConfig.getZoneAtPosition(position)
	return WorldConfig.getZoneAtDistance(WorldConfig.getDistanceAlongField(position))
end

function WorldConfig.getZoneById(zoneId)
	for _, zone in ipairs(WorldConfig.Zones) do
		if zone.Id == zoneId then
			return zone
		end
	end
	return nil
end

-- Where a zone's ground physically ends (the last zone ends with the field).
function WorldConfig.getZoneEndDistance(zone)
	return math.min(zone.MaxDistance, WorldConfig.Field.Length)
end

-- Distances that get a marker: 50, 100, ... up to (but not including) the field end.
function WorldConfig.getMarkerDistances()
	local distances = {}
	local d = WorldConfig.DistanceMarkerInterval
	while d < WorldConfig.Field.Length do
		distances[#distances + 1] = d
		d = d + WorldConfig.DistanceMarkerInterval
	end
	return distances
end

function WorldConfig.isInLandingLane(position)
	return math.abs(position.Z - WorldConfig.FieldCenterZ) < WorldConfig.Field.LaneHalfWidth
end

-- Checks that the configuration is internally consistent.
-- Returns true, or false plus a list of problems.
function WorldConfig.validate()
	local problems = {}
	local zones = WorldConfig.Zones
	if #zones == 0 then
		problems[#problems + 1] = "no zones defined"
	else
		if zones[1].MinDistance ~= 0 then
			problems[#problems + 1] = "first zone must start at distance 0"
		end
		if zones[#zones].MaxDistance ~= math.huge then
			problems[#problems + 1] = "last zone must be open-ended (MaxDistance = math.huge)"
		end
	end
	local seenIds = {}
	for i, zone in ipairs(zones) do
		if seenIds[zone.Id] then
			problems[#problems + 1] = "duplicate zone id " .. tostring(zone.Id)
		end
		seenIds[zone.Id] = true
		if not (zone.MaxDistance > zone.MinDistance) then
			problems[#problems + 1] = zone.Id .. ": MaxDistance must be greater than MinDistance"
		end
		if i > 1 and zone.MinDistance ~= zones[i - 1].MaxDistance then
			problems[#problems + 1] = zone.Id .. ": must start where " .. zones[i - 1].Id .. " ends (gap or overlap)"
		end
		if zone.MinDistance >= WorldConfig.Field.Length then
			problems[#problems + 1] = zone.Id .. ": starts beyond the end of the field"
		end
	end
	local field = WorldConfig.Field
	if field.MaxLandingDistance > field.Length then
		problems[#problems + 1] = "Field.MaxLandingDistance must not exceed Field.Length"
	end
	if field.LaneHalfWidth * 2 >= field.Width then
		problems[#problems + 1] = "landing lane must be narrower than the field"
	end
	return #problems == 0, problems
end

do
	local ok, problems = WorldConfig.validate()
	if not ok then
		error("WorldConfig is invalid:\n  " .. table.concat(problems, "\n  "))
	end
end

-- Make the configuration read-only so no script can change it at runtime.
for _, zone in ipairs(WorldConfig.Zones) do
	table.freeze(zone.GroundColor)
	table.freeze(zone.LaneColor)
	table.freeze(zone.AccentColor)
	table.freeze(zone)
end
table.freeze(WorldConfig.Zones)
table.freeze(WorldConfig.Field)
table.freeze(WorldConfig.Town)

return table.freeze(WorldConfig)
