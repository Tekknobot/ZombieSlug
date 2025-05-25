extends CharacterBody2D

# --- Health & leveling ---
@export var base_max_health: int = 100      # boss health at level 1
var max_health: int                         # scaled from base_max_health
var health: int                             # current boss health

# movement & physics
@export var speed: float = 50.0
@export var gravity: float = 900.0

# detection & attack
@export var detection_radius: float = 128.0  # start attack patterns within this range
@export var attack_range: float = 24.0       # for melee checks
@export var attack_damage: int = 1           # melee damage

# rendering layer (spawn on floor)
const LAYER_Z_FLOOR := 0

# state
var is_dead: bool = false
var pattern_timer: Timer
var pattern_index: int = 0  # cycles through patterns

# --- Attack pattern settings ---
@export var slam_radius: float = 200.0
@export var blast_damage: int = 1
@export var jump_strength: float = -400.0    # upward force for ground slam
@export var fear_radius: float = 100.0       # new radius for fear field
@export var fear_knockback: float = 300.0    # how hard to push them

@onready var health_label: Label = $HealthLabel
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

# Slam settings
@export var slam_height: float = 64.0        
@export var slam_time:   float = 0.2         
@export var slam_effect_scene: PackedScene = preload("res://Scenes/Effects/Explosion.tscn")

# Volley settings
@export var volley_count: int = 16
@export var volley_interval: float = 0.1
@export var bullet_scene: PackedScene = preload("res://Scenes/Sprites/zombie_bullet.tscn")

# Hands grab
@export var hands_scene: PackedScene = preload("res://Scenes/Sprites/hands.tscn")

# Lightning nova
@export var lightning_fx: PackedScene    = preload("res://Scenes/Effects/Chain_Bolt.tscn")
@export var lightning_radius: float     = 256.0
@export var lightning_targets: int      = 16
@export var lightning_damage: int       = 3

@onready var attack_sfx: AudioStreamPlayer2D = $AttackSfx

func _ready():
	randomize()
	# initialize and scale health for current player level
	max_health = int(base_max_health * pow(1.2, Playerstats.level - 1))
	health = max_health

	Playerstats.connect("level_changed", Callable(self, "_on_level_changed"))

	# add to Zombie group
	if not is_in_group("Zombie"):
		add_to_group("Zombie")

	# always draw on the floor layer
	z_index = LAYER_Z_FLOOR

	# ignore any sidewalks & streets so we never leave the floor
	for sw in get_tree().get_nodes_in_group("Sidewalk"):
		if sw is PhysicsBody2D:
			add_collision_exception_with(sw)
	for st in get_tree().get_nodes_in_group("Street"):
		if st is PhysicsBody2D:
			add_collision_exception_with(st)

	# prepare (but don’t start) attack pattern timer
	pattern_timer = Timer.new()
	pattern_timer.wait_time = 1
	pattern_timer.one_shot = false
	add_child(pattern_timer)
	pattern_timer.timeout.connect(Callable(self, "_next_pattern"))

	set_process(true)
	update_health_label()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 1) find the player
	var players = get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		return
	var p = players[0] as CharacterBody2D

	# 2) treat the player as if at our Y-level
	var player_floor_pos = Vector2(p.global_position.x, global_position.y)
	var to_player = player_floor_pos - global_position
	var horz_dist = abs(to_player.x)

	# 3) always face horizontally
	anim.flip_h = to_player.x > 0

	# 4) melee override (horizontal only!)
	if horz_dist <= attack_range and is_on_floor():
		velocity = Vector2.ZERO
		if not pattern_timer.is_stopped():
			pattern_timer.stop()
		attack_sfx.play()
		if anim.animation != "attack":
			_start_attack()
			if p.has_method("take_damage"):
				p.take_damage(attack_damage)
		return

	# 5) detection & pattern start/stop
	if horz_dist <= detection_radius:
		velocity.x = 0
		_start_attack()
		if pattern_timer.is_stopped():
			pattern_timer.start()
	else:
		if not pattern_timer.is_stopped():
			pattern_timer.stop()
		velocity.x = sign(to_player.x) * speed
		if anim.animation != "move":
			anim.play("move")

	# 6) lane‐based collisions with other zombies
	for other in get_tree().get_nodes_in_group("Zombie"):
		if other == self or not (other is PhysicsBody2D):
			continue
		if other.z_index != z_index:
			add_collision_exception_with(other)
		else:
			remove_collision_exception_with(other)

	# 7) gravity & slide
	if is_on_floor():
		velocity.y = 0
	else:
		velocity.y += gravity * delta

	move_and_slide()

