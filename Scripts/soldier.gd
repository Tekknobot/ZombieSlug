# Soldier.gd
extends CharacterBody2D

@export var base_speed:             float = 50.0   # starting speed
@export var speed_increase_per_lvl: float = 10.0   # how much to add each time you level
@export var max_speed:              float = 100.0  # absolute cap
var speed: float

# remember what your speed was before the star power
var _orig_speed: float = 0.0

@export var initial_firerate  := 0.6    # seconds between shots at level 1
var firerate: float
var attack_ready: bool = true
var attack_cooldown_timer: Timer

@export var jump_velocity := -350.0
@export var gravity       := 900.0
@export var max_health    := 5

@onready var anim         := $AnimatedSprite2D
@onready var muzzle_point := $Point                    # Position2D for spawn-offset

@export var initial_grenade_cooldown := 1  # base seconds between throws
@export var grenade_cooldown: float = 1   # seconds between throws
var grenade_cooldown_timer: Timer

@export var initial_mine_cooldown := 2.0   # base seconds between mines
@export var mine_offset: float     = 16.0   # how far in front of player to drop
@export var mine_cooldown: float   = 2.0    # seconds between mine drops
var mine_cooldown_timer: Timer

@export var initial_grenade_damage := 3
var grenade_damage: int

@export var initial_mine_damage := 3
var mine_damage: int

@export var dash_speed:          float        = 800.0  # how fast you dash
@export var dash_time:           float        = 0.2    # how long the dash lasts
@export var dash_cooldown:       float        = 0.3    # time before you can dash again
@export var dash_afterimage_sc:  PackedScene = preload("res://Scenes/Sprites/DashAfterImage.tscn")

var homing_mode: bool = false

var can_dash:     bool     = true
var is_dashing:   bool     = false
var dash_dir:     Vector2  = Vector2.ZERO

const BulletScene = preload("res://Scenes/Sprites/bullet.tscn")
const DogScene    = preload("res://Scenes/Sprites/dog.tscn")
const MercScene   = preload("res://Scenes/Sprites/merc.tscn")
const GrenadeScene = preload("res://Scenes/Sprites/tnt.tscn")
const HomingGrenadeScene = preload("res://Scenes/Sprites/tnt_yellow.tscn")
const MineScene    = preload("res://Scenes/Sprites/mine.tscn")
const MuzzleFlashParticles = preload("res://Scenes/Sprites/muzzle_flash.tscn")

var facing_right: bool = false
var is_attacking:  bool = false
var health:        int  = 0
var is_dead:       bool = false

# Separate cooldown timers
var dog_cooldown_timer: Timer
var merc_cooldown_timer: Timer

@onready var dog_sfx      := $DogSfx       as AudioStreamPlayer2D
@onready var merc_sfx     := $MercSfx      as AudioStreamPlayer2D
@onready var jump_sfx     := $JumpSfx      as AudioStreamPlayer2D
@onready var hurt_sfx     := $HurtSfx      as AudioStreamPlayer2D
@onready var levelup_sfx     := $LevelUpSfx      as AudioStreamPlayer2D
@onready var empty_sfx     := $EmptyClickSfx      as AudioStreamPlayer2D
@onready var dash_sfx     := $DashSfx      as AudioStreamPlayer2D

@onready var glow_mat := $AnimatedSprite2D.material as ShaderMaterial

@onready var hitbox          := $Hitbox as Area2D
@onready var _star_timer := Timer.new()

var _default_material:Material
var _star_material:ShaderMaterial  # assign this in _ready()
var is_invincible: bool = false
var star_damage:    int  = 0

@onready var body_shape := $CollisionShape2D
var _shape_was_disabled: bool
var _zombie_exceptions = []

@export var climb_speed: float = 80.0
var on_ladder: bool   = false
var is_climbing: bool = false

# how long we disable one-way before re-enabling
const DROP_THROUGH_TIME := 0.4

@export var extra_spawn_offset: float = 16.0  # tweak-able in the inspector

var on_roof: bool = false
var _left_roof: bool = false

# -- near your other exports --
@export var dog_base_damage: int          = 3
@export var dog_damage_per_level: int     = 2
@export var merc_base_damage: int         = 5
@export var merc_damage_per_level: int    = 2

const CLIMB_DEADZONE: float = 0.2

