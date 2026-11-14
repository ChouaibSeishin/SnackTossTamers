# Snack Toss Tamers — Game Design & Development Brief

**Document type:** Game design plan + implementation guide  
**Status:** Approved concept for initial development  
**Last updated:** 14 November 2026  
**Platform:** Roblox  
**Working title:** Snack Toss Tamers  
**Other title ideas:** Beast Snack Simulator, Feed the Dragons, Toss & Tame

---

## 1. Game vision

### One-sentence pitch

Train your strength, throw food farther across a series of themed environments, attract and tame increasingly rare creatures, build a team of pets, and eventually compete in creature tournaments.

### Core fantasy

A new player begins weak and can barely throw an apple into the meadow. Through training and upgrades, they gradually reach distant environments. Better food improves the chance of attracting rare creatures. What starts as a small bunny collection can eventually become a team of powerful fantasy creatures and dragons.

### Design pillars

1. **Satisfying throws:** Every throw should be readable, physical, and rewarding. Distance should be obvious.
2. **Visible progression:** Players should see how much farther they can throw and which new environment is within reach.
3. **Exciting creature discoveries:** The creature that comes to eat the food should feel like a small event, especially for rare discoveries.
4. **Collection and identity:** Players should enjoy collecting creatures and showing off their equipped pets.
5. **Long-term goals:** Upgrades, new zones, tournaments, trophies, and eventually rebirths provide reasons to return.

The game is inspired by the general idea of throwing food to attract animals. It must use original names, creature designs, UI, animations, map layouts, sounds, and branding rather than copying another creator's assets or presentation.

---

## 2. Core gameplay loop

The main loop is:

**Train → Choose food → Throw → Attract → Tame → Collect → Battle → Earn rewards → Upgrade**

1. **Train:** The player uses training equipment at the Gym. Each successful training action increases Strength.
2. **Choose food:** The player selects food from their inventory. Food has a Luck multiplier and a cost per throw, except the free starter apple.
3. **Throw:** The player walks to the Throwing Line and launches the selected food. More Strength generally means greater distance.
4. **Attract:** The actual landing distance determines the environment's creature pool. The selected food determines the rarity odds.
5. **Tame:** A creature spawns only after food lands. It approaches the food, eats it, reacts with a friendly effect, and joins the player's collection.
6. **Collect:** The player views, equips, sells, and eventually levels up creatures.
7. **Battle:** In a later release, the player selects a team of three creatures for NPC cups and tournaments.
8. **Upgrade:** Coins are spent on training equipment, food, and collection capacity. Trophies and progression unlock longer-term goals.

### Important agreed design decision: creature spawning

**Creatures do not wander around the zones before a player throws food.** The food throw is the trigger for an encounter.

After the food lands:

- The server determines the landing zone.
- The server rolls the creature rarity and selects a creature from that zone's pool.
- The creature appears at a suitable spawn point and moves or flies toward the food.
- It plays an eating animation, followed by a friendly taming/collection effect.
- The player receives the creature and a clear notification.

The environments can still contain plants, rocks, trees, decorations, ambient particles, and scenery. The absence of free-roaming collectible creatures keeps the food-throwing mechanic central and makes each encounter intentional.

---

## 3. World and map layout

The first map is one long progression route. The Town is at one end, with a large field extending away from the Throwing Line.

### Town

The Town is the spawn and social hub. It contains:

- **Gym:** Training equipment and Strength upgrades.
- **Food Market:** Food purchases and food selection.
- **Arena:** Reserved for creature battles and tournaments in a later release.
- **Throwing Line:** A clearly marked platform facing the field.
- **Creature/inventory area:** A convenient place to open the collection UI and show equipped pets.

### Zones and distance bands

| Zone | Approximate landing distance | Visual theme |
|---|---:|---|
| Meadow | 0–60 studs | Bright grass, flowers, gentle hills |
| Forest | 60–150 studs | Trees, mushrooms, leafy scenery |
| Desert | 150–300 studs | Sand, rocks, cacti, warm colors |
| Snow Peaks | 300–600 studs | Snow, ice, mountain shapes |
| Volcano | 600–1,000 studs | Dark rock, glowing lava details |
| Dragon's Nest | 1,000+ studs | Dramatic cliffs, giant nest, fantasy atmosphere |

Use signs, flags, or floating distance markers at regular intervals (for example, every 50 studs) so players can understand their progress. The exact proportions and boundaries can be adjusted after playtesting.

### World-building approach

