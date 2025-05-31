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
		"amount":   1,
		"icon":    preload("res://Projectiles/tnt/tnt_drop.png")
	},
	{
		"name":   "Mine Damage +1",
		"cost":    125,
		"stat":   "initial_mine_damage",
		"amount":   1,
		"icon":    preload("res://Assets/Mines/mine_drop.png")        
	},
	{
		"name":   "Dog Damage +1",
		"cost":    150,
		"stat":   "dog_base_damage",
		"amount":   1,
		"icon":    preload("res://Assets/Items/dog_drop.png")        
	},
	{
		"name":   "Merc Damage +1",
		"cost":    175,
		"stat":   "merc_base_damage",
		"amount":   1,
		"icon":    preload("res://Assets/Items/merc_drop.png")        
	},
	{
		"name":   "Crawler Damage +5",
		"cost":    200,
		"stat":   "mech_base_damage",
		"amount":   5,
		"icon":    preload("res://Assets/Items/crawler_drop.png")        
	},
	{
		"name":   "Roller Damage +5",
		"cost":    200,
		"stat":   "mech_panther_base_damage",
		"amount":   5,
		"icon":    preload("res://Assets/Items/roller_drop.png")        
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
	set_process_unhandled_input(true)

	update_currency_label()
	update_shop_label()
	populate_upgrades()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Only respond to true D-pad up/down
	if event is InputEventJoypadButton and event.pressed and (event.button_index == JOY_BUTTON_DPAD_UP or event.button_index == JOY_BUTTON_DPAD_DOWN):

		if event.button_index == JOY_BUTTON_DPAD_UP:
			_focus_prev_button()
		else:
			_focus_next_button()

		get_viewport().set_input_as_handled()

	# Activate with jump (keyboard or gamepad A)
	elif event.is_action_pressed("jump"):
		var focused = get_viewport().gui_get_focus_owner()
		if focused and focused is Button:
			focused.emit_signal("pressed")
			get_viewport().set_input_as_handled()

func update_currency_label():
	currency_label.text = "$ " + str(Playerstats.currency)
	if font:
		currency_label.add_theme_font_override("font", font)
		currency_label.add_theme_constant_override("font_size", font_size)

func update_shop_label():
	shop_label.text = "MERCHANT"
	if font:
		shop_label.add_theme_font_override("font", font)
		shop_label.add_theme_constant_override("font_size", font_size)

func populate_upgrades():
	# clear existing rows
	for child in upgrades_container.get_children():
		child.free()

	for data in upgrades:
		# scale each “amount” by the player’s current level
		var payload = data.duplicate()
		payload.amount = data.amount * Playerstats.level

		# create one HBox per upgrade
		var row = HBoxContainer.new()
		if font:
			row.add_theme_font_override("font", font)
			row.add_theme_constant_override("font_size", font_size)

		# 1) icon / TextureRect in front
		var icon = TextureRect.new()
		icon.texture = data.icon
		icon.size = Vector2(24,24)
		icon.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)

		# 2) description label
		var desc = Label.new()
		desc.text = "%s +%d (Cost: %d)" % [ data.name.split(" +")[0], payload.amount, data.cost ]
		desc.focus_mode = Control.FOCUS_NONE
		if font:
			desc.add_theme_font_override("font", font)
			desc.add_theme_constant_override("font_size", font_size)
		row.add_child(desc)

		# 3) buy button
		var btn = Button.new()
		btn.text = "Buy"
		btn.disabled = Playerstats.currency < data.cost
		btn.focus_mode = Control.FOCUS_ALL
		if font:
			btn.add_theme_font_override("font", font)
			btn.add_theme_constant_override("font_size", font_size)
		# Bind “payload” onto the pressed‐signal
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

	# 1) Try to spend currency via PlayerStats
	if Playerstats.use_currency(data.cost):
		# 2) Apply the upgrade locally in shop AND push into PlayerStats
		apply_upgrade(data)
		update_currency_label()

		# flash the description text green to confirm purchase
		if is_instance_valid(desc):
			desc.modulate = Color(0,1,0)
		await get_tree().create_timer(0.2).timeout
		if is_instance_valid(desc):
			desc.modulate = Color(1,1,1)

		# re‐populate the list so that any “Buy” buttons disable/enable accordingly
		populate_upgrades()
		$AudioStreamPlayer2D.play()
	else:
		# flash description red if not enough money
		if is_instance_valid(desc):
			desc.modulate = Color(1,0,0)
		await get_tree().create_timer(0.2).timeout
		if is_instance_valid(desc):
			desc.modulate = Color(1,1,1)
		push_error("Not enough currency for %s" % data.name)


