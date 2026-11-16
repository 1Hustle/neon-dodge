extends Area2D
## A falling hazard block.
##
## Enemies fall straight down at a speed set by Main when they spawn
## (Main raises it over time as the difficulty ramp). An enemy has two
## ways out of the game, and reports both with signals so Main can
## react without knowing anything about enemy internals:
##   * it overlaps the player  -> hit_player
##   * it leaves the screen    -> escaped (the player dodged it)
## Either way the enemy frees itself.

signal hit_player
signal escaped

## Fall speed in pixels per second. Set by Main at spawn time.
var speed := 260.0

## How far past the bottom edge an enemy may travel before despawning.
const DESPAWN_MARGIN := 48.0

var _screen_height := 0.0


func _ready() -> void:
	_screen_height = get_viewport_rect().size.y
	# area_entered fires when another Area2D starts overlapping us.
	# Our collision mask only includes the "player" layer, so in
	# practice this only ever fires for the player's ship.
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	position.y += speed * delta
	# Spin slowly for a bit of visual life. The collision shape is a
	# diamond (a square rotated 45 degrees), so spinning it does not
	# suddenly grow or shrink the area the player must avoid.
	rotation += delta * 1.2

	if position.y > _screen_height + DESPAWN_MARGIN:
		escaped.emit()
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		hit_player.emit()
		queue_free()
