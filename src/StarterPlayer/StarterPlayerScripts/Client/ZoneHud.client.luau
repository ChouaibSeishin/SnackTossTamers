-- ZoneHud (LocalScript, runs on each player's device)
-- Studio location: StarterPlayer > StarterPlayerScripts > Client > ZoneHud
--
-- Shows which zone the player is standing in and how far past the throwing
-- line they are, e.g. "Forest - 87 studs". Display only: the server never
-- trusts this. It uses the same WorldConfig functions that future server code
-- will use to turn a food landing position into a zone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared:WaitForChild("Config"):WaitForChild("WorldConfig"))

local UPDATE_INTERVAL = 0.2 -- seconds; no need to update every frame
local TOWN_COLOR = Color3.fromRGB(60, 60, 76)

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ZoneHud"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Name = "ZoneLabel"
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0, 8)
label.Size = UDim2.fromOffset(320, 40)
label.BackgroundColor3 = TOWN_COLOR
label.BackgroundTransparency = 0.15
label.Font = Enum.Font.FredokaOne
label.TextScaled = true
label.TextColor3 = Color3.new(1, 1, 1)
label.TextStrokeTransparency = 0.4
label.Text = ""
label.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = label

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 4)
padding.PaddingBottom = UDim.new(0, 4)
padding.Parent = label

local function update()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local distance = WorldConfig.getDistanceAlongField(root.Position)
	local zone = WorldConfig.getZoneAtDistance(distance)
	if zone then
		label.Text = string.format("%s - %d studs", zone.DisplayName, math.floor(distance))
		label.BackgroundColor3 = Color3.fromRGB(zone.AccentColor[1], zone.AccentColor[2], zone.AccentColor[3])
	else
		label.Text = "Town"
		label.BackgroundColor3 = TOWN_COLOR
	end
end

while true do
	update()
	task.wait(UPDATE_INTERVAL)
end
