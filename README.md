# Snack Toss Tamers

A Roblox simulator: train Strength, throw food across themed zones, attract and tame creatures, collect pets, and upgrade.

**Core loop:** Train strength → Throw food → Reach new zones → Attract creatures → Tame creatures → Collect pets → Upgrade.

- Game design (source of truth): [`GAME_DESIGN.md`](GAME_DESIGN.md)
- Rules for AI coding assistants: [`AGENTS.md`](AGENTS.md)

## Current status

**Phase 0 — Project foundation.** No gameplay systems yet. The only code is a sync-check that proves files reach Roblox Studio.

| Phase | Status |
|---|---|
| 0. Project foundation | In progress — awaiting Studio sync confirmation |
| 1. Map blockout | Not started |

## Toolchain

| Tool | Purpose | Version |
|---|---|---|
| Roblox Studio | World building, playtesting | Latest (auto-updates) |
| [Rokit](https://github.com/rojo-rbx/rokit) | Installs project tools at pinned versions (like a lockfile for CLIs) | — |
| [Rojo](https://rojo.space) | Syncs `src/` files into Studio | `7.7.1`, pinned in `rokit.toml` |
| Rojo Studio plugin | The Studio half of Rojo; must match the CLI version | Installed by `rojo plugin install` |
| Git | Version control | Any recent Git for Windows |

## First-time setup (Windows, PowerShell)

Run these from the project folder (`Documents\RobloxProjects\SnackTossTamers`):

```powershell
rokit install            # downloads the tools listed in rokit.toml (Rojo 7.7.1)
rojo --version           # should print: Rojo 7.7.1
rojo plugin install      # installs the matching Rojo plugin into Roblox Studio
```

Restart Roblox Studio after installing the plugin.

## Daily workflow

1. Open a terminal in the project folder and start the Rojo server:

   ```powershell
   rojo serve
   ```

   Leave this terminal open. It prints the address it listens on (default `localhost:34872`).
2. Open the Snack Toss Tamers place in Roblox Studio.
3. In Studio, open the **Plugins** tab and click **Rojo**, then click **Connect**.
4. Edit `.luau` files in `src/`. Saved changes appear in Studio within a second or two.
5. Playtest in Studio (**Home** tab → **Play**, or `F5`). Check the **Output** window for errors.
6. Commit to Git at meaningful checkpoints.

Stop the server with `Ctrl+C` in its terminal. If you switch Git branches, stop `rojo serve` first and restart it afterwards (Rojo 7.7.1 can crash if a served folder disappears while it runs).

## What Rojo manages vs. what Studio manages

This project uses **partially managed Rojo**.

| Managed by Rojo (files in Git) | Managed in Studio (saved in the place file) |
|---|---|
| Everything under `src/` | Workspace: the map, parts, Terrain |
| Server scripts, client scripts, shared modules | Models, meshes, lighting, sounds, decorations |
| | Any instance not listed in `default.project.json` |

Rojo only owns the three folders below. Everything else in Studio is left alone.

| Local folder | Studio Explorer location | Runs on |
|---|---|---|
| `src/ReplicatedStorage/Shared/` | `ReplicatedStorage > Shared` | Shared code: required by server and client |
| `src/ServerScriptService/Server/` | `ServerScriptService > Server` | Server only |
| `src/StarterPlayer/StarterPlayerScripts/Client/` | `StarterPlayer > StarterPlayerScripts > Client` | Each player's device |

**Important:** inside those three folders, the files on disk win. If you create or edit a script *inside* `Shared`, `Server`, or `Client` directly in Studio, Rojo will overwrite or delete it on the next sync. Always edit those scripts as files. Anything you put elsewhere (for example directly in `ServerScriptService`, outside `Server`) is not touched by Rojo — but avoid that for scripts, so all code stays in Git.

### File naming → Roblox script type

| File name | Becomes in Studio |
|---|---|
| `Name.server.luau` | `Script` (server) |
| `Name.client.luau` | `LocalScript` (client) |
| `Name.luau` | `ModuleScript` |
| A folder | `Folder` |

## Project structure

```text
SnackTossTamers/
├── GAME_DESIGN.md                 Game design (source of truth)
├── AGENTS.md                      Rules for AI assistants
├── README.md                      This file
├── default.project.json           Rojo: which files go where in Studio
├── rokit.toml                     Pinned tool versions (Rojo)
├── .gitignore / .gitattributes
└── src/
    ├── ReplicatedStorage/Shared/
    │   └── ProjectInfo.luau                       (ModuleScript, Phase 0 sync check)
    ├── ServerScriptService/Server/
    │   └── SyncCheck.server.luau                  (Script, Phase 0 sync check)
    └── StarterPlayer/StarterPlayerScripts/Client/
        └── SyncCheck.client.luau                  (LocalScript, Phase 0 sync check)
```

Folders such as `Config/`, `Services/`, `Controllers/`, `Remotes/`, and `tests/` from the design document will be added in the phase that first needs them.

## Checks

Validate that the Rojo project builds (does not touch Studio):

```powershell
rojo build default.project.json -o build/SnackTossTamers.rbxlx
```

`build/` is ignored by Git.

## Backing up the world

Because the map lives in the place file and not in Git:

- Use **File → Save to Roblox** regularly. Roblox keeps a version history for saved places.
- Optionally also keep local copies with **File → Save to File As…** in a `PlaceBackups/` folder inside the project (ignored by Git, so it never bloats the repository).

## Security rules (summary)

- The server decides all important outcomes: coins, Strength, purchases, throws, rarity rolls, creature rewards, inventory, saving.
- Every RemoteEvent request is validated on the server, with cooldowns and rate limits.
- No unverified Toolbox models with scripts. No monetization or paid random rewards in the initial version.

See `AGENTS.md` for the full rules.
