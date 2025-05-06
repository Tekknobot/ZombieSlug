extends CharacterBody2D

@export var speed: float           = 120.0
@export var attack_range: float    = 32.0
@export var attack_damage: int     = 5
@export var attack_cooldown: float = 0.5
@export var gravity: float         = 900.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var attack_timer: Timer
var current_target       # untyped on purpose

@onready var attack_sfx: AudioStreamPlayer2D = $AttackSfx

func _ready() -> void:
	# setup attack cooldown timer
	attack_timer = Timer.new()
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = false
	add_child(attack_timer)
	attack_timer.connect("timeout", Callable(self, "_on_attack_timeout"))

func _physics_process(delta: float) -> void:
	# 1) gather only real CharacterBody2D zombies, skip self
	var zombies := []
	for node in get_tree().get_nodes_in_group("Zombie"):
		if node != self and node is CharacterBody2D and is_instance_valid(node):
			zombies.append(node)

	if zombies.is_empty():
		# no valid target
		current_target = null
		if not attack_timer.is_stopped():
			attack_timer.stop()
		velocity.x = 0
		anim.play("idle")
	else:
		# 2) pick nearest
		current_target = zombies[0]
		var best_dist = current_target.global_position.distance_to(global_position)
		for z in zombies:
			var d = z.global_position.distance_to(global_position)
			if d < best_dist:
				best_dist = d
				current_target = z

		var to_tgt = current_target.global_position - global_position

		# 3) chase or attack
		if best_dist > attack_range:
			velocity.x = sign(to_tgt.x) * speed
			if not attack_timer.is_stopped():
				attack_timer.stop()
			if anim.animation != "move":
				anim.play("move")
			anim.flip_h = velocity.x > 0
		else:
			velocity.x = 0
			if attack_timer.is_stopped():
				attack_timer.start()
			if anim.animation != "attack":
				anim.play("attack")
			anim.flip_h = to_tgt.x > 0

	# 4) gravity + movement
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0
	move_and_slide()

func _on_attack_timeout() -> void:
	# only hit if still valid and in scene
	if current_target and is_instance_valid(current_target) and current_target.is_inside_tree():
		# play your merc attack SFX
		attack_sfx.play()
		# now apply damage
		if current_target.has_method("take_damage"):
			current_target.take_damage(attack_damage)
	else:
		# lost target—stop attacking so we re-acquire next frame
		attack_timer.stop()