func _ready() -> void:	
	#Place elswhere when needed
	Playerstats.reset_stats()
	
	speed = base_speed

	# remember whether it was enabled
	_shape_was_disabled = body_shape.disabled
	
	# remember your default anim material
	_default_material = anim.material
	_star_material   = preload("res://Shaders/StarEffect.tres") as ShaderMaterial

	# setup hitbox (disabled until star power)
	hitbox.monitoring = false
	hitbox.connect("body_entered", Callable(self, "_on_hitbox_body_entered"))

	# initialize firing rate
	firerate = initial_firerate
	
	# wire up level-change so we can speed up
	Playerstats.connect("level_changed", Callable(self, "_on_level_changed"))
			
	# initialize global stats to match this soldier
	Playerstats.max_health = max_health
	Playerstats.health     = max_health
	Playerstats.xp         = 0
	Playerstats.kills      = 0
	Playerstats.level      = 1

	health = max_health
	print("Soldier health set to", health)

	# set up a dedicated one-shot Timer for your fire‐rate
	attack_cooldown_timer = Timer.new()
	attack_cooldown_timer.one_shot = true
	add_child(attack_cooldown_timer)
	attack_cooldown_timer.timeout.connect(Callable(self, "_on_attack_cooldown_finished"))

	dog_cooldown_timer = Timer.new()
	dog_cooldown_timer.wait_time = 10.0
	dog_cooldown_timer.one_shot  = true
	add_child(dog_cooldown_timer)

	merc_cooldown_timer = Timer.new()
	merc_cooldown_timer.wait_time = 10.0
	merc_cooldown_timer.one_shot  = true
	add_child(merc_cooldown_timer)

	grenade_cooldown_timer = Timer.new()
	grenade_cooldown_timer.wait_time = grenade_cooldown
	grenade_cooldown_timer.one_shot  = true
	add_child(grenade_cooldown_timer)

	mine_cooldown_timer = Timer.new()
	mine_cooldown_timer.wait_time = mine_cooldown
	mine_cooldown_timer.one_shot  = true
	add_child(mine_cooldown_timer)
	
	Playerstats.connect("level_changed", Callable(self, "_on_player_leveled"))
	
	grenade_damage = initial_grenade_damage
	mine_damage    = initial_mine_damage

	# Configure a reusable star-power timer
	_star_timer.one_shot = true
	add_child(_star_timer)
	_star_timer.connect("timeout", Callable(self, "_on_star_timeout"))

	await get_tree().create_timer(1).timeout
	_on_level_changed(Playerstats.level)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# ——— Drop-through when pressing Down+Jump on a roof ———
	if is_on_floor() and Input.is_action_just_pressed("jump") and Input.is_action_pressed("ui_down") and on_roof:
		_drop_through_roofs()
		return

	# ——— Ladder climbing override ———
	if on_ladder:
		var up_strength   = Input.get_action_strength("ui_up")
		var down_strength = Input.get_action_strength("ui_down")

		# only climb if input exceeds deadzone
		is_climbing = (up_strength > CLIMB_DEADZONE or down_strength > CLIMB_DEADZONE)

		if is_climbing:
			velocity.x = 0

			# apply only one direction
			if up_strength > CLIMB_DEADZONE:
				velocity.y = -climb_speed
			elif down_strength > CLIMB_DEADZONE:
				velocity.y = climb_speed
			else:
				velocity.y = 0

			anim.play("move")
			move_and_slide()
			return
			
	# ——— Air dash ———
	if is_dashing:
		velocity = dash_dir * dash_speed
		move_and_slide()
		_spawn_afterimage()
		return

	if not is_on_floor() and Input.is_action_just_pressed("attack") and can_dash:
		var dash_input = Vector2(
			Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
			Input.get_action_strength("ui_down")  - Input.get_action_strength("ui_up")
		)
		if dash_input == Vector2.ZERO:
			dash_input = Vector2.UP
		dash_input = dash_input.normalized()
		_start_dash()
		return

	# ——— Ground attack ———
	if is_on_floor() and Input.is_action_just_pressed("attack") and attack_ready:
		_on_attack()

	# ——— Kick off an air dash via button ———
	if Input.is_action_just_pressed("dash") and can_dash and not is_on_floor():
		var dash_input = Vector2(
			Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
			Input.get_action_strength("ui_down")  - Input.get_action_strength("ui_up")
		)
		if dash_input == Vector2.ZERO:
			dash_input = Vector2.UP
		dash_input = dash_input.normalized()
		_start_dash()

	# ——— Spawns ———
	if Input.is_action_just_pressed("dog") and dog_cooldown_timer.is_stopped():
		_spawn_dog()
		dog_cooldown_timer.start()

	if Input.is_action_just_pressed("merc") and merc_cooldown_timer.is_stopped():
		_spawn_merc()
		merc_cooldown_timer.start()

	# ——— Movement, gravity, other attacks ———
	velocity.y += gravity * delta

	if Input.is_action_just_pressed("attack") and attack_ready:
		_on_attack()

	if Input.is_action_just_pressed("grenade") and grenade_cooldown_timer.is_stopped():
		if Playerstats.use_grenade():
			_throw_grenade()
			grenade_cooldown_timer.start()
		else:
			empty_sfx.play()

	if is_on_floor() and Input.is_action_just_pressed("mine") and mine_cooldown_timer.is_stopped() and not on_roof:
		if Playerstats.use_mine():
			_drop_mine()
			mine_cooldown_timer.start()
		else:
			empty_sfx.play()

	var can_move = not is_attacking or not is_on_floor()
	var dir = 0.0
	if can_move:
		dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	velocity.x = dir * speed

	if dir != 0 and can_move:
		facing_right = dir > 0
		anim.flip_h = facing_right
		var abs_off = abs(muzzle_point.position.x)
		if facing_right:
			muzzle_point.position.x = abs_off
		else:
			muzzle_point.position.x = -abs_off

	if can_move and is_on_floor() and Input.is_action_just_pressed("jump"):
		jump_sfx.play()
		velocity.y = jump_velocity
		
	self.velocity = velocity
	move_and_slide()

	# While in the air.
	_left_roof = true	

	# ——— Detect if standing on a Roof collider ———
	on_roof = false
	if is_on_floor():
		for i in range(get_slide_collision_count()):
			var col = get_slide_collision(i)
			if col and col.get_collider().is_in_group("Roof"):
				on_roof = true
				_left_roof = false
				break

	# ——— Ground snap & animations ———
	if is_on_floor() and abs(velocity.y) < 1:
		velocity.y = 0
		self.velocity.y = 0

	if not is_attacking:
		if not is_on_floor():
			anim.play("move")
		elif dir != 0:
			anim.play("move")
		else:
			anim.play("default")

