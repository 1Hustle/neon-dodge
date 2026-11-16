extends "res://scripts/enemies/enemy_base.gd"
## Diver — the hunter enemy. A three-state machine:
##
##   ENTER: drifts down slowly from the top of the screen.
##   LOCK:  hovers briefly once it is inside the play field — this is
##          the player's warning window.
##   DIVE:  locks onto the player's position at that moment and dives
##          straight at it at high speed. The target is a fixed point,
##          not homing: a player who keeps moving can dodge the dive,
##          which is what makes the enemy fair.
##
## The state is an enum + a timer, advanced in _move(). Main only sets
## `speed` (the base fall speed); the dive speed is derived from it.

enum State { ENTER, LOCK, DIVE }

## Seconds spent hovering in LOCK before the dive starts.
const LOCK_TIME := 0.45
## ENTER ends and LOCK begins once the enemy is this far down (px).
const LOCK_DEPTH := 140.0
## Dive speed = base speed * this multiplier.
const DIVE_MULTIPLIER := 2.6

var _state: State = State.ENTER
var _state_time := 0.0
var _dive_velocity := Vector2.ZERO


func _move(delta: float) -> void:
	match _state:
		State.ENTER:
			position.y += speed * 0.45 * delta
			if position.y >= LOCK_DEPTH:
				_state = State.LOCK
				_state_time = 0.0
		State.LOCK:
			_state_time += delta
			if _state_time >= LOCK_TIME:
				_begin_dive()
		State.DIVE:
			position += _dive_velocity * delta


func _begin_dive() -> void:
	# Aim at where the player IS, right now. If the player node is
	# somehow gone, dive at the bottom centre of the screen instead.
	var target := Vector2(_screen_size.x / 2.0, _screen_size.y)
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = (players[0] as Node2D).global_position
	_dive_velocity = (target - position).normalized() * speed * DIVE_MULTIPLIER
	_state = State.DIVE
