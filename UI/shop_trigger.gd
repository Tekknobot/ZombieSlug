# res://Scripts/ShopTrigger.gd
extends Area2D

@export var shop_ui: CanvasLayer
@export var interior_scene: PackedScene = preload("res://Scenes/Interior_Main.tscn")
@export var exterior_scene: PackedScene = preload("res://Scenes/Main.tscn")

var _player_in_zone := false

func _ready() -> void:
	connect("body_entered",  Callable(self, "_on_body_entered"))
	connect("body_exited",   Callable(self, "_on_body_exited"))
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_zone or get_tree().paused:
		return
	if event is InputEventJoypadButton \
	and event.button_index == JOY_BUTTON_DPAD_UP \
	and event.pressed:

		# Interior door → load interior scene
		if is_in_group("Interior_Door"):
			_open_scene(interior_scene)
			return

		# Exterior door → load main scene
		if is_in_group("Exterior_Door"):
			_open_scene(exterior_scene)
			return

		# Otherwise open the shop UI
		if not shop_ui.is_visible():
			shop_ui.update_currency_label()
			shop_ui.populate_upgrades()
			shop_ui.show_shop()
			get_tree().paused = true

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_in_zone = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_in_zone = false

func _open_scene(scene: PackedScene) -> void:
	var tree = get_tree()
	var path = scene.resource_path
	# Godot 4: change_scene_to_file(path)
	if tree.has_method("change_scene_to_file"):
		tree.change_scene_to_file(path)
	# Godot 4: change_scene_to(PackedScene)
	elif tree.has_method("change_scene_to"):
		tree.change_scene_to(scene)
	# Godot 3: change_scene(path)
	elif tree.has_method("change_scene"):
		tree.change_scene(path)
	else:
		push_warning("No suitable change_scene method found on SceneTree.")
