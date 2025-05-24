# res://Scripts/ShopTrigger.gd
extends Area2D

@export var shop_ui: CanvasLayer

var _player_in_zone := false

func _ready() -> void:
	print("[%s] ShopTrigger ready. monitoring=%s, layer=%d, mask=%d" %
		[name, monitoring, collision_layer, collision_mask])
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited",  Callable(self, "_on_body_exited"))
	# make sure we get input events
	set_process_input(true)
	set_process_unhandled_input(true)

# no more _process() watching ui_up()

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_zone or shop_ui.is_visible() or get_tree().paused:
		return

	# Only open on gamepad D-pad Up
	if event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_DPAD_UP and event.pressed:
			print("D-pad Up pressed in shop zone → opening shop")
			shop_ui.update_currency_label()
			shop_ui.populate_upgrades()
			shop_ui.show_shop()
			get_tree().paused = true

func _on_body_entered(body: Node) -> void:
	print("[%s] body_entered -> %s, groups=%s" %
		[name, body.name, body.get_groups()])
	if body.is_in_group("Player"):
		_player_in_zone = true
		print("  → Player entered shop zone")

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_in_zone = false
		print("  → Player exited shop zone")
	# optionally hide your prompt UI here
