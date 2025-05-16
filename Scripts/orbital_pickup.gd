# res://Scenes/Items/OrbitalStrikePickup.gd
extends Area2D

@export var sfx_stream : AudioStream      # drop your strike SFX here
@export var wiggle_angle : float = 10.0
@export var wiggle_time  : float = 1.0

const OrbitalController = preload("res://Scripts/OrbitalStrikeController.gd")

var _time := 0.0
@onready var collect_sfx := $CollectSfx as AudioStreamPlayer2D

func _ready() -> void:
	monitoring = true
	connect("body_entered", Callable(self, "_on_body_entered"))
	set_process(true)

func _process(delta: float) -> void:
	_time += delta
	rotation_degrees = sin(_time * TAU / wiggle_time) * wiggle_angle

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("Player"):
		return

	# play & detach SFX so it survives this node being freed
	collect_sfx.play()
	remove_child(collect_sfx)
	get_tree().get_current_scene().add_child(collect_sfx)
	collect_sfx.global_position = global_position

	# spawn the controller
	var ctrl = OrbitalController.new()
	ctrl.sfx_stream = sfx_stream
	get_tree().get_current_scene().add_child(ctrl)
	Playerstats.add_currency(10)

	queue_free()
