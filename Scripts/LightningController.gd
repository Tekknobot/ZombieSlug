# res://Scripts/LightningController.gd
extends Node

@export var controller_name := "LightningController"

@onready var _timer := Timer.new()
var _elapsed := 0.0
var _duration := 0.0
var _interval := 0.0
var _strikes_per := 0
var _damage := 0

const LightningStrike = preload("res://Scripts/LightningStrike.gd")

func start(duration: float, interval: float, strikes_per_interval: int, damage: int) -> void:
	_duration = duration
	_interval = interval
	_strikes_per = strikes_per_interval
	_damage = damage

	# Timer to trigger each volley
	_timer.wait_time = _interval
	_timer.one_shot = false
	add_child(_timer)
	_timer.start()
	_timer.connect("timeout", Callable(self, "_on_timer_timeout"))

	set_process(true)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _duration:
		_timer.stop()
		queue_free()

func _on_timer_timeout() -> void:
	# gather alive zombies
	var zombies = get_tree().get_nodes_in_group("Zombie").filter( func(z): return z is CharacterBody2D )
	if zombies.is_empty():
		return

	# fire up to _strikes_per bolts at distinct random targets
	for i in _strikes_per:
		if zombies.is_empty(): break
		var idx = randi() % zombies.size()
		var z = zombies[idx]
		zombies.remove_at(idx)
		_strike(z)

func _strike(zombie: CharacterBody2D) -> void:
	var strike = LightningStrike.new()         # ← use .new() for a script
	get_tree().get_current_scene().add_child(strike)
	strike.fire(zombie.global_position, _damage)
