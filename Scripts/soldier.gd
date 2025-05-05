extends CharacterBody2D

@export var speed         := 200.0
@export var jump_velocity := -350.0
@export var gravity       := 900.0

@onready var anim         := $AnimatedSprite2D
@onready var muzzle_point := $Point      # Position2D child for bullet spawn

const BulletScene = preload("res://Scenes/Sprites/bullet.tscn")

var facing_right: bool = false
var is_attacking:  bool = false

func _physics_process(delta: float) -> void:
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
	# Allow air control: if on ground, wait 1s; if in air, wait until landing
	if is_on_floor():
		await get_tree().create_timer(0.2).timeout
	else:
		await _await_landing()
	is_attacking = false

func _await_landing() -> void:
	# Await until the player lands (SceneTree physics_frame signal)
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
