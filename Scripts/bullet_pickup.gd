extends Area2D

@export var duration:            float = 1.0    # how long the rain lasts
@export var interval:            float = 0.1    # seconds between volleys
@export var bullets_per_tick:    int   = 5      # bullets per volley
@export var spread:              float = 100.0  # horizontal spread around player
@export var speed:               float = 200.0  # fall speed of each bullet
@export var damage:              int   = 1      # damage per bullet

# little wrist-watch wiggle so the pickup spins in place
@export var wiggle_angle:        float = 10.0
@export var wiggle_time:         float = 1.0
var _time:                       float = 0.0

const BulletRainController = preload("res://Scripts/BulletRainController.gd")

@onready var collect_sfx := $CollectSfx as AudioStreamPlayer2D

func _ready() -> void:
	monitoring = true
	set_process(true)
	connect("body_entered", Callable(self, "_on_body_entered"))

func _process(delta: float) -> void:
	_time += delta
	rotation_degrees = sin(_time * TAU / wiggle_time) * wiggle_angle

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("Player"):
		return

	# play & detach collect SFX
	remove_child(collect_sfx)
	get_tree().get_current_scene().add_child(collect_sfx)
	collect_sfx.global_position = global_position
	collect_sfx.play()

	# spawn the rain controller at the player's position
	var ctrl = BulletRainController.new()
	ctrl.global_position     = body.global_position
	ctrl.duration            = duration
	ctrl.interval            = interval
	ctrl.bullets_per_tick    = bullets_per_tick
	ctrl.spread              = spread
	ctrl.speed               = speed
	ctrl.damage              = damage
	get_tree().get_current_scene().add_child(ctrl)

	Playerstats.add_currency(10)
	
	queue_free()
