extends SceneTree
## Rendered-capture harness — a developer tool, not part of the game.
##
## Unlike sim_test.gd this runs WITH rendering (under a virtual X
## display), drives the real game through its menu, gameplay, pause
## and game-over states, and saves a PNG screenshot of each state as
## visual evidence. Run with:
##   xvfb-run godot --path . --script res://tests/capture_test.gd

const OUT_DIR := "/home/hatch/workspace/godot-qualify/evidence/"

var _main: Node
var _frame := 0


func _initialize() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_main = packed.instantiate()
	root.add_child(_main)


func _capture(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := OUT_DIR + name
	var err := image.save_png(path)
	print("CAPTURE ", name, " -> ", "OK" if err == OK else "ERROR %d" % err)


func _process(_delta: float) -> bool:
	_frame += 1
	match _frame:
		25:
			_capture("shot_menu.png")
		26:
			_main._on_start_game()
			_main._on_spawn_timer_timeout()
			_main._on_spawn_timer_timeout()
			_main._on_spawn_timer_timeout()
		30:
			Input.action_press("move_right")
		55:
			Input.action_release("move_right")
		90:
			_capture("shot_gameplay.png")
		95:
			_main._set_paused(true)
		115:
			_capture("shot_pause.png")
		120:
			_main._set_paused(false)
			_main._game_over()
		145:
			_capture("shot_gameover.png")
			return true
	return false
