extends Node2D

@export var start_offset:      float = 128.0
@export var duration:          float = 1.0
@export var interval:          float = 0.1
@export var bullets_per_tick:  int   = 5
@export var spread:            float = 100.0
@export var speed:             float = 200.0
@export var damage:            int   = 1
@export var fade_in_time:      float = 0.5    # how long for each bullet to fade in
@export var sfx_stream:        AudioStream

const BulletScene = preload("res://Scenes/Sprites/bullet.tscn")

var _timer:       Timer
var _elapsed:     float = 0.0
var _sfx_player:  AudioStreamPlayer2D

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = interval
	_timer.one_shot  = false
	add_child(_timer)
	_timer.connect("timeout", Callable(self, "_on_timer_timeout"))
	_timer.start()
	set_process(true)

	if sfx_stream:
		_sfx_player = AudioStreamPlayer2D.new()
		_sfx_player.stream = sfx_stream
		add_child(_sfx_player)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		_timer.stop()
		queue_free()

func _on_timer_timeout() -> void:
	if _sfx_player:
		_sfx_player.play()

	var vr = get_viewport().get_visible_rect()

	for i in range(bullets_per_tick):
		var x_off   = randf_range(-spread, spread)
		var spawn_x = global_position.x + x_off
		var spawn_y = vr.position.y - start_offset

		var bullet = BulletScene.instantiate()
		bullet.global_position = Vector2(spawn_x, spawn_y)
		bullet.direction       = Vector2.DOWN
		if bullet.has_meta("speed"):
			bullet.speed = speed

		# start fully transparent
		bullet.modulate.a = 0.0
		get_tree().get_current_scene().add_child(bullet)

		# fade it in
		var tw = bullet.create_tween()
		tw.tween_property(bullet, "modulate:a", 1.0, fade_in_time)
