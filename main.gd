extends Node
## Neon Dodge — the game controller.
##
## Main owns the game state (score, lives, elapsed time, difficulty)
## and coordinates the three other scenes: it tells the Player where
## to start, spawns Enemies on a timer, and tells the HUD what to
## show. The Player, Enemy and HUD scenes only know about themselves;
## everything that makes this "a game" lives in this one file.

## The enemy scene, instanced once per spawn.
const EnemyScene := preload("res://enemy.tscn")

# --- Difficulty tuning -------------------------------------------------
# A run starts gentle and gets harder the longer the player survives.
# The ramp values below are the whole difficulty curve of the game.
const START_SPAWN_INTERVAL := 1.1 ## Seconds between spawns at t=0.
const MIN_SPAWN_INTERVAL := 0.35 ## Fastest spawn rate allowed.
const SPAWN_RAMP := 0.012 ## Seconds shaved off the interval per second survived.
const START_ENEMY_SPEED := 240.0 ## Enemy fall speed (px/s) at t=0.
const MAX_ENEMY_SPEED := 560.0 ## Fall speed cap (px/s).
const SPEED_RAMP := 4.0 ## Extra px/s of fall speed per second survived.

const SCORE_PER_SECOND := 10.0 ## Points for simply staying alive.
const SCORE_PER_DODGE := 15 ## Bonus when an enemy leaves the screen.
const START_LIVES := 3

var _score := 0.0 # Float, so fractional per-frame time score is not lost.
var _lives := START_LIVES
var _elapsed := 0.0 # Seconds survived in the current run.
var _playing := false

# Untyped on purpose: these are scene roots with their own scripts, and
# GDScript resolves their custom methods (start, show_hud, ...) at
# runtime. Typing them as Area2D / CanvasLayer would hide those methods
# from the compiler and fail.
@onready var _player = $Player
@onready var _hud = $HUD
@onready var _spawn_timer: Timer = $SpawnTimer


func _ready() -> void:
	randomize()
	_hud.start_game.connect(_on_start_game)
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	_hud.show_start()
	_player.deactivate()


func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	_score += SCORE_PER_SECOND * delta
	# Difficulty ramp, part 1: spawn more often as the run goes on.
	# A Timer re-reads wait_time every cycle, so changing it here is
	# enough — no need to stop and restart the timer.
	_spawn_timer.wait_time = maxf(MIN_SPAWN_INTERVAL, START_SPAWN_INTERVAL - _elapsed * SPAWN_RAMP)
	_hud.update_score(int(_score))


## Starts (or restarts) a run. Wired to the HUD's menu button.
func _on_start_game() -> void:
	# Clear any enemies left over from the previous run.
	get_tree().call_group("enemies", "queue_free")
	_score = 0.0
	_lives = START_LIVES
	_elapsed = 0.0
	_playing = true
	_hud.update_score(0)
	_hud.update_lives(_lives)
	_hud.show_hud()
	var screen_size := get_viewport().get_visible_rect().size
	_player.start(Vector2(screen_size.x / 2.0, screen_size.y - 180.0))
	_spawn_timer.start()


func _on_spawn_timer_timeout() -> void:
	# "enemy" is the Enemy scene's root node (see enemy.gd); it is left
	# untyped so its custom properties and signals resolve at runtime.
	var enemy = EnemyScene.instantiate()
	var screen_width := get_viewport().get_visible_rect().size.x
	enemy.position = Vector2(randf_range(40.0, screen_width - 40.0), -40.0)
	# Difficulty ramp, part 2: enemies fall faster the longer the run
	# has lasted, with a little random variation per enemy so spawns
	# do not feel mechanical.
	var base_speed := minf(MAX_ENEMY_SPEED, START_ENEMY_SPEED + _elapsed * SPEED_RAMP)
	enemy.speed = base_speed * randf_range(0.9, 1.15)
	enemy.hit_player.connect(_on_enemy_hit_player)
	enemy.escaped.connect(_on_enemy_escaped)
	add_child(enemy)


## An enemy left the bottom of the screen: the player dodged it.
func _on_enemy_escaped() -> void:
	if _playing:
		_score += SCORE_PER_DODGE


## An enemy touched the player: lose a life, maybe end the run.
func _on_enemy_hit_player() -> void:
	if not _playing:
		return
	_lives -= 1
	_hud.update_lives(_lives)
	if _lives <= 0:
		_game_over()


func _game_over() -> void:
	_playing = false
	_spawn_timer.stop()
	_player.deactivate()
	_hud.show_game_over(int(_score))
