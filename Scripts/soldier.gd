# Soldier.gd
extends CharacterBody2D

@export var base_speed:             float = 50.0   # starting speed
@export var speed_increase_per_lvl: float = 10.0   # how much to add each time you level
@export var max_speed:              float = 100.0  # absolute cap
var speed: float

@export var knockback_speed:    float = 150.0   # horizontal speed when hit
@export var knockback_upward:   float = -150.0  # vertical boost when hit
# how long the knockback lasts
@export var knockback_duration: float = 0.2

var _knockback_time_left: float = 0.0

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

@export var shock_radius:       float = 150.0  # how far down it hits
@export var shock_damage:      int   = 9999     # flat damage to each zombie
@export var shock_knockback:   float = 300.0  # impulse strength
@export var shock_cooldown:    float = 1.0   # seconds between uses
@export var initial_shocks: int = 5       # start with 5 shocks
var shocks: int                          # runtime count

var shock_timer: Timer

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

const LightningStrike = preload("res://Scripts/LightningStrike.gd")

var facing_right: bool = false
var is_attacking:  bool = false
var health:        int  = 0
var is_dead:       bool = false

# Separate cooldown timers
var dog_cooldown_timer: Timer
var merc_cooldown_timer: Timer

@onready var dog_sfx      := $DogSfx          as AudioStreamPlayer2D
@onready var merc_sfx     := $MercSfx         as AudioStreamPlayer2D
@onready var jump_sfx     := $JumpSfx         as AudioStreamPlayer2D
@onready var hurt_sfx     := $HurtSfx         as AudioStreamPlayer2D
@onready var levelup_sfx  := $LevelUpSfx      as AudioStreamPlayer2D
@onready var empty_sfx    := $EmptyClickSfx   as AudioStreamPlayer2D
@onready var dash_sfx     := $DashSfx         as AudioStreamPlayer2D
@onready var panther_sfx  := $PantherSfx      as AudioStreamPlayer2D

@onready var levelup_voice_sfx  := $LevelUpVoiceSfx      as AudioStreamPlayer2D

@onready var glow_mat := $AnimatedSprite2D.material as ShaderMaterial

@onready var hitbox          := $Hitbox as Area2D
@onready var _star_timer := Timer.new()

const ShockEffectScene = preload("res://Scenes/Sprites/shock_effect.tscn")
@onready var shock_effect = ShockEffectScene.instantiate()

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
const DROP_THROUGH_TIME := 0.1

@export var extra_spawn_offset: float = 16.0  # tweak-able in the inspector

var on_roof: bool = false
var _left_roof: bool = false

# -- near your other exports --
@export var dog_base_damage: int          = 3
@export var dog_damage_per_level: int     = 2
@export var merc_base_damage: int         = 5
@export var merc_damage_per_level: int    = 2

const MechScene = preload("res://Scenes/Meks_Scenes/PLAYER/M1.scn")
const MechScene_Panther = preload("res://Scenes/Meks_Scenes/PLAYER/M2.scn")

@export var mech_cooldown: float         = 10.0
@export var mech_base_damage: int       = 10
@export var mech_damage_per_level: int  = 5
var mech_cooldown_timer: Timer

@export var mech_panther_cooldown: float         = 10.0
@export var mech_panther_base_damage: int       = 10
@export var mech_panther_damage_per_level: int  = 5
var mech_panther_cooldown_timer: Timer

const CLIMB_DEADZONE: float = 0.2
const GrappleScene = preload("res://Scenes/Sprites/grapple_hook.tscn")

var _on_sidewalk := false
var _floor_exceptions := []

var _on_street   : bool = false
var _sidewalk_exceptions := []

const LAYER_Z_FLOOR    := 0
const LAYER_Z_SIDEWALK := 2
const LAYER_Z_STREET   := 4

