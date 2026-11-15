# World and map

How the Snack Toss Tamers map is laid out, how it is built, and how future systems should use it.

## Coordinate system

All distances are in **studs**.

```text
            Town                 |  Meadow | Forest |  Desert  | Snow Peaks | Volcano | Dragon's Nest
  X: -180 ................... 0  |    60   |  150   |   300    |    600     |  1000   ...... 1400
                                 ^
                          Throwing line (X = 0). Throws travel toward +X.
```

| Axis | Meaning |
|---|---|
| **X** | Along the field. `X = 0` is the throwing line. **Throw distance = landing X.** Town is at negative X. |
| **Z** | Sideways across the field. `Z = 0` is the center line. The field is 240 studs wide (`Z = -120 … 120`). |
| **Y** | Up. The top of all ground is `Y = 0`. |

The numbers live in one place: `src/ReplicatedStorage/Shared/Config/WorldConfig.luau` (Studio: `ReplicatedStorage > Shared > Config > WorldConfig`).

## Zones

| Zone | Distance | Landing ground | Look |
|---|---|---|---|
| Meadow | 0–60 | bright green | flowers, bushes, rolling hills |
| Forest | 60–150 | dark green | blocky trees, mushrooms |
| Desert | 150–300 | sand | cacti, sandstone rocks, dunes |
| Snow Peaks | 300–600 | snow | snowy pines, ice crystals, mountain peaks |
| Volcano | 600–1000 | dark slate | volcanoes with smoke, lava pools, dark rocks |
| Dragon's Nest | 1000+ | purple slate | glowing crystals, floating rocks, giant nest, cliffs |

A distance belongs to the zone where `MinDistance <= distance < MaxDistance`, so exactly 60 is Forest. Use `WorldConfig.getZoneAtDistance(d)` or `WorldConfig.getZoneAtPosition(position)`; never re-type the boundaries.

The landing ground ends at `Field.Length = 1400`. `Field.MaxLandingDistance = 1300` is the farthest a throw may land (to be enforced by the throwing code in Phase 4); the nest and cliffs sit beyond it.

## Field layout (cross-section)

```text
 Z: -120   -80                -40          0          40                80    120
     |fence| decorations band |  LANDING LANE (clear) | decorations band |fence|
     |     |  trees, rocks    |  markers' lines only  |                  |     |
                        signs at |Z| = 47 (markers) and 62 (zone names)
```

- **Landing lane** (`|Z| < 40`): nothing collidable or raycast-visible above the ground up to 1300 studs. Food can always land here.
- **Every ground part is a landing surface**: lane and shoulders, all tagged `LandingSurface` with a `ZoneId` attribute.
- **Distance markers** every 50 studs: a white line across the lane and a numbered sign on each side (gold for every 100).
- **Zone boundaries**: a glowing line across the whole field in the zone's color, plus a zone-name sign on each side.
- **Space for creatures (Phase 6)**: the shoulders beside the lane give room for a creature to appear and walk to the food.

## Explorer hierarchy

```text
Workspace
└── GeneratedWorld (Model)             ← rebuilt by WorldBuilder. Do not hand-edit.
    ├── Boundaries                     invisible walls + colored zone fences
    ├── Town (Model)
    │   ├── Ground                     town ground, paths, outer scenery ground
    │   ├── TownSpawn (SpawnLocation)
    │   ├── Gym, FoodMarket, Arena, PetPlaza (Models, placeholders)
    │   ├── ThrowingLine (Model)       Platform, ThrowLine stripe, arrows, arch, LaunchPoint
    │   └── Decor                      welcome arch, lamps, hedges, trees
    └── Field (Model)
        ├── LandingSurfaces            18 ground parts: <ZoneId>_Lane / _LeftShoulder / _RightShoulder
        ├── Markings                   lane edges, zone boundary lines
        ├── DistanceMarkers            Marker_50 … Marker_1350
        ├── ZoneSigns
        ├── ZoneDecor                  one Model per zone
        └── Scenery                    ground outside the walls, end ground
```

Put hand-made additions in **`Workspace > WorldDecor`** (create the Folder yourself). WorldBuilder never touches anything outside `GeneratedWorld`.

## Building and rebuilding the map

The map is generated **in edit mode** by `ServerStorage > Tools > WorldBuilder` and saved in the place file.

1. Stop any playtest. Make sure Rojo is connected so the latest code is in Studio.
2. Open the Command Bar (**View** tab → **Command Bar**, or the **Window** menu in newer Studio layouts).
3. Run:

   ```lua
   require(game.ServerStorage.Tools.WorldBuilder:Clone()).Build()
   ```

4. Read the Output. `Build()` runs `Validate()` at the end and should print `ALL 16 CHECKS PASSED`.
5. Save the place (**File → Save to File** / `Ctrl+S`, and **File → Save to Roblox** if published).

Other commands:

```lua
require(game.ServerStorage.Tools.WorldBuilder:Clone()).Validate()       -- re-check the map
require(game.ServerStorage.Tools.WorldBuilder:Clone()).ApplyLighting()  -- optional bright look (changes Lighting)
```

**Why `:Clone()`?** Studio caches a ModuleScript after the Command Bar requires it once, so edits would be ignored until Studio restarts. Requiring a fresh clone always runs the current code.

**When to rebuild:** after any change to `WorldConfig` or `WorldBuilder`. Rebuilding gives an identical map (fixed random seed) except for what you changed.

## Using the map from future code

- **Distance and zone** (server, Phase 4/6): `WorldConfig.getZoneAtPosition(landingPosition)`.
- **Finding the ground under the food**: raycast down with `RaycastParams` set to `Include` only `Workspace.GeneratedWorld.Field.LandingSurfaces` (or the `LandingSurface` tag). The hit part's `ZoneId` attribute must agree with `getZoneAtPosition`.
- **Launch point**: `GeneratedWorld.Town.ThrowingLine.LaunchPoint` (invisible part; its `LookVector` points down the field).
- **Clamp throws** to `WorldConfig.Field.MaxLandingDistance`.

## Performance notes

- About 900 parts in total, all anchored. Small decorations have collision, raycasting, touch events and shadows turned off.
- No Terrain: flat parts give an exact, predictable landing surface and are cheaper than a 1400-stud strip of terrain voxels.
- `GeneratedWorld` uses `ModelStreamingMode = Persistent`, so far zones stay visible from the Throwing Line even with instance streaming on. If the world grows a lot, switch decoration models to normal streaming and keep only ground and signs persistent.
- Distance marker text stops rendering beyond 800 studs; zone signs always render.

## Checks

| Check | Where | What it covers |
|---|---|---|
| `tests/run_tests.lua` | any Lua 5.3+ (`lua tests/run_tests.lua`) | zone boundaries, lookup functions, marker list |
| `WorldBuilder.Validate()` | Studio Command Bar | real raycasts: gaps, flat ground, zone per distance, clear lane, markers, spawn, throwing line direction, anchoring, template leftovers |
| `WorldCheck` script | runs when you press Play | the saved map exists and every zone has landing ground |
