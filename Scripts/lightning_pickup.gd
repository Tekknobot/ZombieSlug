extends Area2D

@export var duration:            float = 5.0   # total seconds storm lasts
@export var interval:            float = 1.0   # seconds between volleys
@export var strikes_per_interval: int   = 3    # how many bolts each volley
@export var damage:              int   = 3    # damage per bolt

# wiggle params
@export var wiggle_angle: float = 10.0  # degrees either side
@export var wiggle_time:  float = 1.0   # seconds per full back-and-forth

const LightningController = preload("res://Scripts/LightningController.gd")

var _time := 0.0

func _ready() -> void:
	monitoring = true
	connect("body_entered", Callable(self, "_on_body_entered"))
	set_process(true)

func _process(delta: float) -> void:
	_time += delta
	# full cycle is wiggle_time, so use sin(_time / wiggle_time * TAU)
	rotation_degrees = sin(_time / wiggle_time * TAU) * wiggle_angle

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		var ctrl = LightningController.new()
		get_tree().get_current_scene().add_child(ctrl)
		ctrl.start(duration, interval, strikes_per_interval, damage)
		queue_free()
