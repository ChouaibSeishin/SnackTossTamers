-- SyncCheck (Script, runs on the server)
-- Studio location: ServerScriptService > Server > SyncCheck
--
-- Temporary Phase 0 script. It proves that:
--   1. Rojo syncs server code into ServerScriptService.
--   2. Server code can require a shared ModuleScript from ReplicatedStorage.
-- Remove it once real server services exist (Phase 2).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProjectInfo = require(Shared:WaitForChild("ProjectInfo"))

print(string.format("[%s] SERVER: %s (%s)", ProjectInfo.Name, ProjectInfo.SyncCheckMessage, ProjectInfo.Phase))
