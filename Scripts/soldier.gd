extends CharacterBody2D

@export var speed         := 200.0
@export var jump_velocity := -350.0
@export var gravity       := 900.0
@export var max_health    := 10

@onready var anim         := $AnimatedSprite2D
@onready var muzzle_point := $Point      # Position2D child for bullet spawn

const BulletScene = preload("res://Scenes/Sprites/bullet.tscn")

var facing_right: bool = false
var is_attacking:  bool = false
var health:        int  = 0
var is_dead:       bool = false

func _ready() -> void:
	health = max_health
	print("Player health set to", health)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Always apply gravity first
	velocity.y += gravity * delta

	# Handle attack input
	if Input.is_action_just_pressed("attack") and not is_attacking:
		_on_attack()

	# Determine if we can move: either not attacking or we are in the air
	var can_move := not is_attacking or not is_on_floor()

	# Horizontal movement
	var dir: float = 0.0
	if can_move:
		dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		velocity.x = dir * speed
	else:
		velocity.x = 0

	# Update facing when moving
	if dir != 0 and can_move:
		facing_right = dir > 0
		anim.flip_h = facing_right

		var abs_off: float = abs(muzzle_point.position.x)
		if facing_right:
			muzzle_point.position.x = abs_off
		else:
			muzzle_point.position.x = -abs_off

	# Jump input only when allowed
	if can_move and is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	# Move & slide
	self.velocity = velocity
	move_and_slide()

	# Reset vertical velocity on landing
	if is_on_floor() and abs(velocity.y) < 1:
		velocity.y = 0
		self.velocity.y = 0

	# Play move/idle when not attacking
	if not is_attacking:
		if not is_on_floor():
			anim.play("move")
		elif dir != 0:
			anim.play("move")
		else:
			anim.play("default")

func _on_attack() -> void:
	is_attacking = true
	anim.play("attack")
	fire_bullet()

	# Allow air control: if on ground, wait briefly; if in air, wait until landing
	if is_on_floor():
		await get_tree().create_timer(0.1).timeout
	else:
		await _await_landing()

	is_attacking = false

func _await_landing() -> void:
	while not is_on_floor():
		await get_tree().physics_frame

func fire_bullet() -> void:
	var bullet = BulletScene.instantiate()
	bullet.global_position = muzzle_point.global_position

	if facing_right:
		bullet.direction = Vector2.RIGHT
	else:
		bullet.direction = Vector2.LEFT

	get_tree().get_current_scene().add_child(bullet)
	print("⚠️ Fired bullet at", bullet.global_position)

# Called externally to reduce player health
func take_damage(amount: int = 1) -> void:
	if is_dead:
		return

	# flash the sprite to show damage
	flash()

	health -= amount
	print("Player took", amount, "damage; remaining health", health)
	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	anim.play("death")
	await anim.animation_finished
	queue_free()

# --- FLASH HELPER ---
func flash() -> void:
	# immediately tint the sprite red
	anim.modulate = Color(1, 0, 0, 1)
	# wait a short moment
	await get_tree().create_timer(0.1).timeout
	# restore the original color
	anim.modulate = Color(1, 1, 1, 1)
