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
	menu.visible     = false
	fade.modulate.a  = 0.0
	get_tree().paused = false
	GameOverSfx.stop()
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	get_tree().quit()
