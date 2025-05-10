# res://Scenes/Items/TimeWarpPickup.gd
extends Area2D

@export var duration:     float       = 5.0    # how long the slow lasts
@export var slow_factor:  float       = 0.3    # 30% game speed
@export var sfx_stream:   AudioStream             # optional pickup SFX

# wiggle parameters
@export var wiggle_angle: float       = 10.0   # degrees each side
@export var wiggle_time:  float       = 0.8    # seconds per full oscillation

var _time: float = 0.0

const TimeWarpController = preload("res://Scripts/TimeWarpController.gd")

func _ready() -> void:
	monitoring = true
	connect("body_entered", Callable(self, "_on_body_entered"))
	set_process(true)

func _process(delta: float) -> void:
	_time += delta
	rotation_degrees = sin(_time * TAU / wiggle_time) * wiggle_angle

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		# optional pickup sound
		if sfx_stream:
			var sfx = AudioStreamPlayer2D.new()
			sfx.stream = sfx_stream
			get_tree().get_current_scene().add_child(sfx)
			sfx.global_position = global_position
			sfx.play()

		# spawn and configure the slow‐motion controller
		var ctrl = TimeWarpController.new()
		ctrl.duration    = duration
		ctrl.slow_factor = slow_factor
		ctrl.sfx_stream  = sfx_stream
		get_tree().get_current_scene().add_child(ctrl)

		queue_free()
