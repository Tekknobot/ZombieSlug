# PauseManager.gd
# ----------------------
# This CanvasLayer shows a pause panel and, when opened, reads from PlayerStats 
# and from the (first) Player node in the “Player” group. We use call_deferred()
# in _show_pause() so that any newly created/instanced Player has already run its
# _ready() and pulled stats from PlayerStats.

extends CanvasLayer
class_name PauseManager

@export var pause_button := "pause"             # Input action to toggle pause
@export var panel_padding: Vector2 = Vector2(16, 16)

# UI references (assigned at scene‐build time)
@onready var pause_panel    := self
@onready var panel          := $Panel
@onready var resume_button  := $Panel/VBoxContainer/VBox/ResumeButton
@onready var options_button := $Panel/VBoxContainer/VBox/OptionsButton
@onready var quit_button    := $Panel/VBoxContainer/VBox/QuitButton

# Stats labels (damage‐related from shop or leveling)
@onready var grenade_damage_label = $Panel/VBoxContainer/Stats/Grenade/GrenadeDamageLabel
@onready var mine_damage_label    = $Panel/VBoxContainer/Stats/Mine/MineDamageLabel
@onready var dog_damage_label     = $Panel/VBoxContainer/Stats/Dog/DogDamageLabel
@onready var merc_damage_label    = $Panel/VBoxContainer/Stats/Merc/MercDamageLabel
@onready var mech_damage_label    = $Panel/VBoxContainer/Stats/Crawler/MechDamageLabel
@onready var panther_damage_label = $Panel/VBoxContainer/Stats/Roller/PantherDamageLabel
@onready var currency_label       = $Panel/VBoxContainer/Stats/CurrencyLabel

# Navigation buttons for D‐pad/keyboard
var nav_buttons: Array = []
var current_nav_index: int = 0

func _ready() -> void:
	# 1) Hide the panel by default
	pause_panel.visible = false
	get_tree().paused = false

	# 2) Make sure this CanvasLayer still processes when the game is paused
	process_mode = ProcessMode.PROCESS_MODE_ALWAYS
	_enable_ui_processing(self)
	set_process_unhandled_input(true)

	# 3) Build a simple up/down navigation list and hook up Resume/Quit
	nav_buttons = [ resume_button, options_button, quit_button ]
	for btn in nav_buttons:
		btn.focus_mode    = Control.FOCUS_ALL
		btn.process_mode  = ProcessMode.PROCESS_MODE_ALWAYS

	resume_button.connect("pressed", Callable(self, "_on_resume"))
	# options_button.connect("pressed", Callable(self, "_on_options"))  # (uncomment if you want Options)
	quit_button.connect("pressed", Callable(self, "_on_quit"))


func _process(_delta: float) -> void:
	# If any “Shop” UI is open, don’t allow pausing
	for shop_ui in get_tree().get_nodes_in_group("Shop"):
		if shop_ui is CanvasLayer and shop_ui.visible:
			return

	# Toggle pause when user presses the assigned action
	if Input.is_action_just_pressed(pause_button):
		if get_tree().paused:
			_unpause()
		else:
			_show_pause()
		return


func _input(event: InputEvent) -> void:
	# Only handle navigation if the pause panel is visible
	if not pause_panel.visible:
		return

	# D‐pad up/down to move focus
	if event is InputEventJoypadButton and event.pressed and (
		 event.button_index == JOY_BUTTON_DPAD_UP or
		 event.button_index == JOY_BUTTON_DPAD_DOWN
	):
		if event.button_index == JOY_BUTTON_DPAD_UP:
			_nav_prev()
		else:
			_nav_next()
		get_viewport().set_input_as_handled()
		return

	# “Jump” or “A” button to activate focused control
	if event.is_action_pressed("jump"):
		var focused = get_viewport().gui_get_focus_owner()
		if focused and focused is Button:
			focused.emit_signal("pressed")
			get_viewport().set_input_as_handled()


func _show_pause() -> void:
	$Music.play()
	get_tree().paused = true
	pause_panel.visible = true

	# Defer the stats update by one idle frame, so that the Player node’s _ready()
	# has already run and copied everything from PlayerStats into its own fields.
	call_deferred("_update_stats")

	_fit_panel_to_content()

	current_nav_index = 0
	nav_buttons[current_nav_index].grab_focus()


func _unpause() -> void:
	$Music.stop()
	pause_panel.visible = false
	get_tree().paused = false


func _update_stats() -> void:
	# Format string for “LabelText  number”
	var fmt = "%-4s %0d"

	# 1) Always read currency directly from the PlayerStats singleton
	currency_label.text = fmt % ["Currency:", Playerstats.currency]

	# 2) Read all damage values directly from PlayerStats
	grenade_damage_label.text = fmt % ["Grenade Damage:", Playerstats.grenade_damage]
	mine_damage_label.text    = fmt % ["Mine Damage:",    Playerstats.mine_damage]
	dog_damage_label.text     = fmt % ["Dog Damage:",     Playerstats.dog_damage]
	merc_damage_label.text    = fmt % ["Merc Damage:",    Playerstats.merc_damage]
	mech_damage_label.text    = fmt % ["Crawler Damage:", Playerstats.mech_damage]
	panther_damage_label.text = fmt % ["Roller Damage:",  Playerstats.panther_damage]


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
	# Resize the Panel to fit all VBoxContainer children + padding
	var size = panel.get_node("VBoxContainer").get_combined_minimum_size()
	panel.size = size + panel_padding * 2
	panel.get_node("VBoxContainer").position = panel_padding


func _enable_ui_processing(node) -> void:
	# Recursively ensure every CanvasItem under this node still processes when paused
	if node is CanvasItem:
		(node as CanvasItem).process_mode = ProcessMode.PROCESS_MODE_ALWAYS
	for child in node.get_children():
		_enable_ui_processing(child)
