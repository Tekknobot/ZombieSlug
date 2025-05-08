extends Area2D

@export var amount:      int   = 5     # how many mines this gives
@export var wiggle_angle: float = 10.0  # max degrees to each side
@export var wiggle_time:  float = 0.8   # time (in seconds) to complete from center → max → center → min → center

var _time: float = 0.0

func _ready() -> void:
	monitoring = true
	connect("body_entered", Callable(self, "_on_body_entered"))
	set_process(true)

func _process(delta: float) -> void:
	_time += delta
	# full cycle = wiggle_time seconds, so we divide TAU by wiggle_time
	rotation_degrees = sin(_time * TAU / wiggle_time) * wiggle_angle

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		if Playerstats.use_grenade():
			Playerstats.add_grenade(amount)
		queue_free()
