# res://Scenes/Items/FreezePickup.gd
extends Area2D

const FreezeController = preload("res://Scripts/FreezeController.gd")  # ← add this!

@export var duration:    float       = 3.0    # how long zombies stay frozen
@export var wiggle_angle: float      = 10.0   # degrees each side
@export var wiggle_time:  float      = 1.0    # full back-and-forth period
@export var sfx_stream:   AudioStream       # optional pickup sound

@onready var collect_sfx := $CollectSfx as AudioStreamPlayer2D
var _time: float = 0.0

func _ready() -> void:
	monitoring = true
	connect("body_entered", Callable(self, "_on_body_entered"))
	set_process(true)

func _process(delta: float) -> void:
	_time += delta
	rotation_degrees = sin(_time * TAU / wiggle_time) * wiggle_angle

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		# play pickup sound alive
		if collect_sfx:
			remove_child(collect_sfx)
			get_tree().get_current_scene().add_child(collect_sfx)
			collect_sfx.global_position = global_position
			collect_sfx.play()

		# spawn the FreezeController
		var ctrl = FreezeController.new()
		ctrl.duration   = duration
		ctrl.sfx_stream = sfx_stream
		get_tree().get_current_scene().add_child(ctrl)
		Playerstats.add_currency(10)

		queue_free()
