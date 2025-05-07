extends ColorRect

@export var fade_duration := 1.0   # seconds to fade out

var _elapsed := 0.0

func _ready() -> void:
	# start fully opaque
	modulate.a = 1.0
	set_process(true)

func _process(delta: float) -> void:
	_elapsed += delta
	# compute how far through the fade we are (0→1)
	var t = clamp(_elapsed / fade_duration, 0.0, 1.0)
	# lerp alpha from 1→0
	modulate.a = lerp(1.0, 0.0, t)
	if t >= 1.0:
		# once done, stop and hide
		set_process(false)
		hide()