func _drop_through_roofs() -> void:
	$CollisionShape2D.disabled = true
	# give us time to fall through
	await get_tree().create_timer(DROP_THROUGH_TIME).timeout
	$CollisionShape2D.disabled = false

func _start_dash() -> void:
	can_dash   = false
	is_dashing = true

	dash_sfx.play()

	# strictly face dir
	if facing_right:
		dash_dir = Vector2.RIGHT
	else:
		dash_dir = Vector2.LEFT

	anim.play("dash")

	# end dash
	await get_tree().create_timer(dash_time).timeout
	is_dashing = false

	# cooldown before you can dash again
	await get_tree().create_timer(dash_cooldown).timeout
	can_dash = true

func _spawn_afterimage() -> void:
	var ghost = dash_afterimage_sc.instantiate() as AnimatedSprite2D
	ghost.global_position = global_position
	ghost.global_rotation = global_rotation
	ghost.scale           = scale
	ghost.flip_h          = anim.flip_h  # if you flip your soldier via flip_h

	get_tree().get_current_scene().add_child(ghost)
	# no further cleanup needed — the ghost frees itself when its tween finishes

func _on_attack_cooldown_finished() -> void:
	# timer has elapsed → we can fire again
	attack_ready = true
	
func _on_hitbox_body_entered(body: Node) -> void:
	if not is_invincible:
		return

	# 1) if it’s a zombie, deal star_damage
	if body.is_in_group("Zombie") and body.has_method("take_damage"):
		body.take_damage(star_damage)

	# 2) if it’s a mine, trigger its explosion immediately
	elif body.is_in_group("Mine"):
		# your mine script defines `_explode()`
		if body.has_method("_explode"):
			body._explode()

func apply_star(duration: float, damage: int) -> void:
	if is_invincible:
		return
	is_invincible = true
	star_damage   = damage

	# ————— BOOST SPEED —————
	_orig_speed = speed
	speed = _orig_speed * 1.15

	anim.material = _star_material

	# 1) exempt ONLY your body from colliding with zombies:
	_zombie_exceptions.clear()
	for z in get_tree().get_nodes_in_group("Zombie"):
		if z is PhysicsBody2D:
			add_collision_exception_with(z)
			_zombie_exceptions.append(z)

	# 2) turn on the hitbox so it still overlaps zombies
	hitbox.monitoring = true

	# 3) wait out the duration
	await get_tree().create_timer(duration).timeout

	# ————— RESTORE SPEED —————
	speed = _orig_speed

	# 4) restore normal collisions
	for z in _zombie_exceptions:
		if is_instance_valid(z):
			remove_collision_exception_with(z)
	_zombie_exceptions.clear()

	is_invincible     = false
	star_damage       = 0
	hitbox.monitoring = false
	anim.material     = _default_material
					
