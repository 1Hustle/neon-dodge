extends Area2D
## The player's ship.
##
## Moves with the keyboard (the custom "move_*" actions defined in
## project.godot: WASD + arrow keys) or by touch-drag on mobile.
##
## The ship is an Area2D on the "player" physics layer so that enemies
## can detect overlapping it. The ship itself never handles collisions;
## it only moves. Main turns movement on and off via start()/deactivate().

## Movement speed in pixels per second.
@export var speed := 450.0

## Half the ship's size, roughly. Used to keep the whole ship on screen.
const EDGE_MARGIN := 28.0

## Size of the playable area, cached in _ready().
var screen_size := Vector2.ZERO

## False on the start / game-over screens so stray input (including the
## tap on the Start button itself) cannot move a hidden ship.
var active := false

## Touch-drag state: while a finger is down we steer toward the last
## touched position instead of reading the keyboard.
var _touch_active := false
var _touch_position := Vector2.ZERO


func _ready() -> void:
	screen_size = get_viewport_rect().size


func _input(event: InputEvent) -> void:
	# Touch input. A mouse drag also produces these events because
	# "emulate touch from mouse" is enabled in the project settings,
	# which makes the same code path testable on a desktop.
	# event.position is in viewport coordinates, which match world
	# coordinates here because there is no camera transform.
	if event is InputEventScreenTouch:
		_touch_active = event.pressed
		_touch_position = event.position
	elif event is InputEventScreenDrag:
		_touch_position = event.position


func _process(delta: float) -> void:
	if not active:
		return

	var velocity := Vector2.ZERO
	if _touch_active:
		# Steer toward the finger. Stop when we are (nearly) on top of
		# it so the ship does not jitter around the touch point.
		var to_touch := _touch_position - position
		if to_touch.length() > 8.0:
			velocity = to_touch.normalized() * speed
	else:
		# get_vector() returns a normalized direction built from the
		# four movement actions (diagonals are not faster than straights).
		velocity = Input.get_vector("move_left", "move_right", "move_up", "move_down") * speed

	position += velocity * delta

	# Never let the ship leave the screen.
	position.x = clamp(position.x, EDGE_MARGIN, screen_size.x - EDGE_MARGIN)
	position.y = clamp(position.y, EDGE_MARGIN, screen_size.y - EDGE_MARGIN)


## Places the ship at pos, shows it and enables its controls.
## Called by Main when a run starts.
func start(pos: Vector2) -> void:
	position = pos
	_touch_active = false
	active = true
	show()


## Hides the ship and disables its controls (menus, game over).
func deactivate() -> void:
	active = false
	_touch_active = false
	hide()
