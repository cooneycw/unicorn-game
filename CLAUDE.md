# CLAUDE.md — Unicorn Game

## Build & Release (GitHub Actions)

**All builds happen via GitHub Actions — no local Godot installation is needed.**

### Release Process

1. Commit changes to a feature branch
2. Create PR, review, and merge to `main`
3. Tag the merge commit: `git tag v1.X.0 && git push origin v1.X.0`
4. GitHub Actions automatically builds installers and creates a GitHub Release

### Workflow Files

| Workflow | File | Runner | Output |
|----------|------|--------|--------|
| Windows MSI | `.github/workflows/build-windows.yml` | ubuntu-latest (export) + windows-latest (MSI) | `UnicornGame.msi` |
| macOS DMG | `.github/workflows/build-macos.yml` | macos-latest | `UnicornGame.dmg` |

Both workflows trigger on `v*` tag pushes. They use Godot 4.3-stable headless for export and `softprops/action-gh-release@v2` to attach artifacts to the GitHub Release.

Windows MSI uses WiX Toolset v6.0.2 (desktop + start menu shortcuts). macOS DMG is created via `hdiutil`.

### Checking Build Status

```bash
gh run list --workflow=build-windows.yml --limit=3
gh run list --workflow=build-macos.yml --limit=3
gh run view <run-id>           # detailed status
gh release view v1.X.0         # verify artifacts attached
```

## Project Overview

Godot 4.3 / GDScript 3D pet simulation game. All visuals are procedurally generated from primitive meshes — no external assets or textures.

### Pet Types (6)

unicorn, pegasus, dragon, alicorn, dogicorn, caticorn (displays as "sloth" on macOS)

~20% of pets spawn with a koala rider.

### macOS Differences

- **Player character:** Boy (blue shirt, brown shorts, short hair, green eyes) instead of girl
- **Caticorn → Sloth:** The 6th pet type displays as "sloth" with sloth visuals (round body, eye mask, claws, stubby tail) instead of cat features. Internal type remains "caticorn" for save compatibility.
- **Starter pet:** "Sleepy" (sloth) instead of "Whiskers" (caticorn)
- **Achievement:** "Sloth Lover" instead of "Cat Lover"
- Platform detected at runtime via `GameManager.is_macos()` / `GameManager.display_type()`

### Scenes & Scripts

| Scene | Script | Description |
|-------|--------|-------------|
| `Main.tscn` | `Main.gd` | Hub menu (4 options — game is randomly chosen) |
| `Island.tscn` | `Island.gd` | Main gameplay — pets, weather, WASD camera, interactions |
| `VetClinic.tscn` | `VetClinic.gd` | Heal pets for coins |
| `MiniGame.tscn` | `MiniGame.gd` | Treat-catching (5 levels, auto-advance on score 10+) |
| `MemoryGame.tscn` | `MemoryGame.gd` | Card-matching (5 levels: 2x3 to 4x6, advance on completion) |
| `MathGame.tscn` | `MathGame.gd` | Math challenge (10 levels: add/sub/mul/div/mixed, advance on 8+ correct) |
| `SudokuGame.tscn` | `SudokuGame.gd` | Logic Grid (6 levels: 3x3 and 4x4 Latin squares, advance without hints) |
| `SpellingGame.tscn` | `SpellingGame.gd` | Spelling bee (10 levels: tiny to expert words, advance on 6+ correct) |
| `PetProfile.tscn` | `PetProfile.gd` | Pet inspect screen with 3D model, stats, rename |
| `AdoptionCenter.tscn` | `AdoptionCenter.gd` | Adopt pets to families, Friends Book, postcards |
| `AchievementScreen.tscn` | `AchievementScreen.gd` | Achievement gallery |

### Autoloaded Singletons

| Singleton | Script | Purpose |
|-----------|--------|---------|
| `GameManager` | `GameManager.gd` | Pet state, coins, XP, stat decay, egg hatching, game level progression, adventure journeys |
| `SaveManager` | `SaveManager.gd` | JSON save/load (`user://save_data.json`), CSV export |
| `AudioManager` | `AudioManager.gd` | Procedural audio synthesis (no audio files) |
| `AchievementManager` | `AchievementManager.gd` | 18 achievements tracking |
| `PetPopulationManager` | `PetPopulationManager.gd` | Pet lifecycle states, soft cap (12), dynamic egg intervals |

### Standalone Model Script

`Pet.gd` — builds the 3D mesh for each pet type procedurally (body, head, legs, wings, horns, tails, breed-specific features, koala rider).

## Key Controls

### Hub
UP/DOWN + SPACE to navigate, or hotkeys: Q(Island) V(Vet) G(Random Game) D(Adoption Center) A(Achievements)

### Island
WASD or Arrow keys or Numpad 8/4/2/6 — camera movement, LEFT/RIGHT — select pet, F — feed, P — play, R — rest, E — collect egg, I — inspect pet, X — rename pet, J — open Guild Board (adventure journeys), ESC — back

### Pet Profile
X — rename pet, ESC — back to Island

### Global
M — mute/unmute audio, Ctrl+S — manual save

## Conventions

- All 3D scenes extend `Node3D`; mini-games extend `Node2D`; UI-only screens use `Control`
- No external dependencies or assets — everything is procedural
- Save format version is tracked in `SaveManager.SAVE_VERSION` (currently 4)
- Pet stats floor at 10 for hunger/happiness (never reach 0 from decay)
- Action cooldown of 0.5s on Island prevents input exploits
- Egg inventory max: 3 eggs, 300s hatch timer each
- Mini-games are randomly selected (kids can't choose) — levels auto-advance on good performance
- Completing a mini-game awards an egg (if inventory < 3) plus coins/XP
- If player ESCs from a mini-game without finishing, they must return to that same game (tracked via `pending_game`)
- Game levels persist in `game_levels` dict in GameManager, saved to JSON
- Unicorns have rainbow manes/tails; pegasus have blue manes/tails and pink wings
- Dragons have green bodies and gold heads
- Island sky is light blue, transitions to gray during rain
- Pet lifecycle states: ACTIVE, ON_JOURNEY, ADOPTED, RETIRED, AT_ACADEMY (managed by PetPopulationManager)
- Soft cap of 12 active pets; egg spawn interval increases dynamically with population (7min base + 45s per pet)
- Only ACTIVE pets spawn on Island; non-active pets shown as summary count in Hub
- Adoption Center sends pets to families; adopted pets remain viewable in Friends Book and send postcards
- Kindness Stars currency earned by adopting pets; stored in GameManager alongside coins
- Must have at least 2 active pets to adopt one out (prevents empty island)
- Adventure Journeys: 8 quests (10-45 min real time), pets earn coins/XP while away, send postcards mid-journey
- Guild Board on Island (press J) lets player select quest then assign a pet; "First Explorer" achievement unlocked on first journey
