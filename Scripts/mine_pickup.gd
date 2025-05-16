extends Area2D

@export var amount:      int   = 3     # how many grenades this gives
@export var wiggle_angle: float = 10.0  # max degrees to each side
@export var wiggle_time:  float = 0.8   # full oscillation period
@export var lifetime:     float = 20.0  # seconds before auto-despawn

# make sure you have a child AudioStreamPlayer2D named "CollectSfx"
@onready var collect_sfx := $CollectSfx as AudioStreamPlayer2D

var _time: float = 0.0

func _ready() -> void:
	monitoring = true
	connect("body_entered", Callable(self, "_on_body_entered"))
	set_process(true)

	# auto-despawn after `lifetime` seconds
	var life_timer = Timer.new()
	life_timer.wait_time = lifetime
	life_timer.one_shot  = true
	add_child(life_timer)
	life_timer.connect("timeout", Callable(self, "queue_free"))
	life_timer.start()

func _process(delta: float) -> void:
	_time += delta
	rotation_degrees = sin(_time * TAU / wiggle_time) * wiggle_angle

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		# detach & play collect sound so it survives this node’s queue_free
		remove_child(collect_sfx)
		get_tree().get_current_scene().add_child(collect_sfx)
		collect_sfx.global_position = global_position
		collect_sfx.play()

		# give the player grenades
		Playerstats.add_mines(amount)
		Playerstats.add_currency(10)

		queue_free()