func apply_upgrade(data: Dictionary) -> void:
	# We assume exactly one Player in the “Player” group
	var players = get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		push_error("No Player instance found to apply upgrade")
		return

	# In this setup, we want to *persist* every base‐damage change into PlayerStats,
	# not only into the local soldier node. This way, when we switch scenes, the
	# singleton still “remembers” our new damage values.
	match data.stat:
		"initial_grenade_damage":
			# Increase PlayerStats.initial_grenade_damage
			Playerstats.initial_grenade_damage += data.amount
			# Recompute “grenade_damage” at the current level:
			Playerstats.grenade_damage = Playerstats.initial_grenade_damage + (Playerstats.level - 1)
			Playerstats.emit_signal("grenade_damage_changed", Playerstats.grenade_damage)

		"initial_mine_damage":
			Playerstats.initial_mine_damage += data.amount
			Playerstats.mine_damage = Playerstats.initial_mine_damage + (Playerstats.level - 1)
			Playerstats.emit_signal("mine_damage_changed", Playerstats.mine_damage)

		"dog_base_damage":
			Playerstats.dog_base_damage += data.amount
			Playerstats.dog_damage = Playerstats.dog_base_damage + (Playerstats.level - 1) * Playerstats.dog_damage_per_level
			Playerstats.emit_signal("dog_damage_changed", Playerstats.dog_damage)

		"merc_base_damage":
			Playerstats.merc_base_damage += data.amount
			Playerstats.merc_damage = Playerstats.merc_base_damage + (Playerstats.level - 1) * Playerstats.merc_damage_per_level
			Playerstats.emit_signal("merc_damage_changed", Playerstats.merc_damage)

		"mech_base_damage":
			Playerstats.mech_base_damage += data.amount
			Playerstats.mech_damage = Playerstats.mech_base_damage + (Playerstats.level - 1) * Playerstats.mech_damage_per_level
			Playerstats.emit_signal("mech_damage_changed", Playerstats.mech_damage)

		"mech_panther_base_damage":
			Playerstats.panther_base_damage += data.amount
			Playerstats.panther_damage = Playerstats.panther_base_damage + (Playerstats.level - 1) * Playerstats.panther_damage_per_level
			Playerstats.emit_signal("panther_damage_changed", Playerstats.panther_damage)

		_:
			push_warning("Unknown upgrade stat: %s" % data.stat)
			return

	# (Optional) If you also want to push any soldier‐side variables in case the
	# soldier script caches them locally, you can do something like:
	#
	# var soldier = players[0]
	# soldier.grenade_damage = Playerstats.grenade_damage
	# soldier.mine_damage    = Playerstats.mine_damage
	# soldier.dog_base_damage = Playerstats.dog_damage
	# ...etc…

	# But as long as your Soldier.gd’s _ready() pulls everything from Playerstats,
	# simply updating the singleton is sufficient. The next time you re‐enter the
	# scene—or if the soldier listens to those “*_damage_changed” signals—the new
	# values will be applied automatically.


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
	$Music.play()
	visible = true
	_grab_first_button_focus()

func hide_shop() -> void:
	$Music.stop()
	visible = false
