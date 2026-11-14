-- SyncCheck (LocalScript, runs on each player's device)
-- Studio location: StarterPlayer > StarterPlayerScripts > Client > SyncCheck
--
-- Temporary Phase 0 script. It proves that:
--   1. Rojo syncs client code into StarterPlayerScripts.
--   2. Client code can require the same shared ModuleScript as the server.
-- Remove it once real client controllers exist.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProjectInfo = require(Shared:WaitForChild("ProjectInfo"))

local player = Players.LocalPlayer

print(string.format("[%s] CLIENT (%s): %s", ProjectInfo.Name, player.Name, ProjectInfo.SyncCheckMessage))
