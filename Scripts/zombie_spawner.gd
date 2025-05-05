extends Node2D

@export var zombie_scene: PackedScene  # assign your Zombie scene (res://path_to/Zombie.tscn)
@export var spawn_interval: float = 5.0  # seconds between spawns
@export var spawn_distance: float = 200.0 # horizontal distance from player

# Internal timer
var _spawn_timer: Timer

func _ready() -> void:
	# Verify zombie_scene is assigned
	if zombie_scene == null:
		push_error("ZombieSpawner: 'zombie_scene' is not assigned!")
	# Create and configure the spawn timer
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.one_shot = false
	_spawn_timer.autostart = true
	add_child(_spawn_timer)
	_spawn_timer.timeout.connect(spawn_zombie)

func spawn_zombie() -> void:
	# Find the player
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() == 0:
		push_warning("ZombieSpawner: No Player found in group!")
		return
	var player = players[0] as Node2D

	# Choose left or right side randomly
	var side: int
	if randi() % 2 == 0:
		side = -1
	else:
		side = 1
	# Compute spawn position: horizontally offset, same Y as spawner
	var spawn_pos = Vector2(
		player.global_position.x + side * spawn_distance,
		global_position.y
	)

	# Instance and add the zombie
	var zombie = zombie_scene.instantiate()
	zombie.global_position = spawn_pos
	# Ensure zombie is in the 'Zombie' group for AI and collisions
	if not zombie.is_in_group("Zombie"):
		zombie.add_to_group("Zombie")
	get_tree().get_current_scene().add_child(zombie)

	# Optional: debug print
	print("Spawned zombie at", spawn_pos)
