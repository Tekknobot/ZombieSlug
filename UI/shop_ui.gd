# ShopUI.gd
extends CanvasLayer

@export var font: Font                   # assign your Font resource here
@export var font_size: int = 16         # adjust this to resize text
@export var panel_padding: Vector2 = Vector2(16,16)

# ← only damage‐related upgrades here:
var upgrades = [
	{
		"name":   "Grenade Damage +1",
		"cost":    100,
		"stat":   "initial_grenade_damage",
		"amount":   1
	},
	{
		"name":   "Mine Damage +1",
		"cost":    125,
		"stat":   "initial_mine_damage",
		"amount":   1
	},
	{
		"name":   "Dog Damage +1",
		"cost":    150,
		"stat":   "dog_base_damage",
		"amount":   1
	},
	{
		"name":   "Merc Damage +1",
		"cost":    175,
		"stat":   "merc_base_damage",
		"amount":   1
	},
	{
		"name":   "Mech Damage +5",
		"cost":    200,
		"stat":   "mech_base_damage",
		"amount":   5
	},
	{
		"name":   "Panther Damage +5",
		"cost":    200,
		"stat":   "mech_panther_base_damage",
		"amount":   5
	},
]

@onready var panel              = $Panel
@onready var shop_label         = $Panel/VBoxContainer/ShopName
@onready var currency_label     = $Panel/VBoxContainer/CurrencyLabel
@onready var upgrades_container = $Panel/VBoxContainer/UpgradesContainer

func _ready():
	hide()
	# Ensure this UI still receives input when the game is paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	# Enable unhandled input even when paused
	set_process_unhandled_input(true)

	update_currency_label()
	update_shop_label()
	populate_upgrades()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Navigate with up/down
	if event.is_action_pressed("ui_up"):
		_focus_prev_button()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_focus_next_button()
		get_viewport().set_input_as_handled()

	# Activate focused button with jump (keyboard or gamepad)
	elif event.is_action_pressed("jump"):
		var focused = get_viewport().gui_get_focus_owner()
		if focused and focused is Button:
			focused.emit_signal("pressed")
			get_viewport().set_input_as_handled()


func update_currency_label():
	currency_label.text = "Currency: " + str(Playerstats.currency)
	if font:
		currency_label.add_theme_font_override("font", font)
		currency_label.add_theme_constant_override("font_size", font_size)

func update_shop_label():
	shop_label.text = "UPGRADE MERCHANT"
	if font:
		shop_label.add_theme_font_override("font", font)
		shop_label.add_theme_constant_override("font_size", font_size)

func populate_upgrades():
	# clear existing rows
	for child in upgrades_container.get_children():
		child.free()

	# one HBox entry per upgrade with label and buy button side by side
	for data in upgrades:
		# duplicate and scale amount by current player level
		var payload = data.duplicate()
		payload.amount = data.amount * Playerstats.level

		var row = HBoxContainer.new()
		# row itself doesn’t need to grab focus—buttons will
		if font:
			row.add_theme_font_override("font", font)
			row.add_theme_constant_override("font_size", font_size)

		# description label (show scaled amount)
		var desc = Label.new()
		desc.text = "%s +%d (Cost: %d)" % [data.name.split(" +")[0], payload.amount, data.cost]
		desc.focus_mode = Control.FOCUS_NONE
		if font:
			desc.add_theme_font_override("font", font)
			desc.add_theme_constant_override("font_size", font_size)
		row.add_child(desc)

		# buy button next to label
		var btn = Button.new()
		btn.text = "Buy"
		btn.disabled = Playerstats.currency < data.cost
		btn.focus_mode = Control.FOCUS_ALL
		if font:
			btn.add_theme_font_override("font", font)
			btn.add_theme_constant_override("font_size", font_size)
		btn.connect("pressed", Callable(self, "_on_buy_pressed").bind(payload))
		row.add_child(btn)

		upgrades_container.add_child(row)

	# separator and leave button
	upgrades_container.add_child(HSeparator.new())
	var leave_btn = Button.new()
	leave_btn.text = "Leave"
	leave_btn.focus_mode = Control.FOCUS_ALL
	if font:
		leave_btn.add_theme_font_override("font", font)
		leave_btn.add_theme_constant_override("font_size", font_size)
	leave_btn.connect("pressed", Callable(self, "_on_leave_pressed"))
	upgrades_container.add_child(leave_btn)

	_fit_panel_to_content()
	_grab_first_button_focus()

func _on_buy_pressed(data: Dictionary) -> void:
	var btn = get_viewport().gui_get_focus_owner() as Button
	var desc = btn.get_parent().get_child(0) as Label

	# Try to spend currency via use_currency()
	if Playerstats.use_currency(data.cost):
		apply_upgrade(data)
		update_currency_label()  # or rely on currency_changed signal to update UI
		# flash description green
		if is_instance_valid(desc):
			desc.modulate = Color(0,1,0)
		await get_tree().create_timer(0.2).timeout
		if is_instance_valid(desc):
			desc.modulate = Color(1,1,1)
		populate_upgrades()
	else:
		# flash description red
		if is_instance_valid(desc):
			desc.modulate = Color(1,0,0)
		await get_tree().create_timer(0.2).timeout
		if is_instance_valid(desc):
			desc.modulate = Color(1,1,1)
		push_error("Not enough currency for %s" % data.name)

func apply_upgrade(data: Dictionary) -> void:
	# Find the player instance
	var players = get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		push_error("No Player instance found to apply upgrade")
		return
	var soldier = players[0]

	match data.stat:
		"max_health":
			soldier.max_health += data.amount
			soldier.health = soldier.max_health
			# if you want to notify the UI via PlayerStats:
			Playerstats.health = soldier.health
			Playerstats.emit_signal("health_changed", soldier.health)

		"initial_grenade_damage":
			soldier.grenade_damage += data.amount

		"initial_mine_damage":
			soldier.mine_damage += data.amount

		"dog_base_damage":
			soldier.dog_base_damage += data.amount

		"merc_base_damage":
			soldier.merc_base_damage += data.amount

		"mech_base_damage":
			soldier.mech_base_damage += data.amount

		"mech_panther_base_damage":
			soldier.mech_panther_base_damage += data.amount

		_:
			push_warning("Unknown upgrade stat: %s" % data.stat)
			return

func _on_leave_pressed() -> void:
	hide_shop()
	get_tree().paused = false

func _focus_next_button() -> void:
	var buttons = _get_all_buttons()
	if buttons.is_empty(): return
	var curr = get_viewport().gui_get_focus_owner()
	var idx  = buttons.find(curr)
	buttons[(idx + 1) % buttons.size()].grab_focus()

func _focus_prev_button() -> void:
	var buttons = _get_all_buttons()
	if buttons.is_empty(): return
	var curr = get_viewport().gui_get_focus_owner()
	var idx  = buttons.find(curr)
	buttons[(idx - 1 + buttons.size()) % buttons.size()].grab_focus()

func _get_all_buttons() -> Array:
	var list = []
	for entry in upgrades_container.get_children():
		if entry is Button:
			list.append(entry)
		for child in entry.get_children():
			if child is Button:
				list.append(child)
	return list

func _grab_first_button_focus() -> void:
	var buttons = _get_all_buttons()
	if not buttons.is_empty():
		buttons[0].grab_focus()

func _fit_panel_to_content() -> void:
	var content_size = $Panel/VBoxContainer.get_combined_minimum_size()
	panel.custom_minimum_size = content_size + panel_padding * 2

func show_shop() -> void:
	visible = true
	_grab_first_button_focus()

func hide_shop() -> void:
	visible = false
