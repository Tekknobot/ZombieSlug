# res://Scenes/Items/StarPickup.gd
extends Area2D

@export var duration:    float = 5.0   # seconds of invincibility
@export var damage:      int   = 3000     # how much “touch” damage to deal
@export var wiggle_angle: float = 10.0 # max degrees each side
@export var wiggle_time:  float = 1.0  # seconds per full oscillation

@onready var collect_sfx := $CollectSfx as AudioStreamPlayer2D

var _time: float = 0.0

func _ready() -> void:
	monitoring = true
	connect("body_entered", Callable(self, "_on_body_entered"))
	set_process(true)

func _process(delta: float) -> void:
	_time += delta
	# sin wave from –1..1 over wiggle_time seconds
	rotation_degrees = sin(_time * TAU / wiggle_time) * wiggle_angle

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("Player"):
		return

	# detach & play SFX
	collect_sfx.play()
	remove_child(collect_sfx)
	get_tree().get_current_scene().add_child(collect_sfx)
	collect_sfx.global_position = global_position

	# grant star power
	if body.has_method("apply_star"):
		body.apply_star(duration, damage)

	queue_free()