Build the first environment using simple Roblox Parts and Terrain. Prioritize readable layout and navigation before detailed decoration. Avoid importing large collections of unverified Toolbox models. Any third-party model must be inspected for unexpected scripts before use.

---

## 4. Strength and throwing

### Throw-distance formula

Starting prototype formula:

```text
Throw distance = 10 + 4 × sqrt(Strength)
```

Add a small random variation (initial target: ±10%) so throws do not all land at exactly the same distance. The server must use the actual simulated landing position to determine the zone.

| Strength | Approximate throw distance | Progress target |
|---:|---:|---|
| 0 | 10 studs | Starting Meadow throws |
| 156 | 60 studs | Forest boundary |
| 1,225 | 150 studs | Desert boundary |
| 5,256 | 300 studs | Snow Peaks boundary |
| 21,756 | 600 studs | Volcano boundary |
| 61,256 | 1,000 studs | Dragon's Nest boundary |

These are initial balancing values, not final promises. Recheck the formula and thresholds in code and in Studio before deciding that a zone is unlocked.

### Throw presentation

The throwing sequence should feel satisfying and easy to understand:

1. A short wind-up or charge animation (visual only at first; do not add complicated charge math yet).
2. A clear character throwing animation.
3. The selected food visibly travels through the air as a projectile.
4. A landing effect appears where it hits the ground.
5. A distance readout displays the result (for example, `You threw 84 studs!`).
6. The player sees which zone received the food.
7. The creature encounter begins.

The food projectile can use a simple Roblox Part or MeshPart in the first prototype. It does not need complex physics or custom models to prove the mechanic.

### Strength training

Players equip or use training equipment from the Gym. Each successful action adds Strength.

| Training item | Strength per action | Prototype price |
|---|---:|---:|
| Tiny Dumbbell | 1 | Free |
| Big Dumbbell | 5 | 500 coins |
| Barbell | 20 | 3,000 coins |
| Tractor Tire | 75 | 15,000 coins |
| Boulder | 250 | 80,000 coins |
| Mountain | 1,000 | 400,000 coins |

Use a short server-checked cooldown between training actions (initial target: about 0.3 seconds). The server must validate the action and award Strength; the client must never be trusted to award its own stats.

---

## 5. Food and Luck

Food is the player's way to influence rarity. **Food quality does not determine the zone; actual landing distance determines the zone.**

| Food | Luck multiplier | Prototype cost per throw |
|---|---:|---:|
| Apple | ×1 | Free, unlimited |
| Bread | ×1.5 | 10 coins |
| Burger | ×2 | 50 coins |
| Steak | ×3 | 250 coins |
| Cake | ×5 | 1,200 coins |
| Golden Cheese | ×10 | 7,500 coins |
| Cosmic Taco | ×25 | 50,000 coins |

Food is consumed when thrown, except the unlimited starter Apple. Purchases should grant a stack of food; exact stack sizes can be set during implementation and tuned during playtesting.

### Rarity tiers and base weights

| Rarity | Visual treatment | Base weight with Apple |
|---|---|---:|
| Common | Gray | 60 |
| Uncommon | Green | 25 |
| Rare | Blue | 10 |
| Epic | Purple | 4 |
| Legendary | Gold | 0.9 |
| Mythic | Rainbow / special | 0.1 |

### Luck calculation

Use a weighted random roll. Common and Uncommon keep their base weights. Multiply the weights for Rare, Epic, Legendary, and Mythic by the selected food's Luck multiplier. Then normalize all weights so the final probabilities total 100%.

```text
Common weight    = 60
Uncommon weight  = 25
Rare weight      = 10 × Luck
Epic weight      = 4 × Luck
Legendary weight = 0.9 × Luck
Mythic weight    = 0.1 × Luck

Total weight = sum of all six weights
Probability for a rarity = (that rarity's weight / Total weight) × 100
```

This approach preserves the Apple odds and makes better food improve the relative chance of higher rarities. The UI should display the calculated probabilities for the selected food, rather than relying on manually typed values. Add automated tests to check that probabilities are valid and total approximately 100%.

---

## 6. Creatures and collection

### Example creature pool by zone

These are initial creative placeholders. Names, silhouettes, colors, animations, and stats should become original game assets.

