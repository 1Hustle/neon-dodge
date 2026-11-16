extends Area2D
## Base class for every enemy type in Neon Dodge.
##
## An enemy is an Area2D on the "enemy" physics layer whose collision
## mask only includes the "player" layer, so area_entered can only ever
## fire for the player's ship. An enemy has exactly two ways out of the
## game, and reports both with signals so Main can react without knowing
## anything about enemy internals:
##   * it overlaps the player   -> hit_player
##   * it leaves the play field -> escaped (the player dodged it)
## Either way the enemy frees itself.
##
## Movement is the ONLY thing subclasses change: they override _move().
## Spawning, signalling and despawning live here so all three enemy
## types behave identically at the boundary.

signal hit_player
signal escaped

## Fall speed in pixels per second. Set by Main at spawn time.
var speed := 260.0

## How far past an edge an enemy may travel before it despawns.
const DESPAWN_MARGIN := 48.0

var _screen_size := Vector2.ZERO


func _ready() -> void:
	_screen_size = get_viewport_rect().size
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	_move(delta)
	if position.y > _screen_size.y + DESPAWN_MARGIN \
			or position.x < -DESPAWN_MARGIN * 2.0 \
			or position.x > _screen_size.x + DESPAWN_MARGIN * 2.0:
		escaped.emit()
		queue_free()


## Movement hook. The base behaviour is a straight fall; subclasses
## override this to weave, dive, and so on.
func _move(delta: float) -> void:
	position.y += speed * delta


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		hit_player.emit()
		queue_free()
