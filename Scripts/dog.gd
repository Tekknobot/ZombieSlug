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
	# in _physics_process, gather only same‐layer zombies and ignore collisions with them
	var zombies := []
	for node in get_tree().get_nodes_in_group("Zombie"):
		if node is CharacterBody2D and is_instance_valid(node):
			if node.z_index == z_index:
				# only target same-ground zombies
				zombies.append(node)
				# and don't physically collide with them
				add_collision_exception_with(node)
			else:
				# re-enable collision against off-ground zombies
				remove_collision_exception_with(node)
				
	if zombies.is_empty():
		current_target = null
		if not attack_timer.is_stopped():
			attack_timer.stop()
		velocity.x = 0
		anim.play("idle")
	else:
		# pick nearest
		current_target = zombies[0]
		var best_dist = current_target.global_position.distance_to(global_position)
		for z in zombies:
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
