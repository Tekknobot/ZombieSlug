extends Node2D

@export var duration: float   = 0.2    # seconds before the bolt fades and frees
@export var segments: int     = 12     # number of subdivisions along the bolt
@export var amplitude: float  = 8.0   # max offset perpendicular to the bolt
@export var color: Color      = Color(0.2, 0.8, 1.0) # bolt color
@export var width: float      = 1.0    # line thickness

var _line: Line2D

func _ready() -> void:
	# Expect a Line2D child named "BoltLine"
	_line = $BoltLine
	_line.width = width
	_line.modulate = color

func play(target_position: Vector2) -> void:
	# Build jagged points from origin to target
	var local_end = to_local(target_position)
	var dir = local_end.normalized()
	var length = local_end.length()
	var seg_len = length / float(segments)
	var points: Array[Vector2] = []
	for i in range(segments + 1):
		var base = dir * seg_len * float(i)
		var perp = Vector2(-dir.y, dir.x)
		var offset = perp * randf_range(-amplitude, amplitude) * (1.0 - float(i) / segments)
		points.append(base + offset)
	_line.points = points

	$AudioStreamPlayer2D.play()

	# Reset alpha and start fade tween
	_line.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(_line, "modulate:a", 0.0, duration)
	tween.tween_callback(Callable(self, "_on_finished"))

func _on_finished() -> void:
	queue_free()
