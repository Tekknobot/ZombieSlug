# res://Scripts/DoorTrigger.gd
extends Area2D

@export var target_scene_path: String = "res://Scenes/Main.tscn"

var _player_inside: bool = false

func _ready() -> void:
	monitoring = true
	set_process_input(true)
	
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited",  Callable(self, "_on_body_exited"))

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_inside = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_inside = false

func _input(event: InputEvent) -> void:
	if not _player_inside or get_tree().paused:
		return

	# look for D-pad Up on any controller
	if event is InputEventJoypadButton \
	and event.button_index == JOY_BUTTON_DPAD_UP \
	and event.pressed:
		
		# now change scene
		_load_scene()

func _load_scene() -> void:
	var tree = get_tree()
	# Godot 4: change_scene_to_file(path)
	if tree.has_method("change_scene_to_file"):
		tree.change_scene_to_file(target_scene_path)
	# Godot 4: change_scene_to(PackedScene) — if you ever switch to a PackedScene export
	elif tree.has_method("change_scene_to"):
		var packed = ResourceLoader.load(target_scene_path)
		tree.change_scene_to(packed)
	# Godot 3: change_scene(path)
	elif tree.has_method("change_scene"):
		tree.change_scene(target_scene_path)
	else:
		push_error("DoorTrigger: no scene-change method available")
