--!strict
-- ProjectInfo (ModuleScript)
-- Studio location: ReplicatedStorage > Shared > ProjectInfo
--
-- Phase 0 sync-check module. Both the server and the client require this
-- module, which proves that shared code in ReplicatedStorage is reachable
-- from both sides. Edit SyncCheckMessage while Rojo is connected to see
-- live file-to-Studio sync.

local ProjectInfo = {
	Name = "Snack Toss Tamers",
	Phase = "Phase 1 - World and map",
	SyncCheckMessage = "Rojo sync OK",
}

return table.freeze(ProjectInfo)
