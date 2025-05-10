# res://Scripts/CameraShake.gd
extends Camera2D

@export var shake_duration:  float = 0.3    # how long the shake lasts
@export var shake_magnitude: float = 8.0    # max offset in pixels

var _timer:      float = 0.0
var _orig_pos:   Vector2

func _ready() -> void:
	_orig_pos = position
	# watch for any new Explosions entering the scene
	get_tree().connect("node_added", Callable(self, "_on_node_added"))

func _on_node_added(node: Node) -> void:
	if node.is_in_group("Explosion"):
		_timer = shake_duration

func _process(delta: float) -> void:
	if _timer > 0.0:
		_timer -= delta
		# jitter around original spot
		position = _orig_pos + Vector2(
			randf_range(-shake_magnitude, shake_magnitude),
			randf_range(-shake_magnitude, shake_magnitude)
		)
		if _timer <= 0.0:
			# done shaking— snap back
			position = _orig_pos
