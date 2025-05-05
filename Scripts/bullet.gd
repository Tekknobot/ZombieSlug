extends Area2D

@export var speed: float = 200.0
@export var knockback_force: float = 1.0  # tweak as needed
@export var rotation_speed: float = 180.0  # degrees per second
var direction: Vector2 = Vector2.RIGHT

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var colshape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	anim.play("fly")
	monitoring      = true
	collision_layer = 1 << 0   # bullet on layer 1
	collision_mask  = 1 << 0   # detect layer 1 (zombies)

func _physics_process(delta: float) -> void:
	# Move the bullet
	global_position += direction * speed * delta

	# Rotate the bullet continuously
	rotation_degrees += rotation_speed * delta

	# Check overlaps
	for body in get_overlapping_bodies():
		if body.is_in_group("Zombie"):
			_on_zombie_hit(body)
			return

func _on_zombie_hit(zombie: Node) -> void:
	# Disable further collisions immediately
	monitoring = false
	colshape.disabled = true

	print("✅ Hit zombie:", zombie.name)

	# Call the zombie's take_damage method if available
	if zombie.has_method("take_damage"):
		zombie.take_damage(1)
		print("Called take_damage on", zombie.name)

	# Apply knockback
	if zombie is CharacterBody2D:
		var zb := zombie as CharacterBody2D
		zb.global_position += direction.normalized() * knockback_force
		print("Knocked back", zb.name, "by", knockback_force)

	# Flash red
	if zombie.has_node("AnimatedSprite2D"):
		var spr := zombie.get_node("AnimatedSprite2D") as AnimatedSprite2D
		var original_color: Color = spr.modulate
		spr.modulate = Color(1, 0, 0)
		# wait briefly then restore only if sprite still valid
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(spr):
			spr.modulate = original_color
			print("Restored color for", zombie.name)

	# Destroy bullet
	queue_free()
	print("Bullet freed after hit")
