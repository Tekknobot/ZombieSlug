extends Node2D

@export var start_offset: 	 float = 128.0
@export var duration:         float = 1.0    # how long the storm lasts
@export var interval:         float = 0.1    # seconds between each volley
@export var bullets_per_tick: int   = 5      # bullets per volley
@export var spread:           float = 100.0  # horizontal spread around controller
@export var speed:            float = 200.0  # fall speed of each bullet
@export var damage:           int   = 1      # damage per bullet
@export var sfx_stream:       AudioStream    # optional “rain” SFX

const BulletScene = preload("res://Scenes/Sprites/bullet.tscn")

var _timer:      Timer
var _elapsed:    float = 0.0
var _sfx_player: AudioStreamPlayer2D

func _ready() -> void:
	# set up repeating volley timer
	_timer = Timer.new()
	_timer.wait_time = interval
	_timer.one_shot  = false
	add_child(_timer)
	_timer.connect("timeout", Callable(self, "_on_timer_timeout"))
	_timer.start()
	set_process(true)

	# optional SFX player
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
	# play one-shot “rain” sound
	if _sfx_player:
		_sfx_player.play()

	# find how high the viewport sits
	var vr = get_viewport().get_visible_rect()

	for i in range(bullets_per_tick):
		# random horizontal offset around our controller
		var x_off = randf_range(-spread, spread)
		var spawn_x = global_position.x + x_off
		# spawn just above the top of the visible area
		var spawn_y = vr.position.y - start_offset

		var bullet = BulletScene.instantiate()
		bullet.global_position = Vector2(spawn_x, spawn_y)
		bullet.direction       = Vector2.DOWN
		# if your bullet scene exposes a speed property, override it:
		if bullet.has_meta("speed"):
			bullet.speed = speed

		get_tree().get_current_scene().add_child(bullet)
