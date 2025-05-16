# res://Scripts/ShopTrigger.gd
extends Area2D

@export var shop_ui: CanvasLayer

var _player_in_zone := false

func _ready() -> void:
	print("[%s] ShopTrigger ready. monitoring=%s, layer=%d, mask=%d" %
		[name, monitoring, collision_layer, collision_mask])
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited",  Callable(self, "_on_body_exited"))
	set_process(true)

func _process(delta: float) -> void:
	# if player is in the zone and presses Up, open the shop
	if _player_in_zone and Input.is_action_just_pressed("ui_up"):
		print("ui_up pressed in shop zone → opening shop")
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
	print("[%s] body_exited  -> %s, groups=%s" %
		[name, body.name, body.get_groups()])
	if body.is_in_group("Player"):
		_player_in_zone = false
		print("  → Player left shop zone, closing shop")
		shop_ui.hide_shop()
		get_tree().paused = false