| Zone | Common | Uncommon | Rare | Epic | Legendary | Mythic |
|---|---|---|---|---|---|---|
| Meadow | Bunny | Duck | Fox | Clover Sprite | Golden Goose | Meadow Unicorn |
| Forest | Squirrel | Deer | Wolf | Treant Cub | Shadow Owl | Forest Spirit Stag |
| Desert | Lizard | Camel | Scorpion King | Sand Serpent | Sphinx Cat | Sun Phoenix |
| Snow Peaks | Penguin | Arctic Fox | Polar Bear | Frost Yeti | Ice Wyvern | Crystal Dragon |
| Volcano | Fire Ant | Magma Toad | Lava Hound | Ember Salamander | Inferno Drake | Volcano Titan |
| Dragon's Nest | Baby Dragon | Dragon Whelp | Storm Dragon | Twin-Head Dragon | Elder Dragon | Ancient Cosmic Dragon |

### Creature encounter sequence

1. Food lands and the server determines the zone.
2. The server selects a rarity using the food's Luck.
3. The server selects a creature of that rarity from the zone's creature list.
4. A creature model spawns at a safe nearby position and approaches the food.
5. It plays an eating animation and a friendly heart/taming effect.
6. The server adds the creature to the player's saved collection.
7. The client displays a discovery card with creature name, rarity, and an image/model preview.

For Legendary and Mythic discoveries, add more dramatic but brief effects and a server-wide announcement. Do not interrupt ordinary gameplay with excessive pop-ups.

### Creature stats for future battles

Keep the first battle system understandable with three main stats and one element:

| Stat | Meaning |
|---|---|
| Health (HP) | How much damage the creature can take |
| Attack | How much damage it deals |
| Speed | Helps determine which creature acts first |
| Element | Fire, Water, or Nature |

Element cycle:

- Fire beats Nature.
- Nature beats Water.
- Water beats Fire.
- An elemental advantage initially gives a 1.5× damage multiplier.

Rarity and zone can influence base stats. Creatures from later zones should generally be stronger than creatures from early zones, while rarity should make a creature more special within its zone.

### Duplicate creatures

Duplicates should have a purpose. In a later collection update, players can feed duplicates to a matching creature to increase its level and slightly improve its stats. Selling duplicates should remain an alternative. Do not implement both systems until the basic collection is reliable.

### Equipped pets

Allow up to three creatures to be equipped. Equipped pets follow the player around the Town and other safe areas.

Polish ideas for later:

- Different walk, hover, or fly movement based on creature type.
- Larger or more noticeable models for higher rarities.
- Subtle glow or particle effects for Legendary and Mythic creatures.
- A simple formation that avoids pets overlapping the player or each other.

Start with one reliable follow system and a small number of simple placeholder models. Expand the visual variety later.

---

## 7. Battles and tournaments — later release

### Battle format

Use automated battles for the first battle implementation. Avoid complex real-time player-controlled combat.

1. Each trainer selects a team of three creatures.
2. The two teams line up facing each other in the Arena.
3. The fastest available creature takes its turn and attacks a random standing opponent.
4. Damage is based on Attack, a small random factor (initial target: 0.85–1.15), and the elemental advantage multiplier if applicable.
5. A creature whose HP reaches zero faints and cannot continue that battle.
6. The team with creatures remaining wins.

The player's strategic role is selecting a strong team with useful stats and elemental matchups.

### NPC Cups

NPC cups should be implemented before live player tournaments so the Arena is useful even when the server has few players.

| Cup | Opponent theme | Prototype prize |
|---|---|---|
| Meadow Cup | Meadow creatures | 200 coins, 1 trophy |
| Forest Cup | Forest creatures | 1,000 coins, 2 trophies |
| Desert Cup | Desert creatures | 5,000 coins, 3 trophies |
| Snow Cup | Snow creatures | 20,000 coins, 5 trophies |
| Volcano Cup | Volcano creatures | 75,000 coins, 8 trophies |
| Dragon Cup | Dragon's Nest creatures | 250,000 coins, 15 trophies, special title |

A cup can consist of three consecutive battles. Win all three to receive the cup prize. These rewards are placeholders and must be playtested.

### Live tournaments — future feature

A later update may run a tournament on a timer, with player sign-ups, an eight-place bracket, NPC fill-ins where needed, visible battles, and a winner reward. A trophy leaderboard can show the top players by trophies.

Do not build live tournaments before saving, collection, and NPC battles are stable.

---

## 8. Coins, shops, and progression economy

### Ways to earn coins

- Throwing food: the initial design proposes a reward based on throw distance (distance ÷ 2).
- Selling duplicate creatures.
- Winning NPC cups and, later, live tournaments.
- Future quests or milestones if the economy needs more variety.

### Ways to spend coins

- Training equipment.
- Food.
- Additional creature storage slots.
- Rebirth requirements or other long-term progression unlocks.

