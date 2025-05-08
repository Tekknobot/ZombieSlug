# Soldier.gd
extends CharacterBody2D

@export var speed         := 200.0
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

const BulletScene = preload("res://Scenes/Sprites/bullet.tscn")
const DogScene    = preload("res://Scenes/Sprites/dog.tscn")
const MercScene   = preload("res://Scenes/Sprites/merc.tscn")
const GrenadeScene = preload("res://Scenes/Sprites/tnt.tscn")
const MineScene    = preload("res://Scenes/Sprites/mine.tscn")

var facing_right: bool = false
var is_attacking:  bool = false
var health:        int  = 0
var is_dead:       bool = false

@export var initial_firerate  := 0.6    # seconds between shots at level 1
var firerate: float

# Separate cooldown timers
var dog_cooldown_timer: Timer
var merc_cooldown_timer: Timer

@onready var dog_sfx      := $DogSfx       as AudioStreamPlayer2D
@onready var merc_sfx     := $MercSfx      as AudioStreamPlayer2D
@onready var jump_sfx     := $JumpSfx      as AudioStreamPlayer2D
@onready var hurt_sfx     := $HurtSfx      as AudioStreamPlayer2D
@onready var levelup_sfx     := $LevelUpSfx      as AudioStreamPlayer2D

@onready var glow_mat := $AnimatedSprite2D.material as ShaderMaterial

func _ready() -> void:
	# initialize firing rate
	firerate = initial_firerate
	
	# wire up level-change so we can speed up
	Playerstats.connect("level_changed", Callable(self, "_on_level_changed"))
			
	# initialize global stats to match this soldier
	Playerstats.max_health = max_health
	Playerstats.health     = max_health
	Playerstats.xp         = 0
	Playerstats.kills      = 0

	health = max_health
	print("Soldier health set to", health)

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


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Dog spawn on left
	if Input.is_action_just_pressed("dog") and dog_cooldown_timer.is_stopped():
		_spawn_dog()
		dog_cooldown_timer.start()

	# Merc spawn on right
	if Input.is_action_just_pressed("merc") and merc_cooldown_timer.is_stopped():
		_spawn_merc()
		merc_cooldown_timer.start()

	# (The rest of your gravity/attack/movement code stays exactly the same…)
	velocity.y += gravity * delta

	if Input.is_action_just_pressed("attack") and not is_attacking:
		_on_attack()

	if Input.is_action_just_pressed("grenade") and grenade_cooldown_timer.is_stopped():
		_throw_grenade()
		grenade_cooldown_timer.start()
 
	# only allow dropping a mine when the player is on the ground
	if is_on_floor() and Input.is_action_just_pressed("mine") and mine_cooldown_timer.is_stopped():
		_drop_mine()
		mine_cooldown_timer.start()
		
	var can_move := not is_attacking or not is_on_floor()
	var dir: float = 0.0
	if can_move:
		dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		velocity.x = dir * speed
	else:
		velocity.x = 0

	if dir != 0 and can_move:
		facing_right = dir > 0
		anim.flip_h  = facing_right
		var abs_off: float = abs(muzzle_point.position.x)
		if facing_right:
			muzzle_point.position.x = abs_off
		else:
			muzzle_point.position.x = -abs_off

	if can_move and is_on_floor() and Input.is_action_just_pressed("jump"):
		# play jump sound
		jump_sfx.play()
		
		velocity.y = jump_velocity

	self.velocity = velocity
	move_and_slide()

	if is_on_floor() and abs(velocity.y) < 1:
		velocity.y      = 0
		self.velocity.y = 0

	if not is_attacking:
		if not is_on_floor():
			anim.play("move")
		elif dir != 0:
			anim.play("move")
		else:
			anim.play("default")

# --- New spawn functions ---

func _spawn_dog() -> void:
	# play dog‐summon sound
	dog_sfx.play()
		
	var dog = DogScene.instantiate()
	# offset left by the muzzle_point's local X
	var x_off = abs(muzzle_point.position.x)
	dog.global_position = Vector2(
		global_position.x - x_off,
		global_position.y + muzzle_point.position.y
	)
	get_tree().get_current_scene().add_child(dog)
	print("🐶 Spawned dog at ", dog.global_position)
	_auto_free(dog, 5.0)

func _spawn_merc() -> void:
	# play merc‐summon sound
	merc_sfx.play()
		
	var merc = MercScene.instantiate()
	# offset right by the muzzle_point's local X
	var x_off = abs(muzzle_point.position.x)
	merc.global_position = Vector2(
		global_position.x + x_off,
		global_position.y + muzzle_point.position.y
	)
	get_tree().get_current_scene().add_child(merc)
	print("🪖 Spawned merc at ", merc.global_position)
	_auto_free(merc, 5.0)

# Helper to auto‐free any node after `duration` seconds
func _auto_free(node: Node, duration: float) -> void:
	var kill_timer = Timer.new()
	kill_timer.wait_time = duration
	kill_timer.one_shot  = true
	node.add_child(kill_timer)
	kill_timer.connect("timeout", Callable(node, "queue_free"))
	kill_timer.start()

func _on_attack() -> void:
	is_attacking = true
	anim.play("attack")
	fire_bullet()

	if is_on_floor():
		await get_tree().create_timer(firerate).timeout
	else:
		await _await_landing()

	is_attacking = false

func _on_level_changed(new_level: int) -> void:
	# Example: reduce interval by 10% each level, to a floor of 0.1s
	var factor = clamp(1.0 - (new_level - 1) * 0.50, 0.2, 1.0)
	firerate = initial_firerate * factor
	
	# *** new grenade cooldown code ***
	var gren_factor = clamp(1.0 - (new_level - 1) * 0.10, 0.2, 1.0)
	grenade_cooldown_timer.wait_time = initial_grenade_cooldown * gren_factor

	# --- mine cooldown reduction ---
	var mine_factor: float
	if new_level > 1:
		mine_factor = 1.0 - (new_level - 1) * 0.10
	else:
		mine_factor = 1.0
	# clamp to a minimum of 20% of original
	if mine_factor < 0.2:
		mine_factor = 0.2

	mine_cooldown = initial_mine_cooldown * mine_factor
	mine_cooldown_timer.wait_time = mine_cooldown

	print("Level ", new_level, 
		  " → mine cooldown: ", mine_cooldown)
		
	print("Leveled to ", new_level, " → new firerate: ", firerate)
	play_level_up_effect()
	levelup_sfx.play()

func _await_landing() -> void:
	while not is_on_floor():
		await get_tree().physics_frame

func fire_bullet() -> void:
	var bullet = BulletScene.instantiate()
	bullet.global_position = muzzle_point.global_position

	# no ternary: use explicit if/else
	if facing_right:
		bullet.direction = Vector2.RIGHT
	else:
		bullet.direction = Vector2.LEFT

	get_tree().get_current_scene().add_child(bullet)
	print("⚠️ Fired bullet at", bullet.global_position)

func take_damage(amount: int = 1) -> void:
	if is_dead:
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
	
	Playerstats.reset_stats()
	glow_mat.set_shader_parameter("active", false)
	
	queue_free()

func flash() -> void:
	anim.modulate = Color(1, 0, 0, 1)
	await get_tree().create_timer(0.1).timeout
	anim.modulate = Color(1, 1, 1, 1)

func _throw_grenade() -> void:
	var g = GrenadeScene.instantiate()
	# spawn at the muzzle or player hand
	g.global_position = global_position
	g.global_position.y -= 16
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
	get_tree().get_current_scene().add_child(m)
	print("💣 Dropped mine at", m.global_position)
