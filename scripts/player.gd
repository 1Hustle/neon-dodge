extends Area2D
## The player's ship.
##
## Moves with the keyboard (the custom "move_*" actions defined in
## project.godot: WASD + arrow keys) or by touch-drag on mobile.
##
## Movement is velocity-based: each frame the ship accelerates toward
## the velocity the input is asking for (or decelerates to a stop when
## there is no input). That acceleration ramp is what makes the ship
## feel smooth instead of snapping instantly to full speed.
##
## The ship is an Area2D on the "player" physics layer so enemies can
## detect overlapping it. The ship never scores or loses lives itself;
## Main owns the rules. Main also drives the damage feedback: after a
## hit it calls start_invulnerability(), and while is_invulnerable()
## is true Main ignores further hits — that is what stops one overlap
## from costing several lives across consecutive physics frames.

## Top movement speed in pixels per second.
@export var speed := 450.0

## How quickly velocity catches up with input, in px/s per second.
## Higher = snappier. Shared by acceleration and braking so stopping
## feels as controlled as starting.
const ACCELERATION := 2800.0

## Half the ship's size, roughly. Used to keep the whole ship on screen.
const EDGE_MARGIN := 28.0

## Size of the playable area, cached in _ready().
var screen_size := Vector2.ZERO

## Current velocity. Movement integrates this, never the raw input.
var _velocity := Vector2.ZERO

## Seconds of damage immunity remaining. Zero means vulnerable.
var _invuln_time := 0.0

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
	if event is InputEventScreenTouch:
		_touch_active = event.pressed
		_touch_position = event.position
	elif event is InputEventScreenDrag:
		_touch_position = event.position


func _process(delta: float) -> void:
	_update_invulnerability(delta)
	if not active:
		return

	# 1. Work out the velocity the input is asking for.
	var desired := Vector2.ZERO
	if _touch_active:
		# Steer toward the finger. Inside a small dead-zone we ask for
		# a stop, so the ship settles instead of jittering on the point.
		var to_touch := _touch_position - position
		if to_touch.length() > 8.0:
			desired = to_touch.normalized() * speed
	else:
		# get_vector() returns a normalized direction built from the
		# four movement actions (diagonals are not faster than straights).
		desired = Input.get_vector("move_left", "move_right", "move_up", "move_down") * speed

	# 2. Accelerate the real velocity toward it, then integrate.
	_velocity = _velocity.move_toward(desired, ACCELERATION * delta)
	position += _velocity * delta

	# 3. Never let the ship leave the screen.
	position.x = clamp(position.x, EDGE_MARGIN, screen_size.x - EDGE_MARGIN)
	position.y = clamp(position.y, EDGE_MARGIN, screen_size.y - EDGE_MARGIN)


## True while the post-hit immunity window is running.
func is_invulnerable() -> bool:
	return _invuln_time > 0.0


## Starts the immunity window and the blink that communicates it.
func start_invulnerability(duration: float) -> void:
	_invuln_time = duration


func _update_invulnerability(delta: float) -> void:
	if _invuln_time <= 0.0:
		return
	_invuln_time -= delta
	if _invuln_time <= 0.0:
		modulate.a = 1.0
	else:
		# Blink at roughly 11 Hz between dim and solid.
		var phase := int(Time.get_ticks_msec() / 90) % 2
		modulate.a = 0.35 if phase == 0 else 1.0


## Places the ship at pos, shows it and enables its controls.
## Called by Main when a run starts.
func start(pos: Vector2) -> void:
	position = pos
	_velocity = Vector2.ZERO
	_touch_active = false
	_invuln_time = 0.0
	modulate.a = 1.0
	active = true
	show()


## Hides the ship and disables its controls (menus, game over).
func deactivate() -> void:
	active = false
	_touch_active = false
	_velocity = Vector2.ZERO
	hide()
