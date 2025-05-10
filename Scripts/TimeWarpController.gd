# res://Scripts/TimeWarpController.gd
extends Node

@export var duration:      float       = 3.0    # seconds of slow-mo
@export var slow_factor:   float       = 0.4    # global time_scale factor
@export var sfx_stream     = preload("res://Audio/SFX/tick-tock-104746.mp3")
@export var sfx_volume_db: float       = 6.0    # +6 dB boost

func _ready() -> void:
	# 1) Slow the entire game
	Engine.time_scale = slow_factor

	# 2) Optional SFX
	if sfx_stream:
		var sfx = AudioStreamPlayer2D.new()
		sfx.stream    = sfx_stream
		sfx.volume_db = sfx_volume_db
		add_child(sfx)
		sfx.play()

	# 3) Create an on-top CanvasLayer
	var layer = CanvasLayer.new()
	layer.layer = 100  # ensure it draws above game
	add_child(layer)

	# 4) Create & configure full-screen ColorRect
	var overlay = ColorRect.new()
	overlay.name  = "TimeWarpOverlay"
	overlay.color = Color(0.1, 0.2, 0.5, 0.25)
	overlay.anchor_left   = 0.0
	overlay.anchor_top    = 0.0
	overlay.anchor_right  = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_left   = 0
	overlay.offset_top    = 0
	overlay.offset_right  = 0
	overlay.offset_bottom = 0
	layer.add_child(overlay)

	# 5) Real-time timer (ignores time_scale)
	var t = Timer.new()
	t.wait_time = duration
	t.one_shot  = true
	add_child(t)
	t.connect("timeout", Callable(self, "_on_timeout"))
	t.start()

func _on_timeout() -> void:
	# restore normal speed
	Engine.time_scale = 1.0

	# remove our overlay
	if has_node("CanvasLayer/TimeWarpOverlay"):
		get_node("CanvasLayer/TimeWarpOverlay").queue_free()

	queue_free()