# --- New spawn functions ---

func _spawn_dog() -> void:
	dog_sfx.play()
	var dog = DogScene.instantiate() as PhysicsBody2D

	# assign damage based on level
	var lvl = Playerstats.level
	if dog.has_meta("damage"):
		dog.damage = dog_base_damage + (lvl - 1) * dog_damage_per_level

	# combine muzzle_point offset with your extra offset
	var base_off = abs(muzzle_point.position.x)
	var x_off = base_off + extra_spawn_offset

	dog.global_position = Vector2(
		global_position.x - x_off,
		global_position.y + muzzle_point.position.y
	)
	get_tree().get_current_scene().add_child(dog)

	if on_roof or _left_roof:
		_add_roof_exceptions(dog)

	for m in get_tree().get_nodes_in_group("Merc"):
		if m is PhysicsBody2D:
			dog.add_collision_exception_with(m)
			m.add_collision_exception_with(dog)

	var base_duration = 5.0
	var extra_per_level = 1.0
	var life_delay = base_duration + (lvl - 1) * extra_per_level
			
	_fade_and_free(dog, life_delay, 1.0)

func _spawn_merc() -> void:
	merc_sfx.play()
	var merc = MercScene.instantiate() as PhysicsBody2D

	var lvl = Playerstats.level
	if merc.has_meta("damage"):
		merc.damage = merc_base_damage + (lvl - 1) * merc_damage_per_level
		
	var base_off = abs(muzzle_point.position.x)
	var x_off = base_off + extra_spawn_offset

	merc.global_position = Vector2(
		global_position.x + x_off,
		global_position.y + muzzle_point.position.y
	)
	get_tree().get_current_scene().add_child(merc)

	if on_roof or _left_roof:
		_add_roof_exceptions(merc)

	for d in get_tree().get_nodes_in_group("Dog"):
		if d is PhysicsBody2D:
			merc.add_collision_exception_with(d)
			d.add_collision_exception_with(merc)

	var base_duration = 5.0
	var extra_per_level = 1.0
	var life_delay = base_duration + (lvl - 1) * extra_per_level
		
	_fade_and_free(merc, life_delay, 1.0)

func _add_roof_exceptions(body: PhysicsBody2D) -> void:
	for roof in get_tree().get_nodes_in_group("Roof"):
		if roof is PhysicsBody2D:
			body.add_collision_exception_with(roof)
			
# Fades out a CanvasItem over `fade_time` seconds after a `delay`, then frees it.
func _fade_and_free(node: CanvasItem, delay: float, fade_time: float) -> void:
	var tw = get_tree().create_tween()
	# step 1: fade alpha → 0
	tw.tween_property(node, "modulate:a", 0.0, fade_time).set_delay(delay)
	# step 2: schedule queue_free() at exactly (delay + fade_time)
	tw.tween_callback(Callable(node, "queue_free"))

func _on_attack() -> void:
	attack_ready = false     # start cooldown
	anim.play("attack")
	fire_bullet()

	# schedule the next time we're allowed to shoot
	attack_cooldown_timer.wait_time = firerate
	attack_cooldown_timer.start()

func enable_homing_grenades(duration: float) -> void:
	if homing_mode:
		return
	homing_mode = true
	# after `duration` seconds, turn it off
	await get_tree().create_timer(duration).timeout
	homing_mode = false

