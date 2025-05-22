extends Area2D

@export var speed: float = 200.0
@export var knockback_force: float = 1.0
@export var rotation_speed: float = 180.0
var direction: Vector2 = Vector2.RIGHT

@onready var anim: AnimatedSprite2D          		= $AnimatedSprite2D
@onready var colshape: CollisionShape2D      		= $CollisionShape2D
@onready var notifier: VisibleOnScreenNotifier2D  	= $VisibilityNotifier2D
@onready var stats: Node                     		= Playerstats  # or `as PlayerStats`

@export var deflect_speed_multiplier: float = 1.1

func _ready() -> void:
	anim.play("fly")
	monitoring      = true
	collision_layer = 1 << 0
	collision_mask  = 1 << 0

	# free us when we fully leave the screen
	notifier.connect("screen_exited", Callable(self, "_on_screen_exited"))

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	rotation_degrees += rotation_speed * delta

	for body in get_overlapping_bodies():
		if body.is_in_group("Shield") and body.has_method("get_velocity"):
			_reflect_off_shield(body)
			return
		elif body.is_in_group("Zombie"):
			_on_zombie_hit(body)
			return

func _on_screen_exited() -> void:
	queue_free()

func _on_zombie_hit(zombie: Node) -> void:
	monitoring = false
	colshape.disabled = true
	print("✅ Hit zombie:", zombie.name)

	if zombie.has_method("take_damage"):
		# linear curve: level 1→1dmg, 2→2dmg, 3→3dmg, …
		var dmg: int = stats.level
		zombie.take_damage(dmg)
		print("Called take_damage on", zombie.name, "for", dmg)

	if zombie is CharacterBody2D:
		var zb := zombie as CharacterBody2D
		zb.global_position += direction.normalized() * knockback_force
		print("Knocked back", zb.name, "by", knockback_force)

	queue_free()
	print("Bullet freed after hit")

func get_velocity() -> Vector2:
	# Returns the current motion vector of this bullet.
	return direction.normalized() * speed

func set_velocity(new_vel: Vector2) -> void:
	# Sets both the direction and speed from a given Vector2.
	if new_vel.length() == 0:
		direction = Vector2.ZERO
		speed = 0
	else:
		direction = new_vel.normalized()
		speed = new_vel.length()

func _reflect_off_shield(shield_zombie: Node2D) -> void:
	# 1) original velocity
	var vel_in = get_velocity()
	# 2) compute normal from shield to bullet
	var normal = (global_position - shield_zombie.global_position).normalized()
	# 3) reflect and speed up
	var vel_out = vel_in.bounce(normal) * deflect_speed_multiplier
	#    -- or you can use: vel_in.reflect(normal) * deflect_speed_multiplier

	# 4) shove the bullet just outside the shield so it won’t immediately retrigger
	global_position = shield_zombie.global_position + normal * 1

	# 5) apply new motion
	set_velocity(vel_out)
	$ShieldClangSfx.play()
