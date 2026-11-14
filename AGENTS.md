# AGENTS.md — Permanent rules for AI coding assistants

These rules apply to every AI assistant working in this repository (Codex, Claude, or others). Read this file and `GAME_DESIGN.md` before making changes.

## 1. Project and source of truth

- `GAME_DESIGN.md` is the source of truth for game design. Do not replace the approved concept. Suggest improvements, but explain them and get approval before changing important design decisions.
- Core loop: Train strength → Throw food → Reach new zones → Attract creatures → Tame creatures → Collect pets → Upgrade.
- Fixed design decisions:
  - Actual food **landing distance** determines the creature zone.
  - **Food quality** (Luck) determines rarity chances, never the zone.
  - Creatures spawn **only after a throw lands**. No free-roaming collectible creatures.
  - Creatures approach the food, eat it, and join the player's collection.
  - Up to **three** equipped creatures follow the player.
  - NPC battles and tournaments come **after** the core loop is complete.

## 2. The user

- New to Roblox Studio and Luau; experienced software engineer (Java, Spring Boot, React, Git, Docker).
- Skip general programming basics. Explain every Roblox-specific concept: what it is, why we need it, how it works, where it fits in Snack Toss Tamers, and how to test it.
- When a step requires Studio, give exact instructions: which tab, button, menu, or Explorer object. Do not assume the user knows where things are.

## 3. Workflow: one phase at a time

Follow the roadmap in `GAME_DESIGN.md` §11. Never implement multiple phases at once. For every phase:

1. Explain the objective in simple language.
2. Explain the Roblox concepts involved.
3. Inspect the existing project before changing anything.
4. Propose the files and structure needed.
5. Implement in small, understandable steps.
6. Explain what each important script does and where it lives in the Studio Explorer.
7. Run the available checks.
8. Give exact manual test steps for Roblox Studio.
9. **Stop and wait for the user's confirmation** before starting the next phase.

End-of-phase report must include: what was implemented, files created/modified, technical explanations, commands executed, test results, remaining issues, manual test instructions, and Git commit information.

Always distinguish clearly between: **code inspected**, **automated checks run**, and **functionality actually tested in Roblox Studio**. Never claim something works in Studio unless it was run there.

## 4. Architecture (partially managed Rojo)

- Scripts and project config live in this repository and sync to Studio with Rojo (`default.project.json`). Tool versions are pinned in `rokit.toml`.
- The world (Workspace, Terrain, models, lighting) lives in the Studio place file. Do not try to manage visual assets through code unless the user asks.
- Rojo-owned locations (files on disk win; Studio edits inside them are overwritten):

  | Local folder | Studio location | Purpose |
  |---|---|---|
  | `src/ReplicatedStorage/Shared/` | `ReplicatedStorage > Shared` | Config ModuleScripts, shared pure logic, types, remotes |
  | `src/ServerScriptService/Server/` | `ServerScriptService > Server` | Server services and game logic |
  | `src/StarterPlayer/StarterPlayerScripts/Client/` | `StarterPlayer > StarterPlayerScripts > Client` | Client UI and controllers |

- File naming: `*.server.luau` = Script, `*.client.luau` = LocalScript, `*.luau` = ModuleScript.
- Add new folders (`Config/`, `Services/`, `Controllers/`, `Remotes/`, `tests/`) only when a phase needs them.
- When adding a new top-level Rojo mapping, update `default.project.json`, `README.md`, and this file together.

## 5. Security: the server is authoritative

- The server decides coins, Strength, training, food purchases and ownership, throws and landing distance, zone selection, rarity rolls, creature rewards, inventory, equipping, selling, battle results, and saving.
- The client may only **request** actions and **display** results. Never accept a reward, rarity, distance, price, or stat value from the client.
- Validate every RemoteEvent/RemoteFunction request on the server: argument types, ranges, ownership, player state, and position where relevant.
- Apply server-side cooldowns and rate limits (e.g. training ≈ 0.3 s, as configured).
- Prefer RemoteEvents over RemoteFunctions for client→server requests; never have the server invoke the client and wait on it.
- Save player data safely with DataStoreService: pcall around calls, retries with backoff, save on leave and periodically, `game:BindToClose` handling, no saving every click or frame.

## 6. Code quality

- Modular, readable Luau. Small modules with clear names.
- Centralize balance values and definitions (food, equipment, zones, creatures, rarities) in config ModuleScripts. No magic numbers scattered across scripts.
- Comments explain intent or non-obvious logic; do not comment every line.
- No unnecessary frameworks or packages. Any new tool or dependency must be proposed and approved first, then pinned in `rokit.toml`.
- No unverified Toolbox models containing scripts. Inspect any third-party asset for scripts before use.
- No monetization, paid random rewards, trading, or Robux features in the initial version.
- Use current official Roblox Creator Hub and Rojo documentation when an API detail is uncertain. Never invent APIs or Rojo settings.

## 7. Git and safety

- Inspect `git status` before changing files. Preserve existing user files and changes.
- Commit at meaningful, tested milestones with descriptive messages.
- Never run destructive commands (`git reset --hard`, `git clean`, force-push, deleting user files, rewriting history) without explaining the consequences and getting approval.
- **Never push** to a remote without the user's approval.
- Never publish the game, change account or experience settings, spend Robux, or perform Roblox account actions without explicit approval.
- Never ask for Roblox passwords, cookies, or private credentials. Never commit secrets.
- Keep `README.md`, `AGENTS.md`, and other docs updated as the architecture evolves.
