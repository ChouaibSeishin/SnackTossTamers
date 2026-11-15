-- Plain-Lua tests for shared pure-logic modules (no Roblox APIs needed).
--
-- Run from the project root with any Lua 5.3+ interpreter, for example:
--   lua tests/run_tests.lua
-- These tests do NOT replace testing in Roblox Studio. They only check logic
-- that does not depend on the engine (zone lookup, boundaries, markers).

-- Luau has table.freeze; plain Lua does not. Provide a no-op stand-in.
if not table.freeze then
	table.freeze = function(t)
		return t
	end
end

local WorldConfig = dofile("src/ReplicatedStorage/Shared/Config/WorldConfig.luau")

local passed, failed = 0, 0

local function check(name, condition, detail)
	if condition then
		passed = passed + 1
	else
		failed = failed + 1
		print("FAIL: " .. name .. (detail and (" (" .. detail .. ")") or ""))
	end
end

local function zoneIdAt(distance)
	local zone = WorldConfig.getZoneAtDistance(distance)
	return zone and zone.Id or nil
end

-- 1. Configuration is valid and matches GAME_DESIGN.md section 3.
local ok, problems = WorldConfig.validate()
check("config validates", ok, problems and table.concat(problems, "; "))

local expected = {
	{ "Meadow", 0, 60 },
	{ "Forest", 60, 150 },
	{ "Desert", 150, 300 },
	{ "SnowPeaks", 300, 600 },
	{ "Volcano", 600, 1000 },
	{ "DragonsNest", 1000, math.huge },
}
check("six zones", #WorldConfig.Zones == 6, tostring(#WorldConfig.Zones))
for i, e in ipairs(expected) do
	local zone = WorldConfig.Zones[i]
	check("zone " .. i .. " id", zone.Id == e[1], zone.Id)
	check(e[1] .. " min", zone.MinDistance == e[2], tostring(zone.MinDistance))
	check(e[1] .. " max", zone.MaxDistance == e[3], tostring(zone.MaxDistance))
end

-- 2. Boundary behavior: a boundary distance belongs to the zone that starts there.
local cases = {
	{ 0, "Meadow" }, { 30, "Meadow" }, { 59.999, "Meadow" },
	{ 60, "Forest" }, { 149.999, "Forest" },
	{ 150, "Desert" }, { 299.999, "Desert" },
	{ 300, "SnowPeaks" }, { 599.999, "SnowPeaks" },
	{ 600, "Volcano" }, { 999.999, "Volcano" },
	{ 1000, "DragonsNest" }, { 1300, "DragonsNest" }, { 50000, "DragonsNest" },
}
for _, c in ipairs(cases) do
	check("distance " .. c[1] .. " -> " .. c[2], zoneIdAt(c[1]) == c[2], tostring(zoneIdAt(c[1])))
end

-- 3. Invalid distances return nil.
check("negative distance -> nil", zoneIdAt(-0.01) == nil)
check("NaN -> nil", zoneIdAt(0 / 0) == nil)
check("string -> nil", zoneIdAt("100") == nil)
check("nil -> nil", zoneIdAt(nil) == nil)

-- 4. Positions: distance is measured along X only.
check("position distance", WorldConfig.getDistanceAlongField({ X = 84, Y = 3, Z = -20 }) == 84)
local zone = WorldConfig.getZoneAtPosition({ X = 84, Y = 50, Z = 33 })
check("position zone", zone and zone.Id == "Forest")
check("lane inside", WorldConfig.isInLandingLane({ X = 0, Y = 0, Z = 39.9 }) == true)
check("lane outside", WorldConfig.isInLandingLane({ X = 0, Y = 0, Z = -40 }) == false)

-- 5. Markers every 50 studs up to the field end.
local markers = WorldConfig.getMarkerDistances()
check("marker count", #markers == 27, tostring(#markers))
check("first marker", markers[1] == 50)
check("last marker", markers[#markers] == 1350, tostring(markers[#markers]))
for i = 2, #markers do
	check("marker spacing " .. i, markers[i] - markers[i - 1] == 50)
end

-- 6. Lookup helpers.
check("getZoneById", WorldConfig.getZoneById("Volcano").MinDistance == 600)
check("getZoneById unknown", WorldConfig.getZoneById("Moon") == nil)
check("last zone ends at field end",
	WorldConfig.getZoneEndDistance(WorldConfig.Zones[6]) == WorldConfig.Field.Length)
check("max landing inside field", WorldConfig.Field.MaxLandingDistance <= WorldConfig.Field.Length)
check("max landing is Dragon's Nest",
	zoneIdAt(WorldConfig.Field.MaxLandingDistance) == "DragonsNest")

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	os.exit(1)
end