func _ready() -> void:	
	$AnimatedSprite2D.z_index = LAYER_Z_FLOOR
	
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
	dog_cooldown_timer.wait_time = 20.0
	dog_cooldown_timer.one_shot  = true
	add_child(dog_cooldown_timer)

	merc_cooldown_timer = Timer.new()
	merc_cooldown_timer.wait_time = 20.0
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
	
	shock_timer = Timer.new()
	shock_timer.wait_time = shock_cooldown
	shock_timer.one_shot  = true
	add_child(shock_timer)	

	mech_cooldown_timer = Timer.new()
	mech_cooldown_timer.wait_time = mech_cooldown
	mech_cooldown_timer.one_shot  = true
	add_child(mech_cooldown_timer)

	mech_panther_cooldown_timer = Timer.new()
	mech_panther_cooldown_timer.wait_time = mech_cooldown
	mech_panther_cooldown_timer.one_shot  = true
	add_child(mech_panther_cooldown_timer)

	Playerstats.connect("level_changed", Callable(self, "_on_player_leveled"))
	
	grenade_damage = initial_grenade_damage
	mine_damage    = initial_mine_damage

	# Configure a reusable star-power timer
	_star_timer.one_shot = true
	add_child(_star_timer)
	_star_timer.connect("timeout", Callable(self, "_on_star_timeout"))

	shocks = initial_shocks
	add_child(shock_effect)
	shock_effect.visible = false

	await get_tree().create_timer(1).timeout
	Playerstats.set_level(1)
	
	# start on floor by default:
	$AnimatedSprite2D.z_index = LAYER_Z_FLOOR
	
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# ——— ignore collisions with any zombie off our layer ———
	for z in get_tree().get_nodes_in_group("Zombie"):
		if not (z is PhysicsBody2D):
			continue
		# if the zombie’s layer (z_index) differs from ours, skip collision
		if z.z_index != $AnimatedSprite2D.z_index:
			add_collision_exception_with(z)
		else:
			remove_collision_exception_with(z)

	# ——— Step-down from Sidewalk to Street ———
	if _on_sidewalk \
	   and Input.is_action_pressed("ui_down") \
	   and Input.is_action_just_pressed("jump"):

		_drop_to_street()
		return

	# ——— Step-down … ———
	if is_on_floor() \
	   and Input.is_action_pressed("ui_down") \
	   and Input.is_action_just_pressed("jump"):

		# only if you’re on a pure “floor”
		var on_main = false
		for i in range(get_slide_collision_count()):
			var col = get_slide_collision(i)
			if col and col.get_collider().is_in_group("Floor") \
				   and not col.get_collider().is_in_group("Sidewalk"):
				on_main = true
				break
		if on_main:
			_drop_to_sidewalk()
			return

	# ——— Step-up: Street → Sidewalk, or Sidewalk → Floor ———
	if _on_street \
	   and Input.is_action_pressed("ui_up") \
	   and Input.is_action_just_pressed("jump"):

		_climb_up_to_sidewalk()
		return

	if _on_sidewalk \
	   and Input.is_action_pressed("ui_up") \
	   and Input.is_action_just_pressed("jump"):

		_climb_up_to_floor()
		return
					
	# —————————————————— KNOCKBACK HANDLING ——————————————————
	if _knockback_time_left > 0.0:
		_knockback_time_left -= delta
		# gravity still applies
		velocity.y += gravity * delta
		# slide with current velocity, ignore all other input
		move_and_slide()
		return
		
	# ——— Summon Dog or Mech ———
	if Input.is_action_just_pressed("dog"):
		if Input.is_action_pressed("ui_down") and mech_cooldown_timer.is_stopped():
			_spawn_mech()
			mech_cooldown_timer.start()
			Playerstats.emit_signal("mech_used")
		elif dog_cooldown_timer.is_stopped():
			_spawn_dog()
			dog_cooldown_timer.start()
			Playerstats.emit_signal("dog_used")

	# ——— Summon Merc or Mech Panther ———
	if Input.is_action_just_pressed("merc"):
		if Input.is_action_pressed("ui_down") and mech_panther_cooldown_timer.is_stopped():
			_spawn_mech_panther()
			mech_panther_cooldown_timer.start()
			Playerstats.emit_signal("panther_used")
		elif merc_cooldown_timer.is_stopped():
			_spawn_merc()
			merc_cooldown_timer.start()
			Playerstats.emit_signal("merc_used")

	if on_roof and Input.is_action_just_pressed("shock") and shock_timer.is_stopped():
		_perform_roof_shock()
			
	# ——— Roof‐only grapple override ———
	if on_roof:
		if Input.is_action_just_pressed("mine"):
			_shoot_grapple()
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

	if can_move \
	   and is_on_floor() \
	   and not Input.is_action_pressed("ui_down") \
	   and Input.is_action_just_pressed("jump"):
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

