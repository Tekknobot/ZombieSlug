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
	# 1) get all CharacterBody2D zombies
	var all_zombies = get_tree().get_nodes_in_group("Zombie").filter( func(z):
		return z is CharacterBody2D
	)

	# 2) filter to only those within the camera's world‐space rect
	var visible_zombies = all_zombies.filter( func(z):
		return _is_in_camera_view(z.global_position)
	)

	if visible_zombies.is_empty():
		return

	# 3) pick up to _strikes_per distinct random targets
	var candidates = visible_zombies.duplicate()
	for i in range(_strikes_per):
		if candidates.is_empty():
			break
		var idx = randi() % candidates.size()
		var z = candidates[idx]
		candidates.remove_at(idx)
		_strike(z)

func _strike(zombie: CharacterBody2D) -> void:
	var strike = LightningStrike.new()
	get_tree().get_current_scene().add_child(strike)
	strike.fire(zombie.global_position, _damage)

# ——— helper to test if a world‐pos is inside the Camera2D viewport ———
func _is_in_camera_view(world_pos: Vector2) -> bool:
	var cam = get_viewport().get_camera_2d()
	if cam == null:
		return false

	# size of the viewport in pixels
	var pixel_size = get_viewport().get_visible_rect().size
	# convert to world‐units by applying camera zoom
	var world_size = pixel_size * cam.zoom

	# top‐left corner of the camera view in world‐coords
	var half = world_size * 0.5
	var top_left = cam.global_position - half

	# rectangle representing what the camera sees
	var view_rect = Rect2(top_left, world_size)

	return view_rect.has_point(world_pos)
