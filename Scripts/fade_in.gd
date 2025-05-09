# Fader.gd
extends CanvasLayer

@export var fade_duration: float = 0.8   # how long the fade lasts

@onready var fade_rect := $Fade as ColorRect

var _elapsed := 0.0

func _ready() -> void:
	# start fully opaque:
	fade_rect.color.a = 1.0
	set_process(true)

func _process(delta: float) -> void:
	_elapsed += delta
	var t = clamp(_elapsed / fade_duration, 0.0, 1.0)
	# lerp alpha from 1 → 0
	fade_rect.color.a = 1.0 - t

	if t >= 1.0:
		# we're done; hide the rect and stop processing
		fade_rect.color.a = 0.0
		set_process(false)