func _on_level_changed(new_level: int) -> void:
	max_health = int(base_max_health * pow(1.2, new_level - 1))
	health = max_health
	update_health_label()

# make _next_pattern async by introducing an await inside
func _next_pattern() -> void:
	if is_dead:
		return		
	pattern_timer.stop()
	var players = get_tree().get_nodes_in_group("Player")
	if players.is_empty(): return
	var dist = players[0].global_position.distance_to(global_position)
	if dist > detection_radius: return

	match pattern_index:
		0:   await _zombie_grab()
		1:   await _ground_slam()
		2:   await _projectile_volley()
		3:   await _lightning_nova()   # ← new pattern
	pattern_index = (pattern_index + 1) % 4

	if dist <= detection_radius:
		pattern_timer.start()

func _start_attack():
	if is_dead:
		return		
	if anim.animation != "attack":
		anim.play("attack")
		attack_sfx.play()

func _ground_slam() -> void:
	if is_dead:
		return

	anim.play("attack")
			
	# 1) Precompute
	var origin = global_position
	var apex   = origin + Vector2(0, -slam_height)
	var half   = slam_time * 0.5

	if is_dead:
		return
		
	# 2) Rise
	anim.play("jump")
	var t = 0.0
	while t < half:
		t += get_process_delta_time()
		global_position.y = lerp(origin.y, apex.y, t/half)
		await get_tree().physics_frame

	if is_dead:
		return
		
	# 3) Fall
	t = 0.0
	while t < half:
		t += get_process_delta_time()
		global_position.y = lerp(apex.y, origin.y, t/half)
		await get_tree().physics_frame
	global_position = origin

	if is_dead:
		return
		
	# 4) Slam effect & camera shake
	_start_attack()
	# instantiate your explosion VFX and stick it in group "Explosion" 
	# so SmoothShakeCamera sees it and shakes
	var fx = slam_effect_scene.instantiate()
	fx.global_position = global_position
	fx.global_position.y -= 16
	fx.add_to_group("Explosion")
	get_tree().get_current_scene().add_child(fx)

	# 5) Damage & knockback
	for body in get_tree().get_nodes_in_group("Player") + get_tree().get_nodes_in_group("Zombie"):
		if body is CharacterBody2D and body.global_position.distance_to(origin) <= slam_radius:
			if !body.is_on_floor():
				return
			if body.has_method("take_damage"):
				body.take_damage(blast_damage)
			if body.has_method("apply_knockback"):
				var dir = (body.global_position - origin).normalized()
				body.apply_knockback(dir * blast_damage)

func _projectile_volley() -> void:
	if is_dead:
		return		
	_start_attack()
	for i in range(volley_count):
		var angle = (TAU / volley_count) * i
		var dir = Vector2(cos(angle), sin(angle))
		var b = bullet_scene.instantiate()
		b.global_position = global_position
		b.global_position.y -= 48
		b.direction = dir
		get_tree().get_current_scene().add_child(b)
		await get_tree().create_timer(volley_interval).timeout
		
func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
	
	flash()
		
	health -= amount
	update_health_label()
	$HitSfx.play()
	if health <= 0:
		_die()
	else:
		_shake(0.2, 4.0)

