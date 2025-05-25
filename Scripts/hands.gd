extends Area2D

# --- damage & visuals ---
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
		z_index = body.get_node("AnimatedSprite2D").z_index + 1

		_exploded = true
		beep_sfx.play()
		# freeze the player, then free ourselves
		await _freeze_player(body)
		queue_free()

func _freeze_player(player: Node) -> void:
	# safety check
	if not is_instance_valid(player):
		return

	# play your “hold” anim on the hands
	$AnimatedSprite2D.play("hold")

	# disable the player's processing
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

	# resume hands retract animation
	$AnimatedSprite2D.play("retract")
	await get_tree().create_timer(1).timeout

func _explode() -> void:
	# optional later blast effect
	_exploded = true
	beep_sfx.play()

	var exp = ExplosionScene.instantiate()
	exp.global_position = global_position
	get_tree().get_current_scene().add_child(exp)

	for b in get_overlapping_bodies():
		if b.has_method("take_damage"):
			b.take_damage(damage)

	queue_free()