func _climb_up_to_sidewalk() -> void:
	$CollisionShape2D.disabled = true

	# find nearest Sidewalk above
	var best_surf: Node2D
	var best_dy = INF
	for sw in get_tree().get_nodes_in_group("Sidewalk"):
		if sw is Node2D:
			var dy = global_position.y - sw.global_position.y
			if dy > 0 and dy < best_dy:
				best_dy = dy
				best_surf = sw
	if best_surf:
		global_position.y = best_surf.global_position.y

	await get_tree().create_timer(0.1).timeout
	$CollisionShape2D.disabled = false

	# remove those sidewalk exceptions
	for sw in _sidewalk_exceptions:
		if is_instance_valid(sw):
			remove_collision_exception_with(sw)
	_sidewalk_exceptions.clear()

	_on_street   = false
	_on_sidewalk = true
	$AnimatedSprite2D.z_index = LAYER_Z_SIDEWALK

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

### Helper to prevent collisions between all ally summons
func _add_ally_exceptions(body: PhysicsBody2D) -> void:
	for grp in ["Dog", "Merc", "Mech", "MechPanther"]:
		for other in get_tree().get_nodes_in_group(grp):
			if other is PhysicsBody2D and other != body:
				body.add_collision_exception_with(other)
				other.add_collision_exception_with(body)
# Add this helper at the top of your Soldier.gd (or wherever these lives):
func _get_spawn_offset_x() -> float:
	# Dogs and Mechs on the left  => return negative offset
	# Mercs and Panthers on the right => return positive offset
	# We'll pass in a “side” parameter when calling if we need to reverse.
	return abs(muzzle_point.position.x) + extra_spawn_offset

### Spawn Dog (always left)
func _spawn_dog() -> void:
	dog_sfx.play()
	var dog = DogScene.instantiate() as PhysicsBody2D
	dog.add_to_group("Dog")
	var lvl = Playerstats.level
	if dog.has_meta("attack_damage"):
		dog.attack_damage = dog_base_damage + (lvl - 1) * dog_damage_per_level

	var x_off = _get_spawn_offset_x()
	dog.global_position = Vector2(
		global_position.x - x_off,  # left
		global_position.y + muzzle_point.position.y
	)
	get_tree().get_current_scene().add_child(dog)
	if on_roof or _left_roof:
		_add_roof_exceptions(dog)
	_add_ally_exceptions(dog)

	var base_duration = 5.0
	var extra_per_level = 1.0
	var life_delay = base_duration + (lvl - 1) * extra_per_level
	_fade_and_free(dog, life_delay, 1.0)

### Spawn Mech (always left)
func _spawn_mech() -> void:
	merc_sfx.play()
	var mech = MechScene.instantiate() as PhysicsBody2D
	mech.add_to_group("Mech")
	var lvl = Playerstats.level
	if mech.has_meta("attack_damage"):
		mech.attack_damage = mech_base_damage + (lvl - 1) * mech_damage_per_level

	var x_off = _get_spawn_offset_x()
	mech.global_position = Vector2(
		global_position.x - x_off,  # left
		global_position.y + muzzle_point.position.y
	)
	get_tree().get_current_scene().add_child(mech)
	var sprite = mech.get_node("AnimatedSprite2D") as AnimatedSprite2D
	sprite.flip_h = not facing_right
	if on_roof or _left_roof:
		_add_roof_exceptions(mech)
	_add_ally_exceptions(mech)

	var base_duration = 8.0
	var extra_per_level = 2.0
	var life_time = base_duration + (lvl - 1) * extra_per_level
	_fade_and_free(mech, life_time, 1.0)

### Spawn Merc (always right)
func _spawn_merc() -> void:
	merc_sfx.play()
	var merc = MercScene.instantiate() as PhysicsBody2D
	merc.add_to_group("Merc")
	var lvl = Playerstats.level
	if merc.has_meta("attack_damage"):
		merc.attack_damage = merc_base_damage + (lvl - 1) * merc_damage_per_level

	var x_off = _get_spawn_offset_x()
	merc.global_position = Vector2(
		global_position.x + x_off,  # right
		global_position.y + muzzle_point.position.y
	)
	get_tree().get_current_scene().add_child(merc)
	if on_roof or _left_roof:
		_add_roof_exceptions(merc)
	_add_ally_exceptions(merc)

	var base_duration = 5.0
	var extra_per_level = 1.0
	var life_delay = base_duration + (lvl - 1) * extra_per_level
	_fade_and_free(merc, life_delay, 1.0)

