# res://Scripts/SmoothShakeCamera.gd
extends Camera2D

@export var smoothing_speed: float = 5.0    # higher = snappier follow
@export var shake_duration: float = 0.3     # how long the shake lasts
@export var shake_magnitude: float = 8.0    # max offset in pixels

var _target:      Node2D  = null
var _shake_timer: float   = 0.0
var _locked_y:    float   = 0.0

func _ready() -> void:
	# grab the first player in the group (if any)
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		_target = players[0]
	else:
		push_warning("SmoothShakeCamera: no node in group 'Player' found.")

	# lock the Y-axis so it never drifts
	_locked_y = global_position.y

	# watch for Explosions to trigger shakes
	get_tree().connect("node_added", Callable(self, "_on_node_added"))

	set_process(true)

func _on_node_added(node: Node) -> void:
	if node.is_in_group("Explosion"):
		_shake_timer = shake_duration

func _process(delta: float) -> void:
	var base_pos = global_position

	# only follow if _target is still alive
	if is_instance_valid(_target):
		# lerp only the X component
		base_pos.x = lerp(base_pos.x, _target.global_position.x, smoothing_speed * delta)

	# force Y back to our locked value
	base_pos.y = _locked_y

	# overlay shake on top of that
	if _shake_timer > 0.0:
		_shake_timer -= delta
		base_pos += Vector2(
			randf_range(-shake_magnitude, shake_magnitude),
			0  # no vertical shake so Y remains locked
		)

	global_position = base_pos
