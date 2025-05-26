extends CanvasLayer
class_name PauseManager

@export var pause_button := "pause"   # Input action to toggle pause
@export var panel_padding: Vector2 = Vector2(16, 16)

# UI references
@onready var pause_panel    := self
@onready var panel          := $Panel
@onready var resume_button  := $Panel/VBoxContainer/VBox/ResumeButton
@onready var options_button := $Panel/VBoxContainer/VBox/OptionsButton
@onready var quit_button    := $Panel/VBoxContainer/VBox/QuitButton

# Stats labels (damage-related from shop)
@onready var grenade_damage_label = $Panel/VBoxContainer/Stats/GrenadeDamageLabel
@onready var mine_damage_label    = $Panel/VBoxContainer/Stats/MineDamageLabel
@onready var dog_damage_label     = $Panel/VBoxContainer/Stats/DogDamageLabel
@onready var merc_damage_label    = $Panel/VBoxContainer/Stats/MercDamageLabel
@onready var mech_damage_label    = $Panel/VBoxContainer/Stats/MechDamageLabel
@onready var panther_damage_label = $Panel/VBoxContainer/Stats/PantherDamageLabel
@onready var currency_label       = $Panel/VBoxContainer/Stats/CurrencyLabel

# Navigation
var nav_buttons: Array = []
var current_nav_index: int = 0

func _ready() -> void:
	# Initial state
	pause_panel.visible = false
	get_tree().paused = false
	# Ensure this layer and its children process input when paused
	process_mode = ProcessMode.PROCESS_MODE_ALWAYS
	_enable_ui_processing(self)
	set_process_unhandled_input(true)

	# Build nav list & hook button signals
	nav_buttons = [resume_button, options_button, quit_button]

	for btn in nav_buttons:
		btn.focus_mode = Control.FOCUS_ALL
		btn.process_mode = ProcessMode.PROCESS_MODE_ALWAYS

	resume_button.connect("pressed", Callable(self, "_on_resume"))
	#options_button.connect("pressed", Callable(self, "_on_options"))
	quit_button.connect("pressed", Callable(self, "_on_quit"))

func _process(_delta: float) -> void:
	# Skip if shop open
	for shop_ui in get_tree().get_nodes_in_group("Shop"):
		if shop_ui is CanvasLayer and shop_ui.visible:
			return

	# Toggle pause
	if Input.is_action_just_pressed(pause_button):
		if get_tree().paused:
			_unpause()
		else:
			_show_pause()
		return

func _input(event: InputEvent) -> void:
	if not pause_panel.visible:
		return

	# D-pad navigation
	if event is InputEventJoypadButton and event.pressed and (event.button_index == JOY_BUTTON_DPAD_UP or event.button_index == JOY_BUTTON_DPAD_DOWN):
		if event.button_index == JOY_BUTTON_DPAD_UP:
			_nav_prev()
		else:
			_nav_next()
		get_viewport().set_input_as_handled()

	# Activate with A/jump
	elif event.is_action_pressed("jump"):
		var f = get_viewport().gui_get_focus_owner()
		if f and f is Button:
			f.emit_signal("pressed")
			get_viewport().set_input_as_handled()

func _show_pause() -> void:
	$Music.play()
	get_tree().paused = true
	pause_panel.visible = true
	_update_stats()
	_fit_panel_to_content()
	current_nav_index = 0
	nav_buttons[current_nav_index].grab_focus()

func _unpause() -> void:
	$Music.stop()
	pause_panel.visible = false
	get_tree().paused = false

func _update_stats() -> void:
	# align labels and values using fixed-width formatting
	var fmt = "%-4s %0d"
	currency_label.text       = fmt % ["Currency:", Playerstats.currency]

	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		var p = players[0]
		grenade_damage_label.text = fmt % ["Grenade Damage:", p.grenade_damage]
		mine_damage_label.text    = fmt % ["Mine Damage:",    p.mine_damage]
		dog_damage_label.text     = fmt % ["Dog Damage:",     p.dog_base_damage]
		merc_damage_label.text    = fmt % ["Merc Damage:",    p.merc_base_damage]
		mech_damage_label.text    = fmt % ["Crawler Damage:", p.mech_base_damage]
		panther_damage_label.text = fmt % ["Roller Damage:",  p.mech_panther_base_damage]

func _nav_next() -> void:
	current_nav_index = (current_nav_index + 1) % nav_buttons.size()
	nav_buttons[current_nav_index].grab_focus()

func _nav_prev() -> void:
	current_nav_index = (current_nav_index - 1 + nav_buttons.size()) % nav_buttons.size()
	nav_buttons[current_nav_index].grab_focus()

func _on_resume() -> void:
	_unpause()

func _on_options() -> void:
	_unpause()
	get_tree().change_scene("res://Scenes/OptionsMenu.tscn")

func _on_quit() -> void:
	_unpause()
	get_tree().quit()

func _fit_panel_to_content() -> void:
	var size = panel.get_node("VBoxContainer").get_combined_minimum_size()
	panel.size = size + panel_padding * 2
	panel.get_node("VBoxContainer").position = panel_padding

func _enable_ui_processing(node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).process_mode = ProcessMode.PROCESS_MODE_ALWAYS
	for c in node.get_children():
		_enable_ui_processing(c)