### Spawn Mech Panther (always right)
func _spawn_mech_panther() -> void:
	panther_sfx.play()
	var pan = MechScene_Panther.instantiate() as PhysicsBody2D
	pan.add_to_group("MechPanther")
	var lvl = Playerstats.level
	if pan.has_meta("attack_damage"):
		pan.attack_damage = mech_panther_base_damage + (lvl - 1) * mech_panther_damage_per_level

	var x_off = _get_spawn_offset_x()
	pan.global_position = Vector2(
		global_position.x + x_off,  # right
		global_position.y + muzzle_point.position.y
	)
	get_tree().get_current_scene().add_child(pan)
	var sprite = pan.get_node("AnimatedSprite2D") as AnimatedSprite2D
	sprite.flip_h = facing_right == false
	if on_roof or _left_roof:
		_add_roof_exceptions(pan)
	_add_ally_exceptions(pan)

	var base_duration = 8.0
	var extra_per_level = 2.0
	var life_time = base_duration + (lvl - 1) * extra_per_level
	_fade_and_free(pan, life_time, 1.0)

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
	# reduce cooldown by 15% per level, but never below 0.1s
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

	# buff all live mechs:
	for m in get_tree().get_nodes_in_group("Mech"):
		if m.has_meta("attack_damage"):
			m.attack_damage = mech_base_damage + (new_level - 1) * mech_damage_per_level

	print("Level ", new_level, 
		  " → mine cooldown: ", mine_cooldown)
		
	print("Leveled to ", new_level, " → new firerate: ", firerate)
	play_level_up_effect()
	levelup_sfx.play()
	#levelup_voice_sfx.play()
	
	# spawn a yellow bolt on the player
	var bolt = LightningStrike.new()
	# tint it yellow
	bolt.line_color = Color(1, 1, 0)
	# shorter fade so it feels snappier on level-up
	bolt.flash_time = 0.3
	# parent into the world
	get_tree().get_current_scene().add_child(bolt)
	# fire at the player's position (damage=0 since it's just FX)
	bolt.fire(global_position, 0)
	
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

	# 1) Castlevania-style knockback
	var dir = -1 if facing_right else 1
	velocity = Vector2(dir * knockback_speed, knockback_upward)

	# 2) start the timer
	_knockback_time_left = knockback_duration

	# 3) Hurt effects
	hurt_sfx.play()
	flash()

	# 4) subtract health
	Playerstats.damage(amount)
	if Playerstats.health <= 0:
		die()

func die() -> void:
	# disable further logic
	is_dead = true
	$DeathSfx.play()
	
	# ——— bullet-time kick in ———
	Engine.time_scale = 0.2

	# blood + sound
	$Blood.emitting = true

	# play death animation
	anim.play("death")
	
	# Castlevania knock-back: backwards relative to facing, and up
	var dir = -1 if facing_right else 1
	var push_vec = Vector2(dir * 30, -30)

	# Tween: fly up & back, then fall down
	var tw = create_tween()
	tw.tween_property(self, "global_position", global_position + push_vec, 0.3) \
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position", global_position + push_vec + Vector2(0, 30), 0.7) \
	  .set_delay(0.3) \
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished

	# ——— restore normal time ———
	Engine.time_scale = 1.0

	# pause, then game over
	await get_tree().create_timer(0).timeout
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
	# ——— bullet-time kick in ———
	Engine.time_scale = 0.2
	
	# turn on your shader’s “active” uniform
	glow_mat.set_shader_parameter("active", true)
	$LevelUp.emitting = true
	# wait however long you want the glow to last
	await get_tree().create_timer(0.5).timeout
	# turn it off again
	glow_mat.set_shader_parameter("active", false)

	# ——— restore normal time ———
	Engine.time_scale = 1.0

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

func _shoot_grapple() -> void:
	var hook = GrappleScene.instantiate()
	hook.global_position = muzzle_point.global_position
	hook.player = self
	hook.rope_active = true
	get_tree().get_current_scene().add_child(hook)

