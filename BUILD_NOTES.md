# Neon Dodge — Build Notes

## Engine

- **Godot 4.3.stable.official** (build 77dcf97d8), Linux x86_64 editor binary.
- Downloaded from the official Godot GitHub releases:
  `Godot_v4.3-stable_linux.x86_64.zip` (release `4.3-stable`).
- Binary kept outside the project at `~/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64`.
- Verified with: `Godot_v4.3-stable_linux.x86_64 --version`
  → `4.3.stable.official.77dcf97d8`

## Project layout

| File | Role |
| --- | --- |
| `project.godot` | 720×1280 portrait, GL Compatibility, custom `move_*` input actions (WASD + arrows), physics layers 2=player / 3=enemy, dark clear colour |
| `main.tscn` / `main.gd` | Game controller: state, score, lives (3), enemy spawn Timer, difficulty ramp, game over + restart |
| `player.tscn` / `player.gd` | Player ship (Area2D, cyan Polygon2D): keyboard via `Input.get_vector`, touch-drag steering, viewport clamping |
| `enemy.tscn` / `enemy.gd` | Falling hazard (Area2D, magenta diamond): falls at a Main-set speed, `area_entered` → `hit_player`, off-screen → `escaped`, frees itself either way |
| `hud.tscn` / `hud.gd` | CanvasLayer: Score label, Lives label, centred start / game-over panel with button (signal-driven) |
| `tests/sim_test.gd` | Headless simulation test (developer tool, not part of the game) |

All visuals are coloured `Polygon2D` shapes — no external assets.

## Verification (all run headless on 2026-11-16)

Binary below is abbreviated as `godot`; all commands run from the project root.

### 1. Project import / script parse check

```
godot --headless --editor --quit --path .
```

Result: **exit 0, zero errors, zero warnings.** This parses every
GDScript file and imports every scene; any parse error would print here.

### 2. Main scene runtime check (start screen idle)

```
godot --headless --path . --quit-after 600
```

Result: **exit 0, zero errors, zero warnings** across 600 frames.

### 3. Gameplay simulation test

The start-screen run above cannot exercise gameplay (nobody presses
Start), so a SceneTree script drives the real game code directly —
starting runs, forcing spawns, and flying the player into enemies:

```
godot --headless --path . --script res://tests/sim_test.gd
```

Result: **SIM RESULT: ALL PASS** — 8/8 checks:

1. Run starts (playing state)
2. Run starts with 3 lives
3. Spawn creates exactly one enemy
4. Enemy collision costs exactly one life
5. Enemy leaving the screen emits `escaped` (dodge path)
6. Player is clamped to the viewport
7. Spawn interval ramps down with survival time (wait_time 1.1s → 0.380s at t=60s)
8. Losing the last life ends the run

Note: the first simulation run failed checks 6 and 8 — both were bugs
in the *test script* (it re-applied its own inputs every frame,
overwriting the game state it was trying to observe), not in the game.
The test was fixed to apply each input exactly once; the game code was
not changed.

## Remaining warnings

None. All three verification runs produced no errors and no warnings.

## What headless verification cannot prove

- **Real touch input** on a phone (finger down / drag / release). The
  touch code path uses `InputEventScreenTouch` / `InputEventScreenDrag`
  and is identical to the mouse path when "emulate touch from mouse" is
  on (it is, in `project.godot`), but no physical touch device was
  involved in these tests.
- **Actual keyboard feel** — the `move_*` actions are defined and the
  player code reads them via `Input.get_vector`, but no physical key
  presses were sent during headless runs.
- **Rendering appearance** — headless runs do not draw; polygon shapes,
  colours and HUD layout are as authored in the `.tscn` files but were
  not visually inspected.
- **On-device performance** on the target phone.
