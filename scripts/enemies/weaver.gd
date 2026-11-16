extends "res://scripts/enemies/enemy_base.gd"
## Weaver — falls while swaying side to side on a sine wave.
##
## The sway is centred on the x position Main spawned it at (captured
## in _ready, which runs when Main adds it to the tree — after Main has
## set its position). Because the motion is a sine of elapsed time, it
## is smooth, predictable to read, and impossible to "tunnel" through
## the player between frames the way a random walk could.

## How far the sway reaches to each side, in pixels.
const SWAY_AMPLITUDE := 90.0
## How fast the sway oscillates, in radians per second.
const SWAY_FREQUENCY := 3.0

var _time := 0.0
var _base_x := 0.0


func _ready() -> void:
	super._ready()
	_base_x = position.x


func _move(delta: float) -> void:
	_time += delta
	position.y += speed * delta
	position.x = _base_x + sin(_time * SWAY_FREQUENCY) * SWAY_AMPLITUDE