func _perform_roof_shock() -> void:
	if Playerstats.shocks <= 0:
		empty_sfx.play()    # or some “no ammo” feedback
		return

	Playerstats.use_shock()

	shock_timer.start()
	shock_effect.visible = true
	var mat = shock_effect.get_node("ColorRect").material as ShaderMaterial
	mat.set_shader_parameter("time",             0.0)
	mat.set_shader_parameter("glitch_intensity", 0.3)
	mat.set_shader_parameter("glitch_speed",     5.0)
	mat.set_shader_parameter("slice_count",      50.0)

	var tw = create_tween()
	tw.tween_property(mat, "shader_parameter/time", 1.0, 0.5)
	tw.tween_callback(Callable(self, "_hide_shock_effect"))

	for z in get_tree().get_nodes_in_group("Zombie"):
		if not (z is CharacterBody2D) or not is_instance_valid(z):
			continue
		var to_z = z.global_position - global_position
		if to_z.length() <= shock_radius:
			if z.has_method("take_damage"):
				z.take_damage(shock_damage)
			z.velocity = to_z.normalized() * shock_knockback

func _hide_shock_effect() -> void:
	shock_effect.visible = false

func _drop_to_sidewalk() -> void:
	# disable your own collider so you pass through
	$CollisionShape2D.disabled = true

	# snap you down to the nearest sidewalk Y
	var best_sw: Node2D
	var best_dy = INF
	for sw in get_tree().get_nodes_in_group("Sidewalk"):
		if sw is Node2D:
			var dy = sw.global_position.y - global_position.y
			if dy > 0 and dy < best_dy:
				best_dy = dy
				best_sw = sw
	if best_sw:
		global_position.y = best_sw.global_position.y

	# now re-enable collision…
	await get_tree().create_timer(0.1).timeout
	$CollisionShape2D.disabled = false

	# and tell the player to ignore all pure‐floor bodies
	_on_sidewalk = true
	$AnimatedSprite2D.z_index = 2
	_floor_exceptions.clear()
	for f in get_tree().get_nodes_in_group("Floor"):
		if not f.is_in_group("Sidewalk") and f is PhysicsBody2D:
			add_collision_exception_with(f)
			_floor_exceptions.append(f)

# (optional) if you ever let the player step back up…
func _climb_up_to_floor() -> void:
	# 1) Temporarily disable your collider so you pass through the sidewalk
	$CollisionShape2D.disabled = true

	# 2) Find the nearest “floor” (not tagged Sidewalk) **above** you
	var best_floor: Node2D = null
	var best_dy = INF
	for f in get_tree().get_nodes_in_group("Floor"):
		if not f.is_in_group("Sidewalk") and f is Node2D:
			var dy = global_position.y - f.global_position.y
			if dy > 0 and dy < best_dy:
				best_dy = dy
				best_floor = f

	# 3) Snap your Y to that floor
	if best_floor:
		global_position.y = best_floor.global_position.y

	# 4) Wait a hair, then re-enable collisions
	await get_tree().create_timer(0.1).timeout
	$CollisionShape2D.disabled = false

	# 5) Clear out all the “ignore floor” exceptions we added on drop-through
	for floor_body in _floor_exceptions:
		if is_instance_valid(floor_body):
			remove_collision_exception_with(floor_body)
	_floor_exceptions.clear()

	# 6) Mark that you’re no longer on the sidewalk
	_on_sidewalk = false
	$AnimatedSprite2D.z_index = LAYER_Z_FLOOR

func _drop_to_street() -> void:
	$CollisionShape2D.disabled = true

	# snap down to nearest Street
	var best_surf: Node2D
	var best_dy = INF
	for st in get_tree().get_nodes_in_group("Street"):
		if st is Node2D:
			var dy = st.global_position.y - global_position.y
			if dy > 0 and dy < best_dy:
				best_dy = dy
				best_surf = st
	if best_surf:
		global_position.y = best_surf.global_position.y

	await get_tree().create_timer(0.1).timeout
	$CollisionShape2D.disabled = false

	_on_street = true
	$AnimatedSprite2D.z_index = LAYER_Z_STREET   # draw above Floor+Sidewalk
	_sidewalk_exceptions.clear()
	for sw in get_tree().get_nodes_in_group("Sidewalk"):
		if sw is PhysicsBody2D:
			add_collision_exception_with(sw)
			_sidewalk_exceptions.append(sw)