### Economy safeguard

Because Apple is free and unlimited, an unrestricted coin reward on every throw could make repeated throws an easy way to farm coins. Do not implement an unlimited reward loop without testing it. Keep throw rewards server-authoritative and add a configurable reward cooldown, cap, diminishing-return rule, or milestone-based reward. Tournament rewards and meaningful progression should remain important sources of income.

The initial goal is for a meaningful next upgrade to feel reachable after roughly 5–15 minutes of ordinary play. This is only a playtesting target; adjust prices, rewards, and training rates based on actual session results.

### Rebirth — later feature

After reaching a high Strength requirement (initial example: 100,000), a player may rebirth.

- Strength and coins reset.
- Creatures and trophies are kept.
- The player receives a permanent Strength-per-action bonus (initial example: +50%).
- Rebirth count is displayed near the player's name or in the player stats UI.

Rebirth should only be implemented after the early and mid-game economy has been tested.

---

## 9. User interface

The UI should be colorful, readable, and simple enough for a new Roblox player.

| UI area / screen | Main contents |
|---|---|
| Persistent top bar | Coins, Strength, Trophies; rebirth count can be added later |
| Food selector | Available food, quantity, Luck multiplier, and rarity odds |
| Throw prompt | Appears when the player is at the Throwing Line; selected food and throw action |
| Throw feedback | Actual distance, zone reached, and encounter status |
| Creature inventory | Creature grid, rarity filters, Equip, Sell, and later Feed Duplicate |
| Gym shop | Training equipment, Strength per action, and price |
| Food Market | Food item, Luck multiplier, quantity, and price |
| Discovery pop-up | Creature name, rarity, preview, and collection confirmation |
| Battle/team screen | Team selection and cup selection; implement in the later battle phase |

UI requirements:

- Support common desktop screen sizes first, but avoid layouts that cannot adapt to mobile.
- Use clear buttons, readable text, and visible selected states.
- Do not make the player navigate a large number of menus to perform the core loop.
- Keep important values synchronized with server-approved player data.

---

## 10. Technical architecture and development rules

### Platform and language

- Game engine/editor: Roblox Studio.
- Scripting language: Luau.
- Source control: Git.
- File-to-Studio synchronization: Rojo.
- Development assistant: ChatGPT desktop app using Codex with a local project folder, if available in the user's app/account.

### Recommended project-management approach

Use **partially managed Rojo**:

- Luau scripts, configuration, documentation, and project files live in the local folder and are tracked by Git.
- Roblox Studio remains the place to build and edit the world, terrain, models, and other visual assets.
- Rojo synchronizes the code from the local project into the correct Roblox Studio services.
- Keep a saved Roblox place file as a backup. Do not assume Rojo automatically manages every visual asset or every change made in Studio.

This is simpler than trying to represent the entire world and every asset as code from day one.

### Suggested source structure

The exact Rojo structure should be generated and validated during project setup. A reasonable starting organization is:

```text
SnackTossTamers/
├── README.md
├── GAME_DESIGN.md
├── AGENTS.md
├── default.project.json
├── rokit.toml
├── .gitignore
├── src/
│   ├── ReplicatedStorage/
│   │   ├── Shared/
│   │   │   ├── Config/
│   │   │   └── Types/
│   │   └── Remotes/
│   ├── ServerScriptService/
│   │   ├── Services/
│   │   └── ServerBootstrap.server.luau
│   └── StarterPlayer/
│       └── StarterPlayerScripts/
│           └── Controllers/
└── tests/                 # Add lightweight tests when useful
```

Do not create every folder and module immediately if it is not needed. Keep the first implementation small and understandable.

### Server authority and security

The server must decide all important game outcomes:

- Coins and Strength changes.
- Training cooldown and valid training equipment.
- Food ownership, quantity, and purchase costs.
- Throw requests, valid launch position, and actual landing distance.
- Zone selection and rarity rolls.
- Creature awards and inventory capacity.
- Selling, equipping, and future battle results.
- Saving and loading player data.

The client may request an action and display effects, but it must not tell the server what reward, rarity, distance, or stat increase to grant. Validate every RemoteEvent request on the server, including rate limits and player state. Never trust a value just because it came from a LocalScript.

### Data saving

Use Roblox DataStoreService for persistent player data. Save only the data needed to reconstruct a player's progress, such as:

- Coins and Strength.
- Owned food quantities where applicable.
- Creature collection and creature levels.
- Equipped creature IDs.
- Trophies and rebirth count when those systems exist.

