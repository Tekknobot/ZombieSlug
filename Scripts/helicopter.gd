extends CharacterBody2D

@export var controller_id: int = 1    # second gamepad (0 is P1, 1 is P2)
@export var speed:         float = 300.0
@export var shoot_cooldown: float = 0.5
@export var bullet_scene:  PackedScene = preload("res://Scenes/Sprites/bullet.tscn")

@onready var sprite := $Sprite

var _wiggle_time:   float = 0.0
@export var wiggle_speed: float = 5.0    # how fast it oscillates
@export var wiggle_angle: float = 10.0   # max degrees from center

var can_shoot: bool = true
var shoot_timer: Timer

@onready var muzzle := $Muzzle

func _ready() -> void:
	# cooldown timer
	shoot_timer = Timer.new()
	shoot_timer.one_shot = true
	shoot_timer.wait_time = shoot_cooldown
	add_child(shoot_timer)
	shoot_timer.timeout.connect(Callable(self, "_on_shoot_ready"))

func _physics_process(delta: float) -> void:
	# accumulate a time value
	_wiggle_time += delta * wiggle_speed

	# set rotation to sine wave between –wiggle_angle and +wiggle_angle
	sprite.rotation_degrees = sin(_wiggle_time) * wiggle_angle
		
	# horizontal movement
	var dir := Input.get_action_strength("hel_right") - Input.get_action_strength("hel_left")
	velocity.x = dir * speed

	# flip the sprite: default (facing left) is flip_h = false
	if dir < 0:
		sprite.flip_h = false
	elif dir > 0:
		sprite.flip_h = true

	move_and_slide()

	# clamp against the camera‘s viewport in world coords
	var vw := get_viewport().get_visible_rect().size.x
	var cam := get_viewport().get_camera_2d()
	if cam:
		var cam_center := cam.global_position.x
		var half := vw * 0.5
		global_position.x = clamp(global_position.x,
								   cam_center - half,
								   cam_center + half)

func _input(event: InputEvent) -> void:
	# Optional: if you want to ONLY listen on pad #2:
	if event is InputEventJoypadButton and event.device == controller_id and event.pressed:
		if event.button_index == JOY_BUTTON_A and can_shoot:
			_shoot()
	# Else you can also check Input.is_action_just_pressed("hel_shoot") for keyboard/gamepad mix

func _shoot() -> void:
	can_shoot = false

	# instantiate your bullet
	var b = bullet_scene.instantiate() as Area2D
	b.global_position = muzzle.global_position

	# fire straight down
	b.direction = Vector2.DOWN

	get_tree().get_current_scene().add_child(b)
	shoot_timer.start()



func _on_shoot_ready() -> void:
	can_shoot = true
