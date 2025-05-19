# ZombieSpawner.gd
extends Node2D

@export var base_spawn_interval: float = 5.0   # seconds at level 1
@export var min_spawn_factor:    float = 0.2   # never faster than 20% of base
@export var spawn_distance:      float = 200.0

@export var boss_scene:   PackedScene
@export var zombie_scene: PackedScene

var spawn_interval: float
var _spawn_timer:    Timer

func _ready() -> void:
	spawn_interval = base_spawn_interval

	_spawn_timer = Timer.new()
	_spawn_timer.wait_time  = spawn_interval
	_spawn_timer.one_shot   = false
	_spawn_timer.autostart  = true
	add_child(_spawn_timer)
	_spawn_timer.timeout.connect(spawn_zombie)

	Playerstats.connect("level_changed", Callable(self, "_on_level_changed"))

func spawn_zombie() -> void:
	var players = get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		return
	var player = players[0] as Node2D

	# spawn position logic…
	var side: int
	if (randi() & 1) == 0:
		side = -1
	else:
		side = 1
		
	var spawn_pos = Vector2(player.global_position.x + side * spawn_distance,
							global_position.y)

	var z = zombie_scene.instantiate() as CharacterBody2D
	z.global_position = spawn_pos

	# decide archetype *probabilistically*:
	var lvl  = Playerstats.level
	var roll = randf()  # [0,1)
	
	if lvl >= 5:
		# Level 8+: 30% chain, 25% spore, 20% charger, 25% vanilla
		if roll < 0.30:
			z.behavior = "chain"
			z.get_node("AnimatedSprite2D").material = preload("res://Shaders/ChainEffect.tres")
		elif roll < 0.55:
			z.behavior = "spore"
			z.get_node("AnimatedSprite2D").material = preload("res://Shaders/SporeEffect.tres")
		elif roll < 0.75:
			z.behavior = "charger"
			z.get_node("AnimatedSprite2D").material = preload("res://Shaders/ChargerEffect.tres")
		else:
			z.behavior = ""
	elif lvl >= 4:
		# Level 5–7: 25% spore, 20% charger, 55% vanilla
		if roll < 0.25:
			z.behavior = "spore"
			z.get_node("AnimatedSprite2D").material = preload("res://Shaders/SporeEffect.tres")
		elif roll < 0.45:
			z.behavior = "charger"
			z.get_node("AnimatedSprite2D").material = preload("res://Shaders/ChargerEffect.tres")
		else:
			z.behavior = ""
	elif lvl >= 3:
		# Level 3–4: 20% charger, 80% vanilla
		if roll < 0.20:
			z.behavior = "charger"
			z.get_node("AnimatedSprite2D").material = preload("res://Shaders/ChargerEffect.tres")
		else:
			z.behavior = ""
	else:
		# below level 3: always vanilla
		z.behavior = ""
		
	# then your health‐scaling, grouping, etc.
	if lvl > 1 and z.has_method("take_damage"):
		var base  = z.max_health
		var scale = pow(1.40, lvl - 1)
		z.max_health = int(base * scale)
		z.health     = z.max_health

	if not z.is_in_group("Zombie"):
		z.add_to_group("Zombie")
	get_tree().get_current_scene().add_child(z)
	print("Spawned [", z.behavior, "] zombie at ", spawn_pos, " (health=", z.max_health, ")")

func _on_level_changed(new_level: int) -> void:
	# 10% faster per level, but never below min_spawn_factor
	var raw_factor = 1.0 - (new_level - 1) * 0.10
	var clamped    = clamp(raw_factor, min_spawn_factor, 1.0)
	spawn_interval = base_spawn_interval * clamped

	_spawn_timer.wait_time = spawn_interval
	print("Level ", new_level, " → spawn interval ", spawn_interval, "s")

	if boss_scene:
		_spawn_boss()

	for z in get_tree().get_nodes_in_group("Zombie"):
		if z is CharacterBody2D and z.has_method("take_damage"):
			z.max_health += 1
			z.health = min(z.health + 1, z.max_health)
	print("All zombies gained +1 max health (level ", new_level, ")")


func _spawn_boss() -> void:
	var players = get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		return
	var player = players[0] as Node2D

	var side: int
	if (randi() & 1) == 0:
		side = -1
	else:
		side = 1
		
	var spawn_pos = Vector2(
		player.global_position.x + side * spawn_distance,
		global_position.y
	)

	# instantiate the boss
	var boss = boss_scene.instantiate() as CharacterBody2D
	boss.global_position = Vector2(
		player.global_position.x + side * spawn_distance * 1.5,
		global_position.y
	)

	# scale boss health by level (e.g. +50% per level)
	var lvl = Playerstats.level
	if lvl > 1 and boss.has_method("take_damage"):
		var base = boss.max_health
		var scale = pow(1.50, lvl - 1)     # 1.50 == +50% per level
		boss.max_health = int(base * scale)
		boss.health     = boss.max_health

	if not boss.is_in_group("Zombie"):
		boss.add_to_group("Zombie")
	get_tree().get_current_scene().add_child(boss)
	print("Boss spawned for level ", lvl, " with max_health=", boss.max_health)
