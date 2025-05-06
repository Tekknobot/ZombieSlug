# Zombie.gd
extends CharacterBody2D

@export var xp_award: int         = 5
@export var min_speed: float      = 25.0
@export var max_speed: float      = 75.0
@export var attack_range: float   = 32.0
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

	var players = get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		if not attack_timer.is_stopped():
			attack_timer.stop()
		return

	var player = players[0] as CharacterBody2D
	var to_player = player.global_position - global_position
	var dist = to_player.length()

	if dist > attack_range:
		velocity.x = sign(to_player.x) * speed
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
		anim.flip_h = to_player.x > 0

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	move_and_slide()

func _on_attack_timeout() -> void:
	for p in get_tree().get_nodes_in_group("Player"):
		if p.has_method("take_damage"):
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
		
		# 2) death animation + delay + free
		anim.play("death")
		await get_tree().create_timer(0.5).timeout
		queue_free()

# Briefly tint the sprite red, then restore
func flash() -> void:
	var orig = anim.modulate
	anim.modulate = Color(1, 0, 0, 1)
	await get_tree().create_timer(0.1).timeout
	anim.modulate = orig