Use safe load/save patterns, error handling, and periodic or player-exit saves. Avoid saving on every click or every frame. Test DataStores in a separate test experience and follow Roblox Studio's current API-services testing guidance before enabling them for a published experience.

### Maintainability

- Keep balance values and creature/food definitions in shared configuration ModuleScripts rather than scattering constants across scripts.
- Separate server services from client UI/controllers.
- Use clear names and small modules.
- Add comments when they explain intent or non-obvious logic; do not comment every line.
- Avoid unnecessary frameworks and external packages in the first version.
- Keep dependencies minimal and pin tool versions with the project toolchain file.
- Do not add monetization, trading, paid random rewards, or other complex systems to the initial release.

---

## 11. Development roadmap

Build one working slice at a time. Every phase must be tested in Roblox Studio before moving on. The AI assistant should explain what it changes and should not silently skip Studio setup or playtesting steps.

### Phase 0 — Project foundation

- Create the local project folder and Git repository.
- Set up Rojo and connect it to Roblox Studio.
- Create the initial project configuration and a small, understandable folder structure.
- Add this game-design document and a concise `AGENTS.md` with project rules.
- Confirm that a tiny test Script can sync from the file system into Studio.

**Done when:** Rojo sync works, the project opens in Studio, and a test script runs without errors.

### Phase 1 — Map blockout

- Create the Town, Gym, Food Market, Arena placeholder, Throwing Line, and six distance zones.
- Add visible signs and distance markers.
- Use simple Parts and Terrain; do not spend time on final art yet.

**Done when:** The player can spawn, walk through the Town, reach the Throwing Line, and see the six environments laid out in the correct order.

### Phase 2 — Player stats and saving

- Add Coins and Strength to the player state/UI.
- Add a safe data model and DataStore loading/saving.
- Add test-mode fallbacks and clear error messages.

**Done when:** Stats display correctly and persist across a leave/rejoin test in a properly configured test experience.

### Phase 3 — Training

- Add the free Tiny Dumbbell.
- Add a training action and server-side cooldown.
- Increase Strength on valid use and update the UI.

**Done when:** Training increases Strength exactly as configured, and invalid or overly frequent requests are rejected by the server.

### Phase 4 — Throwing prototype

- Add the Throwing Line interaction.
- Add food selection with the starter Apple.
- Launch a visible food projectile based on Strength.
- Measure actual landing distance and display it.
- Add a simple landing effect and a basic throw reward safeguard.

**Done when:** Greater Strength produces visibly greater throws, distance is measured consistently, and the server determines the result.

### Phase 5 — Shops and food inventory

- Add the Gym shop and Food Market.
- Add configurable prices, quantities, and Luck values.
- Validate purchases and food consumption on the server.

**Done when:** Players can buy equipment and food, and cannot spend coins they do not have or throw food they do not own.

### Phase 6 — Creature encounters and rarity

- Add zone-based creature pools and the weighted rarity calculation.
- Spawn a creature only after food lands.
- Make it approach and eat the food, then join the collection.
- Add common discovery UI and special rare-discovery effects.

**Done when:** Landing distance selects the correct zone, selected food affects rarity odds, and the server awards exactly one valid creature per successful encounter.

### Phase 7 — Inventory and following pets

- Add a collection screen.
- Add equip/unequip and up to three equipped pets.
- Implement a stable follow formation.
- Save the collection and equipped pet IDs.

**Done when:** Players can collect, equip, unequip, and keep their pets after rejoining.

### Phase 8 — Core-loop polish and balance

- Improve throw wind-up, projectile feel, landing effects, creature approach/eating animation, sounds, and UI feedback.
- Test early progression and economy with fresh accounts/test data.
- Adjust rewards and prices so the first upgrades feel achievable.

**Done when:** The complete train–throw–tame–upgrade loop is understandable and enjoyable without battle content.

### Phase 9 — NPC battles

- Add creature battle stats and elements.
- Add team selection for three creatures.
- Implement the automatic battle simulator and a readable Arena presentation.

**Done when:** A player can select a team and complete a battle against an NPC team.

### Phase 10 — NPC cups and trophies

- Add the six themed cups.
- Add three-battle cup progression and prizes.
- Add trophy display and a leaderboard if appropriate.

**Done when:** A player can complete and win the first cup, and trophies persist.

### Phase 11 — Long-term progression

- Add duplicate selling and/or duplicate feeding.
- Add creature storage upgrades.
- Add rebirth only after the economy has been tested.

