# res://Scripts/FirestormController.gd
extends Node2D

@export var duration:             float = 2.0    # how long the storm lasts
@export var interval:             float = 0.2    # seconds between each volley
@export var strikes_per_interval: int   = 3      # bolts per volley
@export var damage:               int   = 9999   # damage per bolt
@export var radius:               float = 48.0   # max radius for random blasts
@export var sfx_stream:           AudioStream             # optional storm SFX

const ExplosionScene = preload("res://Scenes/Effects/Explosion.tscn")

var _timer:      Timer
var _elapsed:    float = 0.0
var _sfx_player: AudioStreamPlayer2D

func _ready() -> void:
	# 1) set up repeating volley timer
	_timer = Timer.new()
	_timer.wait_time = interval
	_timer.one_shot  = false
	add_child(_timer)
	_timer.connect("timeout", Callable(self, "_on_timer_timeout"))
	_timer.start()
	
	# 2) optional SFX player
	if sfx_stream:
		_sfx_player = AudioStreamPlayer2D.new()
		_sfx_player.stream = sfx_stream
		add_child(_sfx_player)
	
	set_process(true)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		_timer.stop()
		queue_free()

func _on_timer_timeout() -> void:
	# Play the storm SFX
	if _sfx_player:
		_sfx_player.play()

	# --- 1) Random radius explosions (may miss) ---
	for i in range(strikes_per_interval):
		var angle = randf() * TAU
		# random distance [0, radius]
		var dist  = randf() * radius
		var pos   = global_position + Vector2(cos(angle), sin(angle)) * dist
		
		var exp = ExplosionScene.instantiate()
		exp.global_position = pos
		exp.global_position.y -= 8
		get_tree().get_current_scene().add_child(exp)
	
	# --- 2) Guaranteed strikes on zombies in radius ---
	var zombies := []
	for z in get_tree().get_nodes_in_group("Zombie"):
		if z is CharacterBody2D and z.is_inside_tree():
			if z.global_position.distance_to(global_position) <= radius:
				zombies.append(z)
	
	# strike up to strikes_per_interval distinct zombies
	var to_strike = min(strikes_per_interval, zombies.size())
	for i in range(to_strike):
		var idx = randi() % zombies.size()
		var z   = zombies[idx]
		zombies.remove_at(idx)
		
		# explosion exactly at the zombie
		var exp_z = ExplosionScene.instantiate()
		exp_z.global_position = z.global_position
		get_tree().get_current_scene().add_child(exp_z)
		
		# deal damage
		if z.has_method("take_damage"):
			z.take_damage(damage)
