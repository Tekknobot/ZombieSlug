# CloudMover.gd
extends Node2D

@export var range_x: float = 16.0    # how far (px) from center it swings left/right
@export var freq_x:  float = 0.2     # cycles per second

var _time:     float = 0.0
var _origin_x: float = 0.0

func _ready() -> void:
	# remember the starting center X
	_origin_x = position.x

func _process(delta: float) -> void:
	_time += delta
	# sin() goes from -1→1, multiply by range_x to get ±range_x
	position.x = _origin_x + sin(_time * TAU * freq_x) * range_x
