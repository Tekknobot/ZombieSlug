# HelicopterSpawner.gd
extends Node2D

@export var controller_id:  int = 1
@export var helicopter_scene: PackedScene = preload("res://Scenes/Sprites/helicopter.tscn")
@export var fade_duration:    float       = 1.0

var _helicopter_inst: Node2D = null

func _ready() -> void:
	# we want to catch joypad input
	set_process_input(true)

func _input(event: InputEvent) -> void:
	# only once, and only for pad #2’s A button
	if _helicopter_inst:
		return
	if event is InputEventJoypadButton and event.device == controller_id and event.pressed:
		# JOY_BUTTON_A is the “jump” button on most pads
		if event.button_index == JOY_BUTTON_A:
			_spawn_helicopter()

func _spawn_helicopter() -> void:
	# instantiate at this node’s position
	_helicopter_inst = helicopter_scene.instantiate() as Node2D
	_helicopter_inst.global_position = global_position

	# start fully transparent
	_helicopter_inst.modulate = Color(1, 1, 1, 0)
	get_tree().get_current_scene().add_child(_helicopter_inst)

	# fade it in
	var tw = get_tree().create_tween()
	tw.tween_property(_helicopter_inst, "modulate:a", 1.0, fade_duration)
