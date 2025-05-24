# res://Scripts/BlackHolePickup.gd

extends Area2D

@export var radius:            float = 256.0  # how far the black hole reaches
@export var pull_speed:        float = 200.0  # how fast zombies are pulled in (px/sec)
@export var damage:            int   = 9999      # damage dealt when a zombie reaches the center
@export var effect_duration:   float = 3.0    # how long the black hole remains active

@export var wiggle_angle:      float = 10.0   # max degrees to each side
@export var wiggle_time:       float = 0.8    # full oscillation period
@export var lifetime:          float = 20.0   # seconds before auto‐despawn if unused

@onready var collect_sfx := $CollectSfx as AudioStreamPlayer2D
@export var warpzone_scene: PackedScene = preload("res://Scenes/Sprites/warpzone.tscn")

var _time:    float = 0.0
var _active:  bool  = false

func _ready() -> void:
	monitoring = true
	set_process(true)
	connect("body_entered", Callable(self, "_on_body_entered"))

	# auto‐despawn if never collected
	var life_timer = Timer.new()
	life_timer.wait_time = lifetime
	life_timer.one_shot  = true
	add_child(life_timer)
	life_timer.connect("timeout", Callable(self, "queue_free"))
	life_timer.start()

func _process(delta: float) -> void:
	# wiggle animation
	_time += delta
	rotation_degrees = sin(_time * TAU / wiggle_time) * wiggle_angle

	if _active:
		# suck in and damage zombies
		for z in get_tree().get_nodes_in_group("Zombie"):
			if z is CharacterBody2D and is_instance_valid(z):
				var d = global_position.distance_to(z.global_position)
				if d <= radius:
					# pull them in
					z.global_position = z.global_position.move_toward(
						global_position, pull_speed * delta
					)
					# if they're very close, deal damage
					if d <= 16.0 and z.has_method("take_damage"):
						z.take_damage(damage)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player") and not _active:
		# spawn a warp-zone effect at pickup
		var wz = warpzone_scene.instantiate()
		wz.global_position = global_position
		wz.get_child(0).emitting = true
		get_tree().get_current_scene().add_child(wz)

		# play collect sound
		remove_child(collect_sfx)
		get_tree().get_current_scene().add_child(collect_sfx)
		collect_sfx.global_position = global_position
		collect_sfx.play()

		# activate the black hole effect
		_active = true
		$CollisionShape2D.disabled = true
		visible = false
		
		# after effect_duration, destroy this node
		await get_tree().create_timer(effect_duration).timeout
		wz.get_child(0).emitting = true
		wz.queue_free()
		queue_free()
