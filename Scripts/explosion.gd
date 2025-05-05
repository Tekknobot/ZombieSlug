extends Area2D

@export var damage: int = 3

func _ready() -> void:
	monitoring = true
	$AnimatedSprite2D.animation = "default"
	$AnimatedSprite2D.play()
	$AnimatedSprite2D.connect("animation_finished", Callable(self, "queue_free"))

	# wait one physics frame so overlaps are registered
	await get_tree().physics_frame
	_deal_damage()

func _deal_damage() -> void:
	var bodies = get_overlapping_bodies()
	print("💥 Explosion overlaps:", bodies.size(), "bodies")
	for body in bodies:
		if body.has_method("take_damage"):
			body.take_damage(damage)