func _on_level_changed(new_level: int) -> void:
	# reduce by 15% per level, but never below 0.1s
	var min_factor = 0.1 / initial_firerate
	var factor = clamp(1.0 - (new_level - 1) * 0.15, min_factor, 1.0)
	firerate = initial_firerate * factor

	# --- grenade cooldown reduction (20% per level, floor 20%) ---
	var gren_factor = clamp(1.0 - (new_level - 1) * 0.50, 0.2, 1.0)
	grenade_cooldown = initial_grenade_cooldown * gren_factor
	grenade_cooldown_timer.wait_time = grenade_cooldown

	# --- mine cooldown reduction (20% per level, floor 20%) ---
	var mine_factor = clamp(1.0 - (new_level - 1) * 0.50, 0.2, 1.0)
	mine_cooldown = initial_mine_cooldown * mine_factor
	mine_cooldown_timer.wait_time = mine_cooldown

	mine_cooldown = initial_mine_cooldown * mine_factor
	mine_cooldown_timer.wait_time = mine_cooldown

	# scale grenade damage (e.g. +1 per level)
	grenade_damage = initial_grenade_damage + (new_level - 1)
	grenade_cooldown = initial_grenade_cooldown * clamp(1.0 - (new_level -1)*0.1, 0.2, 1.0)
	grenade_cooldown_timer.wait_time = grenade_cooldown

	# scale mine damage similarly
	mine_damage = initial_mine_damage + (new_level - 1)
	mine_cooldown = initial_mine_cooldown * clamp(1.0 - (new_level -1)*0.1, 0.2, 1.0)
	mine_cooldown_timer.wait_time = mine_cooldown

	# bump speed but never over max_speed
	speed = base_speed + speed_increase_per_lvl * (new_level - 1)
	speed = clamp(speed, base_speed, max_speed)
	print("Level ", new_level, " → player speed: ", speed)

	# buff all live dogs:
	for d in get_tree().get_nodes_in_group("Dog"):
		if d.has_meta("damage"):
			d.damage = dog_base_damage + (new_level - 1) * dog_damage_per_level
	# buff all live mercs:
	for m in get_tree().get_nodes_in_group("Merc"):
		if m.has_meta("damage"):
			m.damage = merc_base_damage + (new_level - 1) * merc_damage_per_level


	print("Level ", new_level, 
		  " → mine cooldown: ", mine_cooldown)
		
	print("Leveled to ", new_level, " → new firerate: ", firerate)
	play_level_up_effect()
	levelup_sfx.play()

func _await_landing() -> void:
	while not is_on_floor():
		await get_tree().physics_frame

func fire_bullet() -> void:
	# 1) spawn a particle burst at the muzzle
	var flash = MuzzleFlashParticles.instantiate()
	flash.global_position = muzzle_point.global_position
	# flip the X scale manually
	if facing_right:
		flash.scale.x = 1.0
	else:
		flash.scale.x = -1.0
	get_tree().get_current_scene().add_child(flash)

	# 2) now spawn the bullet
	var bullet = BulletScene.instantiate()
	bullet.global_position = muzzle_point.global_position

	# set the bullet’s direction without ternary
	if facing_right:
		bullet.direction = Vector2.RIGHT
	else:
		bullet.direction = Vector2.LEFT

	get_tree().get_current_scene().add_child(bullet)

func take_damage(amount: int = 1) -> void:
	if is_dead or is_invincible:
		return

	hurt_sfx.play()

	flash()
	# apply damage via the PlayerStats singleton
	Playerstats.damage(amount)
	print("Soldier took", amount, "damage; remaining health", Playerstats.health)

	if Playerstats.health <= 0:
		die()

func die() -> void:
	is_dead = true
	anim.play("death")
	await anim.animation_finished
	
	GameOverManager.show_game_over()
	
	glow_mat.set_shader_parameter("active", false)
	
	queue_free()

func flash() -> void:
	anim.modulate = Color(1, 0, 0, 1)
	await get_tree().create_timer(0.1).timeout
	anim.modulate = Color(1, 1, 1, 1)

func _throw_grenade() -> void:
	var g
	if homing_mode:
		# your yellow, homing grenade
		g = HomingGrenadeScene.instantiate()
	else:
		g = GrenadeScene.instantiate()

	# spawn at the muzzle or player hand
	g.global_position = global_position
	g.global_position.y -= 16
	g.damage = grenade_damage
	# set initial velocity based on facing direction
	if facing_right:
		g.velocity.x = g.initial_speed
	else:
		g.velocity.x = -g.initial_speed
	g.velocity.y = g.initial_upward
	get_tree().get_current_scene().add_child(g)

func play_level_up_effect():
	# turn on your shader’s “active” uniform
	glow_mat.set_shader_parameter("active", true)
	# wait however long you want the glow to last
	await get_tree().create_timer(1.0).timeout
	# turn it off again
	glow_mat.set_shader_parameter("active", false)

func _drop_mine() -> void:
	# determine direction without ternary
	var dir: int
	if facing_right:
		dir = 1
	else:
		dir = -1

	# instantiate and position the mine
	var m = MineScene.instantiate()
	m.global_position = global_position + Vector2(dir * mine_offset, 0)
	m.global_position.y -= 8
	m.damage = mine_damage
	get_tree().get_current_scene().add_child(m)
	print("💣 Dropped mine at", m.global_position)
