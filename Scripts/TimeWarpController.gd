# res://Scripts/TimeWarpController.gd
extends Node

@export var duration:      float       = 3.0    # seconds of slow-mo
@export var slow_factor:   float       = 0.4    # global time_scale factor
@export var sfx_stream     = preload("res://Audio/SFX/tick-tock-104746.mp3")
@export var sfx_volume_db: float       = 12.0    # +6 dB boost

func _ready() -> void:
	Engine.time_scale = slow_factor

	if sfx_stream:
		var sfx = AudioStreamPlayer.new()
		sfx.stream    = sfx_stream
		sfx.volume_db = sfx_volume_db
		add_child(sfx)
		sfx.play()

	# overlay setup… (unchanged)
	var layer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var overlay = ColorRect.new()
	overlay.name           = "TimeWarpOverlay"
	overlay.color          = Color(0.1,0.2,0.5,0.25)
	overlay.anchor_left    = 0
	overlay.anchor_top     = 0
	overlay.anchor_right   = 1
	overlay.anchor_bottom  = 1
	overlay.offset_left    = 0
	overlay.offset_top     = 0
	overlay.offset_right   = 0
	overlay.offset_bottom  = 0
	layer.add_child(overlay)

	var t = Timer.new()
	t.wait_time = duration
	t.one_shot  = true
	add_child(t)
	t.connect("timeout", Callable(self, "_on_timeout"))
	t.start()

func _on_timeout() -> void:
	Engine.time_scale = 1.0
	if has_node("CanvasLayer/TimeWarpOverlay"):
		get_node("CanvasLayer/TimeWarpOverlay").queue_free()
	queue_free()
