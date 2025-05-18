# res://Scripts/SmoothShakeCamera.gd
extends Camera2D

@export var smoothing_speed: float = 5.0    # higher = snappier follow
@export var shake_duration: float = 0.3     # how long the shake lasts
@export var shake_magnitude: float = 8.0    # max offset in pixels

var _target:      Node2D  = null
var _shake_timer: float   = 0.0
var _locked_y:    float   = 0.0

func _ready() -> void:
	# find the player to follow
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		_target = players[0]
		#global_position = _target.global_position
	else:
		push_warning("SmoothShakeCamera: no node in group 'Player' found.")
	# lock the current Y so it never changes
	_locked_y = global_position.y
	# watch for explosions
	get_tree().connect("node_added", Callable(self, "_on_node_added"))

func _on_node_added(node: Node) -> void:
	if node.is_in_group("Explosion"):
		_shake_timer = shake_duration

func _process(delta: float) -> void:
	# 1) smooth‐follow base position (only X will actually update)
	var base_pos = global_position
	if _target:
		base_pos = base_pos.lerp(_target.global_position, smoothing_speed * delta)
	base_pos.y = _locked_y   # force Y back to locked value

	# 2) overlay shake (then re‐lock Y again)
	var final_pos = base_pos
	if _shake_timer > 0.0:
		_shake_timer -= delta
		final_pos += Vector2(
			randf_range(-shake_magnitude, shake_magnitude),
			randf_range(-shake_magnitude, shake_magnitude)
		)
		final_pos.y = _locked_y

	global_position = final_pos