func _shake(duration: float, magnitude: float) -> void:
	if is_dead:
		return
	var orig = position
	var t = Timer.new()
	t.wait_time = duration
	t.one_shot = true
	add_child(t)
	t.start()
	$AttackSfx.play()
	while t.time_left > 0:
		position = orig + Vector2(
			randf_range(-magnitude, magnitude),
			randf_range(-magnitude, magnitude)
		)
		await get_tree().physics_frame
	position = orig
	t.queue_free()

func _die() -> void:
	is_dead = true
	update_health_label()
	health_label.hide()
	
	# play the death anim
	anim.play("death")
	$Blood.emitting = true
	attack_sfx.play()
	# wait until the animation actually finishes
	remove_from_group("Zombie")
	$CollisionShape2D.disabled = true
	await get_tree().create_timer(3).timeout
	visible = false
	# then free
	queue_free()
	
func update_health_label() -> void:
	if not is_instance_valid(health_label):
		return
	health_label.text = "%d" % health
	var pct := float(health) / float(max_health)
	var tint := Color(1,1,1)
	if pct > 0.66:
		tint = Color(0,1,0)
	elif pct > 0.33:
		tint = Color(1,1,0)
	else:
		tint = Color(1,0,0)
	health_label.modulate = tint

# Spawns the "hands" effect at the player's position, up to 3 times with a short delay.
func _spawn_hands_at_player() -> void:
	if is_dead:
		return
			
	var players = get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		return
	var player = players[0] as Node2D

	if player.is_on_floor():		
		# Try 3 times
		for i in range(1):
			# instantiate and position
			var hands = hands_scene.instantiate() as Node2D
			hands.global_position = player.global_position
			hands.global_position.y -= 8
			get_tree().get_current_scene().add_child(hands)

			# optional: small delay between attempts
			await get_tree().create_timer(0.1).timeout

func _zombie_grab() -> void:
	if is_dead:
		return	
	_start_attack()
	# Wait for your "wind-up" anim (adjust name/duration as needed)
	await get_tree().create_timer(0.1).timeout
	# Spawn the hands
	await _spawn_hands_at_player()

# ——— damaging chain-lightning nova ———
func _lightning_nova() -> void:
	if is_dead:
		return	
	_start_attack() 
	await get_tree().create_timer(0.3).timeout

	# gather all valid targets (player + zombies, excluding self)
	var all_bodies = get_tree().get_nodes_in_group("Player") + get_tree().get_nodes_in_group("Zombie")
	var candidates := []
	for b in all_bodies:
		if b is CharacterBody2D and b != self and b.global_position.distance_to(global_position) <= lightning_radius:
			candidates.append(b)

	# sort by distance (closest first)
	candidates.sort_custom(Callable(self, "_compare_distance"))

	# fire up to lightning_targets bolts
	for i in range(min(lightning_targets, candidates.size())):
		var tgt = candidates[i]
		if not is_instance_valid(tgt):
			return		
		_spawn_lightning(global_position, tgt.global_position)

		# deal damage
		if tgt.has_method("take_damage"):
			tgt.take_damage(lightning_damage)

		await get_tree().create_timer(0.1).timeout


func _spawn_lightning(from_pos: Vector2, to_pos: Vector2) -> void:
	if is_dead:
		return
		
	var bolt = lightning_fx.instantiate()
	bolt.global_position = from_pos
	bolt.global_position.y -= 64
	get_tree().get_current_scene().add_child(bolt)
	if bolt.has_method("play"):
		bolt.play(to_pos)


func _compare_distance(a: CharacterBody2D, b: CharacterBody2D) -> int:
	return int(
		a.global_position.distance_to(global_position)
		- b.global_position.distance_to(global_position)
	)

# Briefly tint the sprite red, then restore
func flash() -> void:
	var orig = anim.modulate
	anim.modulate = Color(1, 0, 0, 1)
	await get_tree().create_timer(0.1).timeout
	anim.modulate = orig
