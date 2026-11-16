extends SceneTree
## Headless simulation test — a developer tool, not part of the game.
##
## Drives main.tscn directly: starts a run, forces spawns, flies the
## player into an enemy to prove collision -> life loss, checks the
## dodge signal, the screen clamp, the difficulty ramp, and the
## game-over transition. Prints PASS/FAIL lines, then quits.
## Run with: godot --headless --path . --script res://tests/sim_test.gd

var _main: Node
var _step := 0
var _step_time := 0.0
var _failures: Array[String] = []
var _escaped_seen := false
var _escape_armed := false
var _entered := false


func _initialize() -> void:
	var packed := load("res://main.tscn") as PackedScene
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


func _process(delta: float) -> bool:
	_step_time += delta
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
		2: # Dodge: drop an enemy past the bottom edge, expect "escaped".
			if not _escape_armed:
				var e2 = _first_enemy()
				if e2 == null:
					_main._on_spawn_timer_timeout()
					e2 = _first_enemy()
				e2.escaped.connect(func() -> void: _escaped_seen = true)
				e2.position = Vector2(360, 2000)
				_escape_armed = true
			if _escaped_seen:
				_check(true, "enemy leaving screen emits escaped (dodge)")
				_next()
			elif _step_time > 2.0:
				_check(false, "enemy leaving screen emits escaped (dodge)")
				_next()
		3: # The player must stay clamped inside the viewport.
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
		4: # Difficulty ramp: spawn interval shrinks as time survives.
			if not _main._playing:
				_main._on_start_game()
			_main._elapsed = 60.0
			if _step_time > 0.25:
				_check(_main._spawn_timer.wait_time <= 0.39, "spawn interval ramps down (wait_time=%.3f)" % _main._spawn_timer.wait_time)
				_next()
		5: # Losing the last life ends the run.
			if not _entered:
				_entered = true
				if not _main._playing:
					_main._on_start_game()
				# Set exactly once: writing this every frame would undo
				# the fatal hit before the assert could observe it.
				_main._lives = 1
			var e3 = _first_enemy()
			if e3 == null:
				_main._on_spawn_timer_timeout()
				e3 = _first_enemy()
			if e3 != null:
				_main._player.position = e3.position
			if _main._playing == false and _main._lives == 0:
				_check(true, "losing the last life ends the run")
				_next()
			elif _step_time > 3.0:
				_check(false, "losing the last life ends the run")
				_next()
		6:
			if _failures.is_empty():
				print("SIM RESULT: ALL PASS")
			else:
				print("SIM RESULT: ", _failures.size(), " FAILURE(S): ", _failures)
			return true
	return false
