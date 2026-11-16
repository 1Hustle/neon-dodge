# Neon Dodge

A 2D arcade survival game built with **Godot 4.3** and **GDScript**. Pilot a ship at the bottom of the screen, dodge everything that falls, and survive as the game gets faster and less predictable. Three lives, one high score to beat — yours.

## Development and AI assistance

This project was developed by **Opeyemi Peter Adeshina** with AI assistance (code generation, testing harnesses and documentation support). The design decisions, project structure and verification process are documented in this repository, including the automated test suite in `tests/` and the build notes in `BUILD_NOTES.md`. Nothing in this README describes a feature that is not implemented in the code.

## Features

- **Three enemy types**, each with distinct movement:
  - **Drifter** — falls straight down, spinning slowly.
  - **Weaver** — falls while swaying side to side on a sine wave.
  - **Diver** — drifts in, hovers as a warning, then dives at the player's position.
- **Progressive difficulty** — spawn rate and fall speed ramp up with survival time, and the enemy mix shifts toward Weaver and Diver the longer a run lasts.
- **Damage system with invulnerability window** — a hit costs one life and grants 1.5 seconds of blinking immunity, so a single overlap can never drain multiple lives.
- **Scoring** — points for survival time plus a bonus per enemy dodged.
- **Persistent high score** — saved to disk (`user://neon_dodge.cfg`) and shown on the menu and game-over screens, with a "NEW BEST" indicator.
- **Pause and resume** — Esc/P or the on-screen pause button, with a pause menu (Resume / Restart / Main Menu).
- **Smooth, velocity-based movement** — acceleration and braking ramps instead of instant full-speed motion.
- **Keyboard and touch controls** — WASD / arrow keys, or touch-drag on mobile.

## Controls

| Action | Keyboard | Touch |
| --- | --- | --- |
| Move | WASD or arrow keys | Drag |
| Pause / resume | Esc or P | On-screen **II** button |
| Confirm | Enter / mouse | Tap |

## Running the game

You need [Godot 4.3](https://godotengine.org/download/) (the standard build is fine).

1. Clone this repository.
2. Open Godot, choose **Import**, and select the cloned folder's `project.godot`.
3. Press **Play** (F5) — or from a terminal: `godot --path .`

The project targets a 720×1280 portrait play field with `canvas_items` stretch, so it scales to other window sizes.

## Project structure

```
neon-dodge/
├── project.godot            # Engine config: main scene, input actions, physics layers
├── scenes/
│   ├── main.tscn            # Game root: Player + SpawnTimer + HUD
│   ├── player.tscn          # The player's ship (Area2D)
│   ├── hud.tscn             # Score/lives, menus, pause menu
│   └── enemies/
│       ├── drifter.tscn     # Straight-falling enemy
│       ├── weaver.tscn      # Sine-wave enemy
│       └── diver.tscn       # Diving enemy
├── scripts/
│   ├── main.gd              # Game controller: state, spawning, damage rules, high score, pause
│   ├── player.gd            # Movement (keyboard + touch), invulnerability, screen clamp
│   ├── hud.gd               # Display only; forwards button presses as signals
│   └── enemies/
│       ├── enemy_base.gd    # Shared enemy behaviour: signals, despawn, movement hook
│       ├── drifter.gd       # _move(): straight fall + spin
│       ├── weaver.gd        # _move(): fall + sine sway
│       └── diver.gd         # _move(): ENTER → LOCK → DIVE state machine
└── tests/
    ├── sim_test.gd          # Headless simulation test suite (17 checks)
    └── capture_test.gd      # Rendered screenshot harness (menu/gameplay/pause/game over)
```

The architecture rule: **Main owns the rules; every other scene only knows about itself.** Enemies report events (`hit_player`, `escaped`) through signals; the HUD displays state and forwards button presses; the player only moves. All enemy types share `enemy_base.gd` and differ only in an overridden `_move()`.

## Testing

Headless simulation (no display needed) — drives the real game code and prints one PASS/FAIL line per check:

```
godot --headless --editor --quit --path .          # import / script parse check
godot --headless --path . --script res://tests/sim_test.gd
```

Current result: **17/17 checks pass** (run start, lives, spawning, collision cost, invulnerability window, dodge signal, screen clamp, difficulty ramp, high-score record + on-disk persistence, pause freeze + menu, resume, Weaver sway, Diver dive state, movement acceleration, game over). Full details in `BUILD_NOTES.md`.

Rendered evidence: `tests/capture_test.gd` runs the game with rendering under a virtual display (Xvfb) and saves PNG screenshots of the menu, gameplay, pause and game-over states, so the visuals — not just the logic — are verified.

## Known limitations

- **Not yet tested on a physical Android device.** Touch controls use the same code path as the mouse (touch emulation is enabled in the project settings) and are verified logically, but no on-device run has happened yet.
- **No audio yet.** Sound effects and music are planned but not implemented; this README will only list them once they exist.
- Visuals are code-drawn polygon shapes — no sprite art.
- No exported builds (desktop/Android) are attached to this repository yet.

## Licence

MIT — see [LICENSE](LICENSE). All code and assets in this repository are original to the project (visuals are polygon shapes defined in the scene files; no third-party assets are included), so the project is free to license this way. The Godot engine itself is also MIT-licensed and is not redistributed here.
