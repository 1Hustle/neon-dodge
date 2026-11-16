extends Node
## Neon Dodge — the game controller.
##
## Main owns the game state (score, lives, elapsed time, difficulty,
## high score, pause) and coordinates the other scenes: it tells the
## Player where to start, spawns Enemies on a timer, applies the
## damage rules, and tells the HUD what to show. The Player, Enemy and
## HUD scenes only know about themselves; everything that makes this
## "a game" lives in this one file.
##
## Main's process mode is set to Always in main.tscn so it can receive
## the pause key while the tree is paused; its _process() returns
## immediately while paused, and the SpawnTimer is explicitly Pausable
## so no enemies spawn during a pause.

## The three enemy scenes. Which one spawns is decided per-spawn by
## _pick_enemy_scene(); all three share scripts/enemies/enemy_base.gd.
const DrifterScene := preload("res://scenes/enemies/drifter.tscn")
const WeaverScene := preload("res://scenes/enemies/weaver.tscn")
const DiverScene := preload("res://scenes/enemies/diver.tscn")

# --- Difficulty tuning -------------------------------------------------
# A run starts gentle and gets harder the longer the player survives.
const START_SPAWN_INTERVAL := 1.1 ## Seconds between spawns at t=0.
const MIN_SPAWN_INTERVAL := 0.35 ## Fastest spawn rate allowed.
const SPAWN_RAMP := 0.012 ## Seconds shaved off the interval per second survived.
const START_ENEMY_SPEED := 240.0 ## Enemy fall speed (px/s) at t=0.
const MAX_ENEMY_SPEED := 560.0 ## Fall speed cap (px/s).
const SPEED_RAMP := 4.0 ## Extra px/s of fall speed per second survived.

const SCORE_PER_SECOND := 10.0 ## Points for simply staying alive.
const SCORE_PER_DODGE := 15 ## Bonus when an enemy leaves the screen.
const START_LIVES := 3

## Seconds of damage immunity after a hit. Without this, one enemy
## overlap can fire on several consecutive physics frames and drain
## multiple lives for a single mistake.
const INVULNERABILITY_TIME := 1.5

## Where the high score is persisted (per-user app data directory).
const SAVE_PATH := "user://neon_dodge.cfg"
const SAVE_SECTION := "records"

var _score := 0.0 # Float, so fractional per-frame time score is not lost.
var _lives := START_LIVES
var _elapsed := 0.0 # Seconds survived in the current run.
var _playing := false
var _high_score := 0
var _new_best := false

# Untyped on purpose: these are scene roots with their own scripts, and
# GDScript resolves their custom methods (start, show_hud, ...) at
# runtime. Typing them as Area2D / CanvasLayer would hide those methods
# from the compiler and fail.
@onready var _player = $Player
@onready var _hud = $HUD
@onready var _spawn_timer: Timer = $SpawnTimer


func _ready() -> void:
	randomize()
	_load_high_score()
	_hud.start_game.connect(_on_start_game)
	_hud.resume_game.connect(func() -> void: _set_paused(false))
	_hud.restart_game.connect(_on_restart_from_pause)
	_hud.quit_to_menu.connect(_on_quit_to_menu)
	_hud.pause_request.connect(_on_pause_request)
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	_hud.show_start(_high_score)
	_player.deactivate()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") and _playing:
		_set_paused(not get_tree().paused)


func _process(delta: float) -> void:
	if not _playing or get_tree().paused:
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
	_set_paused(false)
	# Clear any enemies left over from the previous run.
	get_tree().call_group("enemies", "queue_free")
	_score = 0.0
	_lives = START_LIVES
	_elapsed = 0.0
	_new_best = false
	_playing = true
	_hud.update_score(0)
	_hud.update_lives(_lives)
	_hud.show_hud()
	var screen_size := get_viewport().get_visible_rect().size
	_player.start(Vector2(screen_size.x / 2.0, screen_size.y - 180.0))
	_spawn_timer.start()


func _on_restart_from_pause() -> void:
	_on_start_game()


func _on_quit_to_menu() -> void:
	_set_paused(false)
	_playing = false
	_spawn_timer.stop()
	get_tree().call_group("enemies", "queue_free")
	_player.deactivate()
	_hud.show_start(_high_score)


func _on_pause_request() -> void:
	if _playing:
		_set_paused(not get_tree().paused)


## The single place pause state changes, so the tree and the HUD's
## pause menu can never disagree.
func _set_paused(value: bool) -> void:
	get_tree().paused = value
	_hud.show_pause(value)


## Chooses which enemy type spawns, by survival time. Early game is
## all Drifters; Weavers join at 8s; Divers at 20s, and both keep
## gaining share. The mix IS the second half of the difficulty curve:
## not just faster enemies, but less predictable ones.
func _pick_enemy_scene() -> PackedScene:
	var roll := randf()
	if _elapsed < 8.0:
		return DrifterScene
	if _elapsed < 20.0:
		return WeaverScene if roll < 0.35 else DrifterScene
	if roll < 0.25:
		return DiverScene
	return WeaverScene if roll < 0.55 else DrifterScene


func _on_spawn_timer_timeout() -> void:
	# "enemy" is the spawned scene's root node; it is left untyped so
	# its custom properties and signals resolve at runtime.
	var enemy = _pick_enemy_scene().instantiate()
	var screen_width := get_viewport().get_visible_rect().size.x
	enemy.position = Vector2(randf_range(60.0, screen_width - 60.0), -40.0)
	# Difficulty ramp, part 2: enemies fall faster the longer the run
	# has lasted, with a little random variation per enemy so spawns
	# do not feel mechanical.
	var base_speed := minf(MAX_ENEMY_SPEED, START_ENEMY_SPEED + _elapsed * SPEED_RAMP)
	enemy.speed = base_speed * randf_range(0.9, 1.15)
	enemy.hit_player.connect(_on_enemy_hit_player)
	enemy.escaped.connect(_on_enemy_escaped)
	add_child(enemy)


## An enemy left the play field: the player dodged it.
func _on_enemy_escaped() -> void:
	if _playing:
		_score += SCORE_PER_DODGE


## An enemy touched the player: apply the damage rules.
##
## The enemy has already freed itself (see enemy_base.gd), so this
## function only decides the cost. During the invulnerability window
## the cost is zero — the overlap is real, but it is the SAME mistake
## still passing through the ship, not a new one.
func _on_enemy_hit_player() -> void:
	if not _playing or _player.is_invulnerable():
		return
	_lives -= 1
	_hud.update_lives(_lives)
	if _lives <= 0:
		_game_over()
	else:
		_player.start_invulnerability(INVULNERABILITY_TIME)


func _game_over() -> void:
	_playing = false
	_spawn_timer.stop()
	_player.deactivate()
	var final_score := int(_score)
	if final_score > _high_score:
		_high_score = final_score
		_new_best = true
		_save_high_score()
	_hud.show_game_over(final_score, _high_score, _new_best)


## --- High-score persistence -------------------------------------------

func _load_high_score() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		_high_score = int(config.get_value(SAVE_SECTION, "high_score", 0))


func _save_high_score() -> void:
	var config := ConfigFile.new()
	config.set_value(SAVE_SECTION, "high_score", _high_score)
	config.save(SAVE_PATH)
