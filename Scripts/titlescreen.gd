# res://Scripts/TitleScreen.gd
extends CanvasLayer

@export var main_scene: PackedScene  # your gameplay scene

@onready var fade      := $Fade                     # full-screen ColorRect
@onready var menu      := $Menu                     # contains VStack → Label + HBoxContainer(Enter, Quit)
@onready var enter_btn := menu.get_node("VBoxContainer/HBoxContainer/Enter") as Button
@onready var quit_btn  := menu.get_node("VBoxContainer/HBoxContainer/Quit")  as Button
@onready var anim      := $Anim    as AnimationPlayer
@onready var music     := $AudioStreamPlayer2D

func _ready() -> void:
	# start fully black, hide menu
	fade.modulate.a = 1.0
	menu.visible = false

	# play your title music if you like
	if music.stream:
		music.play()

	# hook up the fade‐in animation
	anim.connect("animation_finished", Callable(self, "_on_fade_in_finished"))
	anim.play("fade_in")

	# wire up button clicks
	enter_btn.connect("pressed", Callable(self, "_on_enter_pressed"))
	quit_btn.connect("pressed",  Callable(self, "_on_quit_pressed"))

func _on_fade_in_finished(anim_name: String) -> void:
	if anim_name == "fade_in":
		# reveal the menu and focus “Enter”
		fade.modulate.a = 0.0
		menu.visible = true
		enter_btn.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not menu.visible:
		return

	# ignore analog stick motion
	if event is InputEventJoypadMotion:
		return

	# move focus with up/down (no diagonals)
	var left = Input.is_action_pressed("ui_left")
	var right = Input.is_action_pressed("ui_right")
	if event.is_action_pressed("ui_down") and not (left or right):
		if get_viewport().gui_get_focus_owner() == enter_btn:
			quit_btn.grab_focus()
			event.accept()
		return
	if event.is_action_pressed("ui_up") and not (left or right):
		if get_viewport().gui_get_focus_owner() == quit_btn:
			enter_btn.grab_focus()
			event.accept()
		return

	# Accept / Jump “clicks” whichever button’s focused
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		var f = get_viewport().gui_get_focus_owner()
		if f and f is Button:
			f.emit_signal("pressed")

func _on_enter_pressed() -> void:
	if main_scene:
		get_tree().change_scene_to_packed(main_scene)
	else:
		push_error("TitleScreen: No main_scene assigned!")

func _on_quit_pressed() -> void:
	get_tree().quit()
