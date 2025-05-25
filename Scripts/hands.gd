# res://Scenes/Items/hands.gd
extends Area2D

@export var damage: int = 3      # same damage as grenade

const ExplosionScene = preload("res://Scenes/Effects/Explosion.tscn")
@onready var beep_sfx := $HandSfx as AudioStreamPlayer2D

var _exploded: bool = false

func _ready() -> void:
	monitoring = true
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
	if _exploded:
		return

	# only affect the player
	if body.is_in_group("Player"):
		_exploded = true
		beep_sfx.play()
		# freeze the player, then free ourselves
		await _freeze_player(body)
		queue_free()

func _freeze_player(player: Node) -> void:
	# safety check
	if not is_instance_valid(player):
		return

	# grab the player's AnimatedSprite2D (adjust path if yours is named differently)
	$AnimatedSprite2D.play("hold")

	# disable the player's movement & processing
	if player.has_method("set_physics_process"):
		player.set_physics_process(false)
	if player.has_method("set_process"):
		player.set_process(false)

	# wait 2 seconds
	await get_tree().create_timer(2.0).timeout

	# if the player died in the meantime, bail
	if not is_instance_valid(player):
		return

	# re-enable movement
	if player.has_method("set_physics_process"):
		player.set_physics_process(true)
	if player.has_method("set_process"):
		player.set_process(true)

	# resume animation
	$AnimatedSprite2D.play("retract")

func _explode() -> void:
	# kept around if you still want a blast effect later
	_exploded = true
	beep_sfx.play()

	var exp = ExplosionScene.instantiate()
	exp.global_position = global_position
	get_tree().get_current_scene().add_child(exp)

	for b in get_overlapping_bodies():
		if b.has_method("take_damage"):
			b.take_damage(damage)

	queue_free()
