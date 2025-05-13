extends Node2D

@export var duration: float = 3.0            # total cloud duration
@export var interval: float = 0.2            # seconds between each spore burst
@export var spores_per_interval: int = 5      # number of spore patches per burst
@export var radius: float = 128.0            # spawn radius around center
@export var dps: float = 5.0                 # damage per second for each patch
@export var patch_duration: float = 1.0      # how long each spore patch lasts
@export var sfx_stream: AudioStream          # optional sound when bursting

const SporePatchScene = preload("res://Scenes/Effects/SporePatch.tscn")

var _timer: Timer
var _elapsed: float = 0.0
var _sfx_player: AudioStreamPlayer2D

func _ready() -> void:
	# 1) set up repeating burst timer
	_timer = Timer.new()
	_timer.wait_time = interval
	_timer.one_shot = false
	add_child(_timer)
	_timer.connect("timeout", Callable(self, "_on_timer_timeout"))
	_timer.start()

	# 2) optional SFX player
	if sfx_stream:
		_sfx_player = AudioStreamPlayer2D.new()
		_sfx_player.stream = sfx_stream
		add_child(_sfx_player)

	set_process(true)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		_timer.stop()
		queue_free()

func _on_timer_timeout() -> void:
	# play burst sound
	if _sfx_player:
		_sfx_player.play()

	# spawn random spore patches around center
	for i in range(spores_per_interval):
		var angle = randf() * TAU
		var dist = randf() * radius
		var pos = global_position + Vector2(cos(angle), sin(angle)) * dist

		var patch = SporePatchScene.instantiate()
		patch.global_position = pos
		patch.dps = dps
		patch.duration = patch_duration
		get_tree().get_current_scene().add_child(patch)
