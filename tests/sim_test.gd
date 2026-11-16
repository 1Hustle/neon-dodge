extends SceneTree
## Headless simulation test — a developer tool, not part of the game.
##
## Drives scenes/main.tscn directly: starts runs, forces spawns, flies
## the player into enemies, and checks the game's rules one by one —
## including the v2 systems (invulnerability, high-score persistence,
## pause, the three enemy types, smoothed movement). Prints one
## PASS/FAIL line per check, then a summary, then quits.
## Run with: godot --headless --path . --script res://tests/sim_test.gd

const WeaverScene := preload("res://scenes/enemies/weaver.tscn")
const DiverScene := preload("res://scenes/enemies/diver.tscn")

var _main: Node
var _step := 0
var _step_time := 0.0
var _total_time := 0.0
var _failures: Array[String] = []
var _escaped_seen := false
var _escape_armed := false
var _entered := false
var _tracked_enemy: WeakRef
var _pause_y := 0.0
var _test_enemy: Node


func _initialize() -> void:
	# Deterministic high-score checks: remove any save left behind by
	# an earlier run BEFORE Main loads it in _ready().
	var save_global := ProjectSettings.globalize_path("user://neon_dodge.cfg")
	if FileAccess.file_exists("user://neon_dodge.cfg"):
		DirAccess.remove_absolute(save_global)
	var packed := load("res://scenes/main.tscn") as PackedScene
	_main = packed.instantiate()
	root.add_child(_main)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		_failures.append(label)
		print("FAIL: ", label)


func _first_enemy() -> Node:
	var enemies := get_nodes_in_group("enemies")
	return enemies[0] if enemies.size() > 0 else null


func _next() -> void:
	_step += 1
	_step_time = 0.0
	_entered = false
	_escape_armed = false
	_tracked_enemy = null


