# Interior.gd
# (Attach this to the root node of each interior scene, e.g. the top‐level Node2D.)

extends Node2D

# preload the Playerstats singleton (adjust the path to wherever your Playerstats.gd is)
@onready var Playerstats = get_node("/root/Playerstats")

# preload a Loot‐pickup scene (this can be a simple Area2D with a sprite/collision)
@export var LootPickupScene: PackedScene = preload("res://Scenes/Sprites/MoneyPickup.tscn")

# -- Tunable parameters for “kill target” --
@export var kills_per_level: int = 10  
# Above:  e.g.  kills_needed = level * kills_per_level

# (Optional) You could also add a bit of randomness, e.g. 0.8–1.2× the base. 
# @export var random_multiplier_min: float = 0.8
# @export var random_multiplier_max: float = 1.2

var _entry_kills: int
var _kill_goal: int
var _reward_dropped: bool = false

# When a zombie dies, we’ll write here:
var last_killed_zombie_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	# 1) Record how many total kills the player already has when stepping in:
	_entry_kills = Playerstats.kills
	
	# 2) Compute how many more kills are needed. For instance:
	#      kill_goal = Player Level × kills_per_level
	_kill_goal = Playerstats.level * kills_per_level
	
	# (Optionally, add a little random variance:)
	# var variance = randf_range(random_multiplier_min, random_multiplier_max)
	# _kill_goal = int(float(_kill_goal) * variance)
	
	_reward_dropped = false
	
	# 3) Connect to the Playerstats “kills_changed” signal so
	#    we can watch their total kills. Once they’ve done
	#    (_entry_kills + _kill_goal), we’ll drop loot.
	Playerstats.connect("kills_changed", Callable(self, "_on_kills_changed"))
	

func _on_kills_changed(new_total_kills: int) -> void:
	if _reward_dropped:
		return
	
	# How many kills have happened “inside” this interior?
	var kills_inside := new_total_kills - _entry_kills
	
	if kills_inside >= _kill_goal:
		_drop_multiple_rewards()
		#_reward_dropped = true
		# If you want to allow multiple drops across repeated entries,
		# reset _reward_dropped = false when the player leaves or re-enters.

		
func _drop_multiple_rewards() -> void:
	# 1) Decide how many to spawn. For example, 10 per player level:
	var total_to_drop = Playerstats.level * 10

	# 2) For each pickup, we’ll scatter it within ±20 pixels of the last zombie position.
	#    You can adjust that radius (±20) to taste so it looks natural.
	for i in range(total_to_drop):
		var loot = LootPickupScene.instantiate()
		
		# Generate a small random offset in x,y. Here: ±20 pixels.
		var scatter_radius := 32.0
		var offset := Vector2(
			(randf() * (scatter_radius * 2.0)) - scatter_radius,
			(randf() * (scatter_radius * 2.0)) - scatter_radius
		)
		
		loot.global_position = last_killed_zombie_pos + offset
		get_tree().get_current_scene().add_child(loot)
		
		# 2.5) Play a little “ding” or effect if you want:
		$RewardSfx.play()
			
		await get_tree().create_timer(0.2).timeout

	# 3) (Optional) You can show a message, particle burst, etc.
	#      _show_message("You found a cache of loot!")
