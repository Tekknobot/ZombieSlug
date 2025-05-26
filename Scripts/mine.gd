# res://Scenes/Items/Mine.gd
extends Area2D

@export var damage: int = 3      # same damage as grenade

const ExplosionScene = preload("res://Scenes/Effects/Explosion.tscn")
@onready var beep_sfx := $BeepSfx as AudioStreamPlayer2D

var _exploded: bool = false

func _ready() -> void:
	# make sure this Area2D will detect bodies
	monitoring = true
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
	if _exploded:
		return

	# only explode if the collider is on the same lane (same z_index)
	if body.is_in_group("Zombie"):
		if body.z_index == z_index:
			_explode()
		return

	# OR if it’s the player and they’re invincible, but still on same lane
	if body.is_in_group("Player") and body.is_invincible and body.z_index == z_index:
		_explode()

func _explode() -> void:
	_exploded = true
	beep_sfx.play()

	# spawn your explosion effect
	var exp = ExplosionScene.instantiate()
	exp.global_position = global_position
	get_tree().get_current_scene().add_child(exp)

	# deal damage to everything overlapping
	for b in get_overlapping_bodies():
		if b.has_method("take_damage"):
			b.take_damage(damage)

	queue_free()