func _process(delta: float) -> bool:
	_step_time += delta
	_total_time += delta
	if _total_time > 90.0:
		_check(false, "watchdog: test finished within 90 seconds")
		_print_summary()
		return true
	match _step:
		0: # Start a run and force one spawn.
			if _step_time > 0.2:
				_main._on_start_game()
				_check(_main._playing == true, "run starts (playing state)")
				_check(_main._lives == 3, "run starts with 3 lives")
				_main._on_spawn_timer_timeout()
				_check(get_nodes_in_group("enemies").size() == 1, "spawn creates exactly one enemy")
				_next()
		1: # Fly the player into the enemy until a life is lost.
			var e = _first_enemy()
			if e != null:
				_main._player.position = e.position
			if _main._lives == 2:
				_check(true, "enemy collision costs exactly one life")
				_next()
			elif _step_time > 3.0:
				_check(false, "enemy collision costs exactly one life")
				_next()
		2: # Invulnerability: a second contact inside the 1.5s window
			# must be IGNORED. The enemy still despawns (contact really
			# happened), but no second life is lost.
			if not _escape_armed:
				_main._on_spawn_timer_timeout()
				_tracked_enemy = weakref(_first_enemy())
				_escape_armed = true
			var e2 = _tracked_enemy.get_ref() if _tracked_enemy != null else null
			if e2 != null:
				_main._player.position = e2.position
			if e2 == null and _step_time > 0.3:
				_check(_main._lives == 2, "second contact during invulnerability costs no life")
				_next()
			elif _step_time > 1.2:
				_check(false, "second contact during invulnerability costs no life")
				_next()
		3: # Dodge: drop an enemy past the bottom edge, expect "escaped".
			if not _escape_armed:
				var e3 = _first_enemy()
				if e3 == null:
					_main._on_spawn_timer_timeout()
					e3 = _first_enemy()
				e3.escaped.connect(func() -> void: _escaped_seen = true)
				e3.position = Vector2(360, 2000)
				_escape_armed = true
			if _escaped_seen:
				_check(true, "enemy leaving screen emits escaped (dodge)")
				_next()
			elif _step_time > 2.0:
				_check(false, "enemy leaving screen emits escaped (dodge)")
				_next()
		4: # The player must stay clamped inside the viewport.
			if not _entered:
				_entered = true
				if not _main._playing:
					_main._on_start_game()
				# One single shove far off-screen; the player's own
				# _process must pull it back inside within a frame.
				_main._player.position = Vector2(-9999, 99999)
			if _step_time > 0.25:
				var p: Vector2 = _main._player.position
				_check(p.x >= 28.0 and p.x <= 692.0 and p.y >= 28.0 and p.y <= 1252.0, "player is clamped to the viewport")
				_next()
		5: # Difficulty ramp: spawn interval shrinks as time survives.
			if not _main._playing:
				_main._on_start_game()
			_main._elapsed = 60.0
			if _step_time > 0.25:
				_check(_main._spawn_timer.wait_time <= 0.39, "spawn interval ramps down (wait_time=%.3f)" % _main._spawn_timer.wait_time)
				_next()
		6: # High score: a finished run saves its score, and the value
			# is really on disk afterwards.
			if not _entered:
				_entered = true
				if not _main._playing:
					_main._on_start_game()
				_main._score = 500.0
				_main._game_over()
				_check(_main._high_score == 500 and _main._new_best == true, "game over records a new high score")
				var config := ConfigFile.new()
				var on_disk := -1
				if config.load("user://neon_dodge.cfg") == OK:
					on_disk = int(config.get_value("records", "high_score", -1))
				_check(on_disk == 500, "high score persists to disk (user://neon_dodge.cfg)")
				_next()
		7: # Pause: enemies freeze while the tree is paused, and the
			# pause menu shows; resume unfreezes.
			if not _entered:
				_entered = true
				_main._on_start_game()
				_main._on_spawn_timer_timeout()
				var ep = _first_enemy()
				_pause_y = ep.position.y if ep != null else -1.0
				_main._set_paused(true)
				_check(paused == true and _main._hud._pause_panel.visible == true, "pause engages and shows the pause menu")
			if _step_time > 0.5:
				var ep2 = _first_enemy()
				_check(ep2 != null and absf(ep2.position.y - _pause_y) < 0.01, "enemies do not move while paused")
				_main._set_paused(false)
				_check(paused == false, "resume unpauses the game")
				_next()
		8: # Weaver: falls AND sways sideways off its spawn x.
			if not _entered:
				_entered = true
				_test_enemy = WeaverScene.instantiate()
				_test_enemy.position = Vector2(360, 100)
				_test_enemy.speed = 200.0
				root.add_child(_test_enemy)
			if _step_time > 0.5:
				_check(_test_enemy.position.y > 150.0 and absf(_test_enemy.position.x - 360.0) > 20.0, "weaver falls and sways on a sine wave")
				_test_enemy.queue_free()
				_next()
		9: # Diver: reaches its DIVE state after ENTER + LOCK.
			if not _entered:
				_entered = true
				_test_enemy = DiverScene.instantiate()
				_test_enemy.position = Vector2(360, 40)
				_test_enemy.speed = 240.0
				root.add_child(_test_enemy)
			if _test_enemy._state == 2:
				_check(true, "diver locks on and enters its dive state")
				_test_enemy.queue_free()
				_next()
			elif _step_time > 4.0:
				_check(false, "diver locks on and enters its dive state")
				_test_enemy.queue_free()
				_next()
		10: # Smoothed movement: shortly after input starts, the ship
			# is moving but NOT yet at top speed (acceleration ramp).
			if not _entered:
				_entered = true
				if not _main._playing:
					_main._on_start_game()
				Input.action_press("move_right")
			if _step_time > 0.05:
				var vx: float = _main._player._velocity.x
				_check(vx > 0.0 and vx < _main._player.speed, "player accelerates smoothly instead of snapping to full speed (vx=%.1f)" % vx)
				Input.action_release("move_right")
				_next()
		11: # Losing the last life ends the run.
			if not _entered:
				_entered = true
				if not _main._playing:
					_main._on_start_game()
				# Set exactly once, with the invulnerability window
				# cleared: writing lives every frame would undo the
				# fatal hit before the assert could observe it.
				_main._player._invuln_time = 0.0
				_main._lives = 1
			var e4 = _first_enemy()
			if e4 == null:
				_main._on_spawn_timer_timeout()
				e4 = _first_enemy()
			if e4 != null:
				_main._player.position = e4.position
			if _main._playing == false and _main._lives == 0:
				_check(true, "losing the last life ends the run")
				_next()
			elif _step_time > 3.0:
				_check(false, "losing the last life ends the run")
				_next()
		12:
			_print_summary()
			return true
	return false


func _print_summary() -> void:
	if _failures.is_empty():
		print("SIM RESULT: ALL PASS")
	else:
		print("SIM RESULT: ", _failures.size(), " FAILURE(S): ", _failures)
