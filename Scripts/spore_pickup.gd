extends Area2D

@export var gas_radius: float = 128.0    # radius of the spore cloud
@export var gas_duration: float = 3.0    # how long the cloud lingers
@export var gas_dps: float = 5.0         # damage per second to zombies
@export var lifetime: float = 20.0       # auto-despawn for unused pickup
@export var wiggle_angle: float = 10.0   # max degrees each way
@export var wiggle_time: float = 1.0     # seconds per full wiggle cycle

@onready var collect_sfx := $CollectSfx as AudioStreamPlayer2D
var _time: float = 0.0

func _ready() -> void:
	monitoring = true
	connect("body_entered", Callable(self, "_on_body_entered"))

	# auto-despawn after some time
	var t = Timer.new()
	t.wait_time = lifetime
	t.one_shot = true
	add_child(t)
	t.connect("timeout", Callable(self, "queue_free"))
	t.start()

	set_process(true)

func _process(delta: float) -> void:
	# wiggle back and forth for visual feedback
	_time += delta
	rotation_degrees = sin(_time * TAU / wiggle_time) * wiggle_angle

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("Player"):
		return

	# play collect sound (detach so it survives queue_free)
	remove_child(collect_sfx)
	get_tree().get_current_scene().add_child(collect_sfx)
	collect_sfx.global_position = global_position
	collect_sfx.play()

	# spawn the gas cloud at the player's location
	var cloud_scene = preload("res://Scenes/Effects/ToxicSporeController.tscn")
	var cloud = cloud_scene.instantiate()
	cloud.global_position = body.global_position
	cloud.radius = gas_radius
	cloud.duration = gas_duration
	cloud.dps = gas_dps
	get_tree().get_current_scene().add_child(cloud)

	queue_free()
