extends Area2D

@export var heal_percent: float = 0.0   # restores 15% of max health
@export var lifetime:    float = 20.0    # optional auto-despawn
@export var wiggle_angle: float = 10.0   # max degrees each way
@export var wiggle_time:  float = 1.0    # seconds per full cycle

@onready var collect_sfx := $CollectSfx as AudioStreamPlayer2D

var _time: float = 0.0

func _ready() -> void:
	monitoring = true
	connect("body_entered", Callable(self, "_on_body_entered"))
	
	# auto-despawn after some time
	var t = Timer.new()
	t.wait_time = lifetime
	t.one_shot  = true
	add_child(t)
	t.connect("timeout", Callable(self, "queue_free"))
	t.start()
	
	set_process(true)

func _process(delta: float) -> void:
	# wiggle rotation back and forth
	_time += delta
	rotation_degrees = sin(_time * TAU / wiggle_time) * wiggle_angle

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("Player"):
		return

	# play collect sound (detach so it survives this node’s queue_free)
	remove_child(collect_sfx)
	get_tree().get_current_scene().add_child(collect_sfx)
	collect_sfx.global_position = global_position
	collect_sfx.play()

	# compute heal amount (at least 1)
	var amount = int(Playerstats.max_health * heal_percent)
	if amount < 1:
		amount = 1

	# heal via negative damage
	#Playerstats.damage(-amount)

	# ――――――――――――――――――――――――――――――
	#  ADD CURRENCY BASED ON CURRENT LEVEL:
	#  For example, give 10 coins per player level.
	#  You can adjust the multiplier (10) as desired.
	var coins_awarded = Playerstats.level * 10
	Playerstats.add_currency(coins_awarded)
	# ――――――――――――――――――――――――――――――

	queue_free()
