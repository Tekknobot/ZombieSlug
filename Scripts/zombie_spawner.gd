# ZombieSpawner.gd
extends Node2D

@export var base_spawn_interval: float = 5.0   # seconds at level 1
@export var min_spawn_factor:    float = 0.2   # never faster than 20% of base
@export var spawn_distance:      float = 200.0

@export var boss_scene:   PackedScene
@export var zombie_scene: PackedScene

var spawn_interval: float
var _spawn_timer:    Timer

@export var sidewalk_chance := 0.5  # 50/50 with the main floor

@export var max_zombies: int = 750

var _zombie_pool: Array[CharacterBody2D] = []
@export var street_chance: float = 0.4   # e.g. 40% of the time

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
	# ——— Don’t spawn if we already have ≥ max_zombies ———
	var current = get_tree().get_nodes_in_group("Zombie").size()
	if current >= max_zombies:
		return

	# ——— Ensure there’s a player to target ———
	var players = get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		return
	var player = players[0] as Node2D

	# ——— Determine spawn type: sidewalk, street, or floor ———
	var r = randf()
	var spawn_type: String
	if r < sidewalk_chance:
		spawn_type = "sidewalk"
	elif r < sidewalk_chance + street_chance:
		spawn_type = "street"
	else:
		spawn_type = "floor"

	# define the exact layer for each type
	var layer_map = {
		"floor":    0,
		"sidewalk": 2,
		"street":   4
	}

	# ——— Gather surfaces based on spawn_type ———
	var surfaces: Array = []
	if spawn_type == "sidewalk":
		surfaces = get_tree().get_nodes_in_group("Sidewalk")
	elif spawn_type == "street":
		surfaces = get_tree().get_nodes_in_group("Street")
	else:
		for f in get_tree().get_nodes_in_group("Floor"):
			if not f.is_in_group("Sidewalk"):
				surfaces.append(f)

	# ——— Bail if no surfaces found ———
	if surfaces.is_empty():
		if spawn_type == "sidewalk":
			push_warning("No Sidewalk surfaces to spawn on")
		elif spawn_type == "street":
			push_warning("No Street surfaces to spawn on")
		else:
			push_warning("No Floor surfaces to spawn on")
		return

	# ——— Pick a random surface ———
	var pick_index = randi() % surfaces.size()
	var surf = surfaces[pick_index] as Node2D

	# ——— Instantiate zombie and position it on the chosen surface ———
	var z = zombie_scene.instantiate() as CharacterBody2D
	# Y = surface height
	z.global_position.y = surf.global_position.y
	
	# ——— put this right after you pick surf ———
	# align the zombie’s z_index to the surface’s, +1 so it draws on top
	z.z_index = layer_map[spawn_type]
	# ——— then add to scene as normal ———
	get_tree().get_current_scene().add_child(z)
	
	# X = player.x ± spawn_distance (choose side without ternary)
	var side_val: int
	if randf() < 0.5:
		side_val = -1
	else:
		side_val = 1
	z.global_position.x = player.global_position.x + side_val * spawn_distance

	# ——— Add to scene ———
	get_tree().get_current_scene().add_child(z)

	# ——— Collision exceptions so zombie falls onto the correct layer ———
	if spawn_type == "sidewalk":
		for f in get_tree().get_nodes_in_group("Floor"):
			if not f.is_in_group("Sidewalk") and f is PhysicsBody2D:
				z.add_collision_exception_with(f)
	elif spawn_type == "street":
		# fall through sidewalks
		for sw in get_tree().get_nodes_in_group("Sidewalk"):
			if sw is PhysicsBody2D:
				z.add_collision_exception_with(sw)
		# fall through floors that aren’t sidewalks
		for f in get_tree().get_nodes_in_group("Floor"):
			if not f.is_in_group("Sidewalk") and f is PhysicsBody2D:
				z.add_collision_exception_with(f)
	# (floor spawns land directly, no exceptions needed)

	# ——— Decide archetype probabilistically ———
	var lvl = Playerstats.level
	var roll = randf()
	if lvl >= 5:
		if roll < 0.30:
			z.behavior = "chain"
			z.get_node("AnimatedSprite2D").material = preload("res://Shaders/ChainEffect.tres")
		elif roll < 0.55:
			z.behavior = "spore"
			z.get_node("AnimatedSprite2D").material = preload("res://Shaders/SporeEffect.tres")
		elif roll < 0.75:
			z.behavior = "charger"
			z.get_node("AnimatedSprite2D").material = preload("res://Shaders/ChargerEffect.tres")
		elif roll < 0.95:
			z.behavior = ""
		else:
			z.behavior = "shield"
			z.get_node("AnimatedSprite2D").material = preload("res://Shaders/ShieldEffect.tres")
			z.add_to_group("Shield")
	elif lvl >= 4:
		if roll < 0.25:
			z.behavior = "spore"
			z.get_node("AnimatedSprite2D").material = preload("res://Shaders/SporeEffect.tres")
		elif roll < 0.45:
			z.behavior = "charger"
			z.get_node("AnimatedSprite2D").material = preload("res://Shaders/ChargerEffect.tres")
		elif roll < 0.65:
			z.behavior = ""
		else:
			z.behavior = "shield"
			z.get_node("AnimatedSprite2D").material = preload("res://Shaders/ShieldEffect.tres")
			z.add_to_group("Shield")
	elif lvl >= 3:
		if roll < 0.20:
			z.behavior = "charger"
			z.get_node("AnimatedSprite2D").material = preload("res://Shaders/ChargerEffect.tres")
		elif roll < 0.40:
			z.behavior = ""
		else:
			z.behavior = "shield"
			z.get_node("AnimatedSprite2D").material = preload("res://Shaders/ShieldEffect.tres")
			z.add_to_group("Shield")
	elif lvl >= 2:
		if roll < 0.20:
			z.behavior = "shield"
			z.get_node("AnimatedSprite2D").material = preload("res://Shaders/ShieldEffect.tres")
			z.add_to_group("Shield")
		else:
			z.behavior = ""
	else:
		z.behavior = ""

	# ——— Scale health for level and add to group ———
	if lvl > 1 and z.has_method("take_damage"):
		var base_health = z.max_health
		var scale = pow(1.40, lvl - 1)
		z.max_health = int(base_health * scale)
		z.health = z.max_health

	if not z.is_in_group("Zombie"):
		z.add_to_group("Zombie")

	# ——— Debug log ———
	print("Spawned [", z.behavior, "] zombie at ", z.global_position, " (health=", z.max_health, ")")

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
