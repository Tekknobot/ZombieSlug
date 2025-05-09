# res://Scripts/FirestormController.gd
extends Node2D

@export var duration:             float = 2.0   # how long the storm lasts
@export var interval:             float = 0.2   # seconds between each volley
@export var strikes_per_interval: int   = 3     # bolts per volley
@export var damage:               int   = 3     # damage per bolt
@export var radius:               float = 48.0  # how far from center bolts can strike
@export var sfx_stream:           AudioStream     # assign a firestorm SFX here

const ExplosionScene = preload("res://Scenes/Effects/Explosion.tscn")

var _timer:     Timer
var _elapsed:   float = 0.0
var _sfx_player: AudioStreamPlayer2D

func _ready() -> void:
	# 1) set up repeating timer
	_timer = Timer.new()
	_timer.wait_time = interval
	_timer.one_shot  = false
	add_child(_timer)
	_timer.connect("timeout", Callable(self, "_on_timer_timeout"))
	_timer.start()
	set_process(true)

	# 2) optional SFX player
	if sfx_stream:
		_sfx_player = AudioStreamPlayer2D.new()
		_sfx_player.stream = sfx_stream
		add_child(_sfx_player)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		_timer.stop()
		queue_free()

func _on_timer_timeout() -> void:
	# play the storm sfx (one shot per volley)
	if _sfx_player:
		_sfx_player.play()

	# snapshot of all alive zombies
	var zombies = get_tree().get_nodes_in_group("Zombie").filter( func(z):
		return z is CharacterBody2D and z.is_inside_tree()
	)

	# fire off up to strikes_per_interval random bolts
	for i in range(strikes_per_interval):
		if zombies.is_empty():
			break

		# pick one target and remove it from the list
		var idx = randi() % zombies.size()
		var z   = zombies[idx]
		zombies.remove_at(idx)

		# choose a random strike position around the controller center
		var angle = randf() * TAU
		var pos   = global_position + Vector2(cos(angle), sin(angle)) * radius

		# spawn explosion effect
		var exp = ExplosionScene.instantiate()
		exp.global_position = pos
		get_tree().get_current_scene().add_child(exp)

		# deal damage to that specific zombie if it’s in range
		if is_instance_valid(z) and z.global_position.distance_to(pos) < 16.0:
			z.take_damage(damage)
