# 🦄 Unicorn Game

A simple 3D unicorn pet game for kids, built with Godot Engine.

## Download

| Platform | Installer |
|----------|-----------|
| Windows  | [UnicornGame.msi](https://github.com/cooneycw/unicorn-game/releases/latest/download/UnicornGame.msi) |
| macOS    | [UnicornGame.dmg](https://github.com/cooneycw/unicorn-game/releases/latest/download/UnicornGame.dmg) |

> Installers are built automatically when a new version tag is pushed. See [all releases](https://github.com/cooneycw/unicorn-game/releases).

## Game Features

- **Three Islands**: Explore different magical islands
- **Collect Magical Pets**: Find and collect unicorns, pegasus, and dragons
- **Veterinary Clinic**: Simple click-to-heal system for injured pets
- **Pet Stats**: Track health and happiness of your pets
- **No Combat**: Pure exploration and collection gameplay

## How to Play

1. **Hub (Starting Location)**
   - See your pets gathered in the hub area
   - Click "Visit Island" to explore
   - Click "Visit Vet" to heal pets

2. **Island**
   - Explore the island and see all your pets
   - Click on pets to interact with them
   - Return to hub when done

3. **Vet Clinic**
   - Select a pet from the list
   - Click "Heal Selected Pet" to heal them
   - Health increases by 30 points per click
   - Watch their health bar improve!

## Controls

### Keyboard Only - Simple Controls

**Main Menu (Hub)**
- **UP Arrow** - Select "Visit Island"
- **DOWN Arrow** - Select "Visit Vet"
- **SPACE** - Enter selected location
- **Q** - Quick access to Island
- **V** - Quick access to Vet Clinic

**Island**
- **ESC** or **B** - Return to Hub
- View all your pets and their stats

**Vet Clinic**
- **UP Arrow** - Select previous pet
- **DOWN Arrow** - Select next pet
- **H** - Heal the selected pet (+30 health)
- **ESC** or **B** - Return to Hub

### No Mouse Required!
- All controls are keyboard-based
- Perfect for kids who prefer keyboard input
- No clicking, no mouse movements needed

## Running the Game

### Option 1: On Your Local Machine (Recommended)

1. Download [Godot Engine 3.x](https://godotengine.org/download/)
2. Copy the `unicorn_game` folder to your local machine
3. Open Godot and select the project folder
4. Click "Play" or press F5 to run

### Option 2: Headless on Server

```bash
cd unicorn_game
godot3 --path . 2>&1
```

## Project Structure

```
unicorn_game/
├── project.godot          # Godot project configuration
├── default_env.tres       # Environment settings
├── icon.svg               # Game icon
├── scripts/
│   ├── GameManager.gd     # Game state management
│   ├── Pet.gd             # Pet 3D model and properties
│   ├── Main.gd            # Hub scene logic
│   ├── Island.gd          # Island scene logic
│   └── VetClinic.gd       # Vet clinic scene logic
└── scenes/
    ├── GameManager.tscn   # Autoload scene
    ├── Main.tscn          # Hub/main scene
    ├── Island.tscn        # Island scene
    └── VetClinic.tscn     # Vet clinic scene
```

## Customization Ideas

### Add More Pets
Edit `scripts/Main.gd` in `_spawn_starting_pets()`:
```gdscript
var pet_names = ["Sparkle", "Rainbow", "Cloud", "Moonlight"]
var pet_types = ["unicorn", "pegasus", "unicorn", "dragon"]
```

### Change Pet Colors
Edit `scripts/Pet.gd` in `_get_pet_color()`:
```gdscript
func _get_pet_color() -> Color:
    match pet_type:
        "unicorn":
            return Color.WHITE  # Change this color!
        ...
```

### Adjust Healing Amount
Edit `scripts/VetClinic.gd` in `_heal_pet()`:
```gdscript
var success = game_manager.heal_pet(selected_pet_id, 30)  # Change 30 to another number
```

## Requirements

- Godot Engine 3.x or higher
- No additional dependencies

## Tips for Kids

- Try visiting the island to see all your pets!
- If a pet gets hurt, take them to the vet immediately
- Each pet has a unique personality based on their type
- Keep all pets healthy and happy!

---

Made with ❤️ for magical pet lovers! 🦄✨
