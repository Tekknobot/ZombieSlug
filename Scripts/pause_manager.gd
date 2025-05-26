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
	# Enable UI processing for the panel and children when paused
	_enable_ui_processing(panel)

	# Build navigation list and ensure buttons accept focus
	nav_buttons = [resume_button, options_button, quit_button]
		# Build navigation list and ensure buttons accept focus
	nav_buttons = [resume_button, options_button, quit_button]
	for btn in nav_buttons:
		btn.focus_mode = Control.FOCUS_ALL
		# Connect using Callable and bind to pass button as argument
		var cb := Callable(self, "_on_button_pressed").bind(btn)
		btn.connect("pressed", cb)
		
func _process(_delta: float) -> void:
	# Prevent pausing when the shop UI is active (nodes in 'Shop' group)
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

	# Navigation and activation when paused
	if get_tree().paused and pause_panel.visible:
		if Input.is_action_just_pressed("ui_down"):
			_nav_next()
		elif Input.is_action_just_pressed("ui_up"):
			_nav_prev()
		elif Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump"):
			_on_button_pressed(nav_buttons[current_nav_index])

func _show_pause() -> void:
	get_tree().paused = true
	pause_panel.visible = true
	_update_stats()
	_fit_panel_to_content()
	current_nav_index = 0
	nav_buttons[current_nav_index].grab_focus()

func _unpause() -> void:
	pause_panel.visible = false
	get_tree().paused = false

func _update_stats() -> void:
	# Currency from Playerstats
	currency_label.text = "Currency: $%d" % Playerstats.currency
	
	# Damage stats from the player (shop stats)
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		var player = players[0]
		grenade_damage_label.text = "Grenade Damage: %d" % player.grenade_damage
		mine_damage_label.text    = "Mine Damage: %d" % player.mine_damage
		dog_damage_label.text     = "Dog Damage: %d" % player.dog_base_damage
		merc_damage_label.text    = "Merc Damage: %d" % player.merc_base_damage
		mech_damage_label.text    = "Crawler Damage: %d" % player.mech_base_damage
		panther_damage_label.text = "Roller Damage: %d" % player.mech_panther_base_damage

func _nav_next() -> void:
	current_nav_index = (current_nav_index + 1) % nav_buttons.size()
	nav_buttons[current_nav_index].grab_focus()

func _nav_prev() -> void:
	current_nav_index = (current_nav_index - 1 + nav_buttons.size()) % nav_buttons.size()
	nav_buttons[current_nav_index].grab_focus()

func _on_button_pressed(btn: Button) -> void:
	match btn:
		resume_button:
			_unpause()
		options_button:
			_unpause()
			get_tree().change_scene("res://Scenes/OptionsMenu.tscn")
		quit_button:
			get_tree().quit()

func _fit_panel_to_content() -> void:
	var content_size = $Panel/VBoxContainer.get_combined_minimum_size()
	panel.size = content_size + panel_padding * 2
	$Panel/VBoxContainer.position = panel_padding

func _enable_ui_processing(node) -> void:
	process_mode = ProcessMode.PROCESS_MODE_ALWAYS
	for child in node.get_children():
		_enable_ui_processing(child)
