# DashAfterImage.gd
extends AnimatedSprite2D

@export var lifetime: float = 0.3    # how long it takes to fade
@export var start_alpha: float = 0.6 # initial transparency

func _ready() -> void:
	# start at semi-opaque
	modulate.a = start_alpha

	# tween alpha → 0 over `lifetime`, then queue_free()
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, lifetime) \
	  .set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	tw.tween_callback(Callable(self, "queue_free"))
