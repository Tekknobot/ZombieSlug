# Bullet.gd
extends Area2D

@export var speed: float = 200.0
@export var knockback_force: float = 1.0  # tweak as needed
@export var rotation_speed: float = 180.0  # degrees per second
var direction: Vector2 = Vector2.RIGHT

@onready var anim: AnimatedSprite2D          = $AnimatedSprite2D
@onready var colshape: CollisionShape2D      = $CollisionShape2D
@onready var stats: Node                     = Playerstats  # or `as PlayerStats` if you want tighter typing

func _ready() -> void:
	anim.play("fly")
	monitoring      = true
	collision_layer = 1 << 0   # bullet on layer 1
	collision_mask  = 1 << 0   # detect layer 1 (zombies)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	rotation_degrees += rotation_speed * delta

	for body in get_overlapping_bodies():
		if body.is_in_group("Zombie"):
			_on_zombie_hit(body)
			return

func _on_zombie_hit(zombie: Node) -> void:
	monitoring = false
	colshape.disabled = true
	print("✅ Hit zombie:", zombie.name)

	if zombie.has_method("take_damage"):
		# explicitly type `dmg` as int
		var dmg: int = 1 + (stats.level - 1)
		zombie.take_damage(dmg)
		print("Called take_damage on", zombie.name, "for", dmg)

	if zombie is CharacterBody2D:
		var zb := zombie as CharacterBody2D
		zb.global_position += direction.normalized() * knockback_force
		print("Knocked back", zb.name, "by", knockback_force)

	queue_free()
	print("Bullet freed after hit")
