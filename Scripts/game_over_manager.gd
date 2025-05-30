# res://Scripts/GameOverManager.gd
extends CanvasLayer

@export var fade_duration := 0.5    # seconds to fade in
@export var fade_target   := 0.8    # alpha at end of fade

@onready var fade        	:= $Fade
@onready var menu        	:= $Menu
@onready var restart_btn 	:= $Menu/VBoxContainer/HBoxContainer/Restart
@onready var quit_btn    	:= $Menu/VBoxContainer/HBoxContainer/Quit
@onready var GameOverSfx    := $GameOverSfx

var _is_fading := false
var _fade_time := 0.0

const MAIN_SCENE_PATH := "res://Scenes/Main.tscn"

func _ready() -> void:
	process_mode = ProcessMode.PROCESS_MODE_ALWAYS

	fade.modulate.a = 0.0
	menu.visible   = false

	restart_btn.connect("pressed", Callable(self, "_on_restart_pressed"))
	quit_btn.connect(   "pressed", Callable(self, "_on_quit_pressed"))

	set_process(false)


func show_game_over() -> void:
	_fade_time = 0.0
	_is_fading = true
	set_process(true)

func _process(delta: float) -> void:
	if _is_fading:
		_fade_time += delta
		var t = clamp(_fade_time / fade_duration, 0.0, 1.0)
		fade.modulate.a = lerp(0.0, fade_target, t)
		if t >= 1.0:
			_is_fading = false
			set_process(false)
			menu.visible      = true
			GameOverSfx.play()      # <<-- play the music here			
			restart_btn.grab_focus()
			get_tree().paused = true

func _unhandled_input(event: InputEvent) -> void:
	if menu.visible and event.is_action_pressed("jump"):
		# ask the *viewport* who currently has UI focus:
		var focussed = get_viewport().gui_get_focus_owner()
		if focussed and focussed is Button:
			focussed.emit_signal("pressed")
			
func _on_restart_pressed() -> void:
	# reset player
	Playerstats.reset_stats()
	menu.visible       = false
	fade.modulate.a    = 0.0
	get_tree().paused  = false
	GameOverSfx.stop()

	# switch back to main scene
	var tree = get_tree()
	if tree.has_method("change_scene_to_file"):
		# Godot 4
		tree.change_scene_to_file(MAIN_SCENE_PATH)
	elif tree.has_method("change_scene"):
		# Godot 3
		tree.change_scene(MAIN_SCENE_PATH)
	else:
		push_error("Can't change to main scene: no scene‐change API found")


func _on_quit_pressed() -> void:
	get_tree().quit()
