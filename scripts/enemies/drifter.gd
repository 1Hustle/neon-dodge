extends "res://scripts/enemies/enemy_base.gd"
## Drifter — the basic enemy.
##
## Falls straight down at the speed Main gave it, spinning slowly.
## The collision shape is a diamond (a square rotated 45 degrees), so
## the spin does not suddenly grow or shrink the area the player must
## avoid. This is the v1 enemy, kept as the baseline type.


func _move(delta: float) -> void:
	position.y += speed * delta
	rotation += delta * 1.2
