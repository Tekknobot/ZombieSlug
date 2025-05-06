# ZombieSpawner.gd
extends Node2D

@export var zombie_scene:    PackedScene  # assign your Zombie scene
@export var boss_scene:      PackedScene  # assign your Boss scene
@export var spawn_interval:  float = 5.0  # seconds between regular spawns
@export var spawn_distance:  float = 200.0# horizontal offset from player

var _spawn_timer: Timer

func _ready() -> void:
	if zombie_scene == null:
		push_error("ZombieSpawner: 'zombie_scene' is not assigned!")
	if boss_scene == null:
		push_warning("ZombieSpawner: 'boss_scene' is not assigned – no boss will spawn on level up.")

	# regular zombie spawns
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.one_shot = false
	_spawn_timer.autostart = true
	add_child(_spawn_timer)
	_spawn_timer.timeout.connect(spawn_zombie)

	# listen for level-up
	Playerstats.connect("level_changed", Callable(self, "_on_level_changed"))

func spawn_zombie() -> void:
	var players = get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		push_warning("ZombieSpawner: No Player found in group!")
		return
	var player = players[0] as Node2D

	# choose side without ternary
	var side: int
	if (randi() & 1) == 0:
		side = -1
	else:
		side = 1

	var spawn_pos = Vector2(
		player.global_position.x + side * spawn_distance,
		global_position.y
	)

	var zombie = zombie_scene.instantiate()
	zombie.global_position = spawn_pos
	if not zombie.is_in_group("Zombie"):
		zombie.add_to_group("Zombie")
	get_tree().get_current_scene().add_child(zombie)
	print("Spawned zombie at ", spawn_pos)

func _on_level_changed(new_level: int) -> void:
	if boss_scene == null:
		return

	var players = get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		return
	var player = players[0] as Node2D

	# choose side without ternary
	var side: int
	if (randi() & 1) == 0:
		side = -1
	else:
		side = 1

	var boss_pos = Vector2(
		player.global_position.x + side * spawn_distance * 1.5,
		global_position.y
	)

	var boss = boss_scene.instantiate()
	boss.global_position = boss_pos
	if not boss.is_in_group("Zombie"):
		boss.add_to_group("Zombie")
	get_tree().get_current_scene().add_child(boss)
	print("🦹‍♂️ Zombie Boss spawned at level ", new_level, " → ", boss_pos)
