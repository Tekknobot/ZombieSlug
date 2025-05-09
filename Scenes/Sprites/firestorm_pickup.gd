# res://Scenes/Items/FirestormPickup.gd
extends Area2D

@export var duration:             float = 5.0
@export var interval:             float = 0.2
@export var strikes_per_interval: int   = 3
@export var damage:               int   = 2
@export var radius:               float = 64.0
@export var sfx_stream:           AudioStream

# wiggle params:
@export var wiggle_angle: float = 10.0  # max degrees each side
@export var wiggle_time:  float = 0.8   # full oscillation period

const FirestormController = preload("res://Scripts/FirestormController.gd")

var _time: float = 0.0

func _ready() -> void:
	monitoring = true
	connect("body_entered", Callable(self, "_on_body_entered"))
	set_process(true)  # needed for _process wiggle

func _process(delta: float) -> void:
	_time += delta
	# oscillate rotation_degrees between ±wiggle_angle
	rotation_degrees = sin(_time * TAU / wiggle_time) * wiggle_angle

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		var ctrl = FirestormController.new()
		ctrl.global_position        = body.global_position
		ctrl.duration               = duration
		ctrl.interval               = interval
		ctrl.strikes_per_interval   = strikes_per_interval
		ctrl.damage                 = damage
		ctrl.radius                 = radius
		ctrl.sfx_stream             = sfx_stream
		get_tree().get_current_scene().add_child(ctrl)
		queue_free()
