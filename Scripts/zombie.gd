# Zombie.gd
extends CharacterBody2D

@export var xp_award: int         = 5
@export var min_speed: float      = 25.0
@export var max_speed: float      = 75.0
@export var attack_range: float   = 24.0
@export var attack_damage: int    = 1
@export var attack_cooldown: float= 0.2
@export var max_health: int       = 5
@export var gravity: float        = 900.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

@onready var hit_sfx: AudioStreamPlayer2D   = $HitSfx
@onready var death_sfx: AudioStreamPlayer2D = $DeathSfx

# Internal state
var speed: float   = 0.0
var health: int    = 0
var is_dead: bool  = false
var attack_timer: Timer

# shaking state
var _shake_active:    bool    = false
var _shake_timer:     Timer
var _shake_orig_pos:  Vector2
var _shake_magnitude: float   = 4.0

signal died(pos: Vector2)

func _ready() -> void:
	randomize()
	speed  = randi_range(int(min_speed), int(max_speed))
	health = max_health
	print("Zombie speed=", speed, "health=", health)

	attack_timer = Timer.new()
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot  = false
	add_child(attack_timer)
	attack_timer.connect("timeout", Callable(self, "_on_attack_timeout"))

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 1) If any homing grenades exist, chase the nearest one instead of the player:
	var grenades = get_tree().get_nodes_in_group("TNT_yellow")
	var target: Node2D = null
	if not grenades.is_empty():
		# find closest grenade
		var best_dist = INF
		for g in grenades:
			if not (g is Node2D): continue
			var d = global_position.distance_to(g.global_position)
			if d < best_dist:
				best_dist = d
				target    = g
	else:
		# fall back to the player
		var players = get_tree().get_nodes_in_group("Player")
		if players.is_empty():
			if not attack_timer.is_stopped():
				attack_timer.stop()
			return
		target = players[0] as CharacterBody2D

	# 2) move/tackle exactly as before, but using `target`:
	var to_target = target.global_position - global_position
	var dist = to_target.length()

	if dist > attack_range:
		velocity.x = sign(to_target.x) * speed
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
			death_sfx.play()
			anim.play("attack")
		anim.flip_h = to_target.x > 0

	# 3) gravity + slide
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	move_and_slide()