**Done when:** The systems have clear costs, server validation, save support, and balanced progression.

### Phase 12 — Live tournaments and release polish

- Consider timed player tournaments with NPC fill-ins.
- Add a polished trophy leaderboard and winner presentation.
- Test desktop and mobile layouts, performance, and multiplayer edge cases.
- Prepare a release checklist and publish only after the owner manually approves it.

**Done when:** The experience is stable in multiplayer tests and ready for a controlled public release.

---

## 12. First playable release scope

The first playable release should focus on the main differentiator: throwing food and taming creatures.

### Must have

- Town and the six themed distance zones.
- Strength training.
- Food selection and food purchasing.
- Visible food throwing and distance feedback.
- Server-side zone and rarity selection.
- Creature approach/eating/taming sequence.
- Collection inventory.
- Up to three pets following the player.
- Basic saving and a balanced coin loop.
- Clear UI and enough sound/visual feedback to make the loop satisfying.

### Not required for the first playable release

- Player-versus-player combat.
- Live tournaments.
- Trading or gifting.
- Rebirth.
- Complex quests.
- Large numbers of custom creature models.
- Monetization or paid random rewards.

These can be considered after the core loop is fun and reliable.

---

## 13. Playtesting checklist

Use fresh test data regularly. Test with more than one player before multiplayer release.

- Does a new player understand where to train, buy food, and throw?
- Is the Throwing Line easy to find?
- Does Strength visibly affect throw distance?
- Does the actual landing position determine the zone?
- Does expensive food improve higher-rarity odds without changing the zone?
- Are the displayed rarity odds consistent with the server calculation?
- Does each successful throw create only one encounter and one creature award?
- Can a player exploit RemoteEvents to give themselves Strength, Coins, food, or rare creatures?
- Can free Apple throws be abused to generate unlimited coins?
- Does the inventory remain correct after rejoining?
- Do equipped pets follow without getting stuck or blocking the player?
- Does the UI remain usable at different screen resolutions?
- Are there errors or warnings in Studio's Output window?

---

## 14. Working with the desktop coding assistant

The assistant should act as a patient Roblox/Luau development partner and teacher, not just generate large blocks of code.

Project rules:

1. Read this document and `AGENTS.md` before making changes.
2. Work one roadmap phase at a time. Do not implement the entire game in one pass.
3. Before each phase, explain the goal, files to be created/changed, Roblox concepts involved, and how the player will test the result.
4. Prefer small, working increments over speculative architecture.
5. Use current Roblox Creator Hub documentation when an API detail may have changed. Do not invent Roblox APIs or Rojo settings.
6. Make code changes in the local project and use Rojo to sync scripts into Studio.
7. For tasks requiring Studio UI interaction or visual building, give exact beginner-friendly steps and clearly say what the human must click or inspect.
8. Never claim that something works in Studio unless it was actually run and verified. Distinguish static code checks from in-Studio playtests.
9. After each phase, provide a short summary, changed-file list, commands run, test results, known issues, and manual playtest checklist.
10. Do not begin the next phase until the current phase's acceptance criteria have been checked with the user.
11. Use Git commits at meaningful checkpoints. Never discard user changes or run destructive commands without explaining the consequences and getting approval.
12. Never publish the game, change account settings, spend Robux, or perform account actions without explicit approval.
13. Never ask the user to share their Roblox password, session cookie, or private account credentials.
14. Keep the project beginner-friendly: explain Roblox-specific concepts in simple language and show where each script lives in the Explorer hierarchy.

---

## 15. Official references

Use official documentation as the primary reference for platform behavior and setup:

- Roblox Studio setup: https://create.roblox.com/docs/studio/setup
- Roblox scripting overview: https://create.roblox.com/docs/scripting
- Luau documentation: https://create.roblox.com/docs/luau
- Roblox DataStoreService: https://create.roblox.com/docs/cloud-services/data-stores
- Roblox Rojo workflow: https://create.roblox.com/docs/projects/rojo
- Rojo installation: https://rojo.space/docs/v7/getting-started/installation/
- Rokit toolchain manager: https://github.com/rojo-rbx/rokit
- Git for Windows: https://git-scm.com/install/win
- ChatGPT desktop app: https://learn.chatgpt.com/docs/app
- ChatGPT Work and Codex overview: https://help.openai.com/en/articles/20001275-chatgpt-work-and-codex

**Reminder:** Roblox Studio and the Rojo ecosystem can change. Verify current install instructions and tool versions rather than relying on old copied commands.
