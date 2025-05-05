extends CharacterBody2D

@export var min_speed: float       = 25.0
@export var max_speed: float       = 50.0
@export var attack_range: float    = 32.0
@export var attack_damage: int     = 1
@export var attack_cooldown: float = 1.0
@export var max_health: int        = 5
@export var gravity: float         = 900.0

# Player reference
var player: CharacterBody2D = null
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

# Internal state
var speed: float = 0.0
var health: int   = 0
var is_dead: bool = false
var can_attack: bool = true
var attack_timer: Timer = null

func _ready() -> void:
	randomize()
	speed = randi_range(int(min_speed), int(max_speed))
	health = max_health
	print("Zombie speed=", speed, "health=", health)

	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player = players[0] as CharacterBody2D
	else:
		push_error("No Player found in Player group!")

	anim.connect("animation_finished", Callable(self, "_on_animation_finished"))

	attack_timer = Timer.new()
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true
	add_child(attack_timer)
	attack_timer.connect("timeout", Callable(self, "_on_attack_timeout"))

func _physics_process(delta: float) -> void:
	if is_dead or player == null:
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()

	if dist > attack_range:
		velocity.x = sign(to_player.x) * speed
	else:
		velocity.x = 0
		if can_attack:
			_attack_player()

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	move_and_slide()

	# Face player when attacking, else face movement direction
	if dist <= attack_range:
		anim.flip_h = to_player.x > 0
	else:
		anim.flip_h = velocity.x > 0

	if abs(velocity.x) > 0:
		anim.play("move")
	elif dist <= attack_range:
		anim.play("attack")
		if player and player.has_method("take_damage"):
			player.take_damage(1)
	else:
		anim.play("default")

func _attack_player() -> void:
	can_attack = false
	anim.play("attack")
	if player and player.has_method("take_damage"):
		player.take_damage(attack_damage)
		print("Zombie attacked player for", attack_damage)
	attack_timer.start()

func _on_attack_timeout() -> void:
	can_attack = true

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
	health -= amount
	print("Zombie took", amount, "damage; remaining=", health)
	if health <= 0:
		is_dead = true
		anim.play("death")

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "death":
		queue_free()