func _on_attack_timeout() -> void:
	for p in get_tree().get_nodes_in_group("Player"):
		if p is CharacterBody2D and p.has_method("take_damage"):
			var dist = global_position.distance_to(p.global_position)
			if dist <= attack_range:
				p.take_damage(attack_damage)
				print("Zombie attacked player for ", attack_damage)

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return

	hit_sfx.play()

	flash()  # your red‐flash helper

	health -= amount
	print("Zombie took", amount, "damage; remaining=", health)

	if health <= 0:
		is_dead = true
		
		# 1) award kill + XP
		Playerstats.add_kill(xp_award)
		
		death_sfx.play()
		
		# after awarding the kill...
		if randi() % 100 < 10:
			var drop = preload("res://Scenes/Sprites/TNTPickup.tscn").instantiate()
			drop.global_position = global_position
			drop.global_position.y -= 8
			get_tree().get_current_scene().add_child(drop)	
		
		if randi() % 100 < 10:
			var drop2 = preload("res://Scenes/Sprites/MinePickup.tscn").instantiate()
			drop2.global_position = global_position
			drop2.global_position.y -= 8
			get_tree().get_current_scene().add_child(drop2)		

		if randi() % 100 < 5:
			var drop3 = preload("res://Scenes/Sprites/HealthPickup.tscn").instantiate()
			drop3.global_position = global_position
			drop3.global_position.y -= 8
			get_tree().get_current_scene().add_child(drop3)		
		
		if randi() % 100 < 3:
			var drop4 = preload("res://Scenes/Sprites/LightningPickup.tscn").instantiate()
			drop4.global_position = global_position
			drop4.global_position.y -= 8
			get_tree().get_current_scene().add_child(drop4)		

		if randi() % 100 < 100:
			var drop5 = preload("res://Scenes/Sprites/StarPickup.tscn").instantiate()
			drop5.global_position = global_position
			drop5.global_position.y -= 8
			get_tree().get_current_scene().add_child(drop5)		
			
		if randi() % 100 < 3:
			var drop6 = preload("res://Scenes/Sprites/FirestormPickup.tscn").instantiate()
			drop6.global_position = global_position
			drop6.global_position.y -= 8
			get_tree().get_current_scene().add_child(drop6)		
			
		if randi() % 100 < 3:
			var drop7 = preload("res://Scenes/Sprites/FreezePickup.tscn").instantiate()
			drop7.global_position = global_position
			drop7.global_position.y -= 8
			get_tree().get_current_scene().add_child(drop7)		

		if randi() % 100 < 3:
			var drop8 = preload("res://Scenes/Sprites/BulletPickup.tscn").instantiate()
			drop8.global_position = global_position
			drop8.global_position.y -= 8
			get_tree().get_current_scene().add_child(drop8)		

		if randi() % 100 < 3:
			var drop9 = preload("res://Scenes/Sprites/TimeWarpPickup.tscn").instantiate()
			drop9.global_position = global_position
			drop9.global_position.y -= 8
			get_tree().get_current_scene().add_child(drop9)		

		if randi() % 100 < 3:
			var drop10 = preload("res://Scenes/Sprites/OrbitalPickup.tscn").instantiate()
			drop10.global_position = global_position
			drop10.global_position.y -= 8
			get_tree().get_current_scene().add_child(drop10)		
		
		if randi() % 100 < 10:
			var drop11 = preload("res://Scenes/Sprites/TNT_YellowPickup.tscn").instantiate()
			drop11.global_position = global_position
			drop11.global_position.y -= 8
			get_tree().get_current_scene().add_child(drop11)	
		
		# 1) award kill + XP, play effects, drop pickups, etc.
		is_dead = true
		_die_cleanup()
		$Blood.emitting = true
		Playerstats.add_kill(xp_award)
		death_sfx.play()

		# emit our new died signal, passing the world position
		emit_signal("died", global_position)
		
		# 2) play death anim, wait, then free
		anim.play("death")
		await get_tree().create_timer(3).timeout
		queue_free()

func _die_cleanup() -> void:
	# 1) prevent any further _physics_process/attack logic
	is_dead = true

	# 2) remove from the “Zombie” group
	remove_from_group("Zombie")

	# 3) stop and tear down the attack timer so it never calls back
	if attack_timer:
		attack_timer.stop()
		attack_timer.disconnect("timeout", Callable(self, "_on_attack_timeout"))
		attack_timer.queue_free()

	# 4) turn off ALL collisions on this body
	collision_layer = 0
	collision_mask  = 0

	# 5) disable every CollisionShape2D child
	for shape in get_children():
		if shape is CollisionShape2D:
			shape.disabled = true

	# 6) if you also have an Area2D hitbox, disable its monitoring
	if has_node("Hitbox"):
		$Hitbox.monitoring = false


# Briefly tint the sprite red, then restore
func flash() -> void:
	var orig = anim.modulate
	anim.modulate = Color(1, 0, 0, 1)
	await get_tree().create_timer(0.1).timeout
	anim.modulate = orig

func start_shake(duration: float = 0.2, magnitude: float = 4.0) -> void:
	if _shake_active:
		return
	_shake_active    = true
	_shake_orig_pos  = position
	_shake_magnitude = magnitude

	# one-shot timer to end the shake
	_shake_timer = Timer.new()
	_shake_timer.wait_time = duration
	_shake_timer.one_shot  = true
	add_child(_shake_timer)
	_shake_timer.connect("timeout", Callable(self, "_on_shake_timeout"))
	_shake_timer.start()

	# enable processing so _process() will run
	set_process(true)

func _process(delta: float) -> void:
	if _shake_active:
		# jitter around original spot
		position = _shake_orig_pos + Vector2(
			randf_range(-_shake_magnitude, _shake_magnitude),
			randf_range(-_shake_magnitude, _shake_magnitude)
		)

func _on_shake_timeout() -> void:
	# end shake, restore exact position
	_shake_active = false
	position      = _shake_orig_pos
	set_process(false)
	_shake_timer.queue_free()
