-- WorldCheck (Script, runs on the server when a game session starts)
-- Studio location: ServerScriptService > Server > WorldCheck
--
-- The map is built in edit mode by ServerStorage > Tools > WorldBuilder and
-- saved in the place file. This script only checks, at startup, that the
-- saved map is present and that every zone in WorldConfig has landing ground.
-- It changes nothing. Future server code (food landing detection) will rely
-- on the same "LandingSurface" tag and "ZoneId" attribute checked here.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared:WaitForChild("Config"):WaitForChild("WorldConfig"))

local WORLD_NAME = "GeneratedWorld"
local LANDING_TAG = "LandingSurface"
local PREFIX = "[Snack Toss Tamers] "

local world = Workspace:FindFirstChild(WORLD_NAME)
if not world then
	warn(PREFIX .. "Workspace." .. WORLD_NAME .. " is missing. Stop the game, then run in the Command Bar: "
		.. "require(game.ServerStorage.Tools.WorldBuilder:Clone()).Build()  and save the place.")
	return
end

local surfaces = CollectionService:GetTagged(LANDING_TAG)
local zonesWithGround = {}
for _, part in ipairs(surfaces) do
	local zoneId = part:GetAttribute("ZoneId")
	if zoneId then
		zonesWithGround[zoneId] = true
	end
end

local missing = {}
for _, zone in ipairs(WorldConfig.Zones) do
	if not zonesWithGround[zone.Id] then
		table.insert(missing, zone.Id)
	end
end

if #missing > 0 then
	warn(PREFIX .. "World check: no landing ground for zone(s) " .. table.concat(missing, ", ")
		.. ". Rebuild the world with WorldBuilder.Build().")
else
	print(string.format("%sWorld OK: %d landing surfaces covering all %d zones", PREFIX, #surfaces,
		#WorldConfig.Zones))
end
