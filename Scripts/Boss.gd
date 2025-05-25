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
@export var shock_radius: float = 150.0
@export var volley_count: int = 5
@export var volley_interval: float = 0.2
@export var slam_radius: float = 200.0
@export var blast_damage: int = 15
@export var jump_strength: float = -400.0    # upward force for ground slam
@export var fear_radius: float = 100.0       # new radius for fear field
@export var fear_knockback: float = 300.0    # how hard to push them

@onready var health_label: Label = $HealthLabel
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	randomize()
	# initialize and scale health for current player level
	max_health = int(base_max_health * pow(1.2, Playerstats.level - 1))
	health = max_health

	# connect to level changes so health scales on the fly
	Playerstats.connect("level_changed", Callable(self, "_on_level_changed"))

	# add to Zombie group for collisions & targeting
	if not is_in_group("Zombie"):
		add_to_group("Zombie")

	# ensure boss draws on the floor layer
	z_index = LAYER_Z_FLOOR

	# prepare (but don’t start) attack pattern timer
	pattern_timer = Timer.new()
	pattern_timer.wait_time = 1.0
	pattern_timer.one_shot = false
	add_child(pattern_timer)
	pattern_timer.timeout.connect(Callable(self, "_next_pattern"))

	set_process(true)
	update_health_label()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# — lane-based collisions: only collide with zombies on same z_index —
	for other in get_tree().get_nodes_in_group("Zombie"):
		if other == self or not (other is PhysicsBody2D):
			continue
		if other.z_index != z_index:
			add_collision_exception_with(other)
		else:
			remove_collision_exception_with(other)
	# —————————————————————————————————————————————————————————————

	# follow player on X until within detection_radius
	var players = get_tree().get_nodes_in_group("Player")
	if not players.is_empty():
		var p = players[0] as CharacterBody2D
		var to_player = p.global_position - global_position

		if abs(to_player.x) <= detection_radius:
			# close enough → stop and start patterns
			velocity.x = 0
			anim.play("default")
			if pattern_timer.is_stopped():
				pattern_timer.start()
		else:
			# too far → patrol toward
			if not pattern_timer.is_stopped():
				pattern_timer.stop()
			velocity.x = sign(to_player.x) * speed
			if anim.animation != "move":
				anim.play("move")
				anim.flip_h = to_player.x > 0

	# gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	move_and_slide()

func _on_level_changed(new_level: int) -> void:
	max_health = int(base_max_health * pow(1.2, new_level - 1))
	health = max_health
	update_health_label()

func _next_pattern():
	# only fire if player still within detection radius
	var players = get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		return
	var dist = players[0].global_position.distance_to(global_position)
	if dist > detection_radius:
		return

	match pattern_index:
		0:
			_do_shockwave()
			anim.play("default")
		1:
			_ground_slam()
			anim.play("attack")
			$DeathSfx.play()
		2:
			_fear_field()
			anim.play("attack")
			$DeathSfx.play()
	pattern_index = (pattern_index + 1) % 3

func _do_shockwave():
	for body in get_tree().get_nodes_in_group("Player") + get_tree().get_nodes_in_group("Zombie"):
		if body is CharacterBody2D and body.global_position.distance_to(global_position) <= shock_radius:
			if body.has_method("take_damage"):
				body.take_damage(blast_damage)

# At the top of Boss.gd, add:
@export var slam_height: float = 64.0          # how high the boss jumps
@export var slam_time:   float = 0.2            # total time for rise+fall
@export var slam_effect_scene: PackedScene = preload("res://Scenes/Effects/Explosion.tscn")

func _ground_slam() -> void:
	# 1) Precompute
	var origin = global_position
	var apex   = origin + Vector2(0, -slam_height)
	var half   = slam_time * 0.5

	# 2) Rise
	anim.play("jump")
	var t = 0.0
	while t < half:
		t += get_process_delta_time()
		global_position.y = lerp(origin.y, apex.y, t/half)
		await get_tree().physics_frame

	# 3) Fall
	t = 0.0
	while t < half:
		t += get_process_delta_time()
		global_position.y = lerp(apex.y, origin.y, t/half)
		await get_tree().physics_frame
	global_position = origin

	# 4) Slam effect & camera shake
	anim.play("slam")
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
			if body.has_method("take_damage"):
				body.take_damage(blast_damage)
			if body.has_method("apply_knockback"):
				var dir = (body.global_position - origin).normalized()
				body.apply_knockback(dir * blast_damage)

func _fear_field():
	# terrifying roar pushes zombies back
	anim.play("roar")
	await get_tree().create_timer(0.5).timeout
	for z in get_tree().get_nodes_in_group("Zombie"):
		if z is CharacterBody2D and z.global_position.distance_to(global_position) <= fear_radius:
			if z.has_method("apply_knockback"):
				var dir = (z.global_position - global_position).normalized()
				z.apply_knockback(dir * fear_knockback)

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
	health -= amount
	update_health_label()
	if health <= 0:
		_die()
	else:
		_shake(0.2, 4.0)

func _shake(duration: float, magnitude: float) -> void:
	var orig = position
	var t = Timer.new()
	t.wait_time = duration
	t.one_shot = true
	add_child(t)
	t.start()
	while t.time_left > 0:
		position = orig + Vector2(
			randf_range(-magnitude, magnitude),
			randf_range(-magnitude, magnitude)
		)
		await get_tree().physics_frame
	position = orig
	t.queue_free()

func _die():
	is_dead = true
	update_health_label()
	health_label.hide()
	anim.play("death")
	await get_tree().create_timer(1).timeout
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
