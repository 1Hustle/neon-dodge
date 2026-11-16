# Neon Dodge — Build Notes

## Engine

- **Godot 4.3.stable.official** (build 77dcf97d8), Linux x86_64 editor binary, from the official Godot GitHub releases (`4.3-stable`).
- Verified with `--version` → `4.3.stable.official.77dcf97d8`.

## History

- **v1 (2026-11-16):** single enemy type, direct-velocity movement, no pause, no persistence. Verified headless: import clean, 600-frame run clean, simulation 8/8. Published to this repository as the first 12 commits.
- **v2 (2026-11-16):** the restructure and feature pass documented below. v1's gameplay checks were carried into the new suite and extended, not replaced.

## What changed in v2

### Structure
- Scenes moved to `scenes/` (enemies in `scenes/enemies/`), scripts to `scripts/` (enemies in `scripts/enemies/`). All `res://` references, the main-scene path in `project.godot`, and every `preload` were updated. The project imports and runs clean after the move (see Verification).

### Gameplay
- **Enemy types:** the single v1 enemy script became `scripts/enemies/enemy_base.gd` (signals, despawn, physics setup) with three subclasses that override only `_move()`: Drifter (straight fall + spin), Weaver (sine sway around its spawn x), Diver (ENTER → LOCK → DIVE state machine that aims at the player's position when the dive begins — a fixed target, not homing).
- **Spawn mix:** Main picks the type per spawn by survival time: <8s all Drifter; 8–20s Weaver 35%; ≥20s Diver 25% / Weaver 30% / Drifter 45%.
- **Damage:** a hit costs one life and starts a 1.5s invulnerability window on the player (blinking). Main ignores `hit_player` while the window runs, fixing the class of bug where one overlap fires across several physics frames and drains multiple lives.
- **High score:** on game over, a beaten record is written with `ConfigFile` to `user://neon_dodge.cfg` and loaded again at startup; the menu and game-over screens display it.
- **Pause:** Esc/P or the HUD pause button toggles `get_tree().paused` through a single `_set_paused()` in Main. Main and the HUD run with process mode *Always* (so they can unpause and take button presses); the Player, enemies and SpawnTimer are explicitly *Pausable*. The pause menu offers Resume / Restart / Main Menu.
- **Movement:** the player now integrates a velocity that accelerates toward the input's desired velocity at 2800 px/s² (same rate for braking), instead of teleporting to full speed. Touch-drag steering is unchanged in behaviour and shares the same velocity path.

## Verification (2026-11-16)

### 1. Import / script parse — headless
```
godot --headless --editor --quit --path .
```
Exit 0, zero errors, zero warnings.

### 2. Main scene idle run — headless
```
godot --headless --path . --quit-after 600
```
Exit 0, zero errors across 600 frames.

### 3. Simulation suite — headless
```
godot --headless --path . --script res://tests/sim_test.gd
```
**SIM RESULT: ALL PASS — 17/17:**
1. run starts (playing state)
2. run starts with 3 lives
3. spawn creates exactly one enemy
4. enemy collision costs exactly one life
5. second contact during invulnerability costs no life
6. enemy leaving screen emits escaped (dodge)
7. player is clamped to the viewport
8. spawn interval ramps down (wait_time=0.380 at t=60s)
9. game over records a new high score
10. high score persists to disk (user://neon_dodge.cfg)
11. pause engages and shows the pause menu
12. enemies do not move while paused
13. resume unpauses the game
14. weaver falls and sways on a sine wave
15. diver locks on and enters its dive state
16. player accelerates smoothly instead of snapping to full speed (vx=135.1 shortly after input)
17. losing the last life ends the run

The suite deletes any pre-existing save file before it starts, so the persistence checks are deterministic. A 90-second watchdog fails the run rather than hanging if a check stalls.

### 4. Rendered run — virtual display (NOT headless)
```
xvfb-run godot --display-driver x11 --rendering-driver opengl3 --path . --script res://tests/capture_test.gd
```
The game ran with real rendering under Xvfb and saved four screenshots: menu (showing the persisted "Best: 500" from the simulation run — cross-run persistence visible on screen), live gameplay (score ticking, enemies falling, player ship offset by scripted input, pause button visible), the pause menu, and the game-over screen. All four captures reported OK and were visually inspected.

## What this verification does NOT prove

- **Physical-device behaviour.** No Android device has run this build. Touch input is exercised only through the mouse-emulation path (enabled in project settings) and logic checks.
- **Audio.** There is no audio in the game yet.
- **Performance on hardware.** Headless and virtual-display runs say nothing about frame rates on a phone GPU.
