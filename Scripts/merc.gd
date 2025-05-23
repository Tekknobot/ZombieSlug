extends CharacterBody2D

@export var speed: float           = 120.0
@export var attack_range: float    = 32.0
@export var attack_damage: int     = 5
@export var attack_cooldown: float = 0.5
@export var gravity: float         = 900.0

# how close to “underneath” before we stop flipping
const FLIP_DEADZONE: float = 4.0

@onready var anim: AnimatedSprite2D       = $AnimatedSprite2D
@onready var attack_sfx: AudioStreamPlayer2D = $AttackSfx

var attack_timer: Timer
var current_target  # untyped on purpose

func _ready() -> void:
	attack_timer = Timer.new()
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot  = false
	add_child(attack_timer)
	attack_timer.connect("timeout", Callable(self, "_on_attack_timeout"))

func _physics_process(delta: float) -> void:
	# 1) Get the player
	var players = get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		return
	var player = players[0] as CharacterBody2D

	# 2) Gather same‐layer zombies and ignore collisions with every OTHER zombie
	var same_layer_zombies: Array[CharacterBody2D] = []
	for z in get_tree().get_nodes_in_group("Zombie"):
		if not is_instance_valid(z) or not (z is CharacterBody2D):
			continue
		# only target and collide with zombies on your layer
		if z.z_index == player.get_child(0).z_index:
			same_layer_zombies.append(z)
			remove_collision_exception_with(z)
		else:
			# ignore collisions with off‐layer zombies
			add_collision_exception_with(z)

	# 3) if no same-ground zombies, idle/reset attack
	if same_layer_zombies.is_empty():
		current_target = null
		if not attack_timer.is_stopped():
			attack_timer.stop()
		velocity.x = 0
		anim.play("idle")
		return
	else:
		# pick nearest
		current_target = same_layer_zombies[0]
		var best_dist = current_target.global_position.distance_to(global_position)
		for z in same_layer_zombies:
			var d = z.global_position.distance_to(global_position)
			if d < best_dist:
				best_dist = d
				current_target = z

		var to_tgt = current_target.global_position - global_position
		var dx = to_tgt.x

		# chase or attack
		if best_dist > attack_range:
			velocity.x = sign(dx) * speed
			if not attack_timer.is_stopped():
				attack_timer.stop()
			if anim.animation != "move":
				anim.play("move")
			# only flip if target is off-center
			if abs(dx) > FLIP_DEADZONE:
				if velocity.x > 0:
					anim.flip_h = true
				else:
					anim.flip_h = false
		else:
			velocity.x = 0
			if attack_timer.is_stopped():
				attack_timer.start()
			if anim.animation != "attack":
				anim.play("attack")
			# only flip if target is off-center
			if abs(dx) > FLIP_DEADZONE:
				if dx > 0:
					anim.flip_h = true
				else:
					anim.flip_h = false

	# gravity + movement
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	move_and_slide()

func _on_attack_timeout() -> void:
	if current_target and is_instance_valid(current_target) and current_target.is_inside_tree():
		attack_sfx.play()
		if current_target.has_method("take_damage"):
			current_target.take_damage(attack_damage)
	else:
		attack_timer.stop()
