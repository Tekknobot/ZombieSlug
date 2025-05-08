# res://Scenes/Items/Mine.gd
extends Area2D

@export var fuse_time:     float = 1.5    # total seconds before detonation
@export var beep_interval: float = 0.5    # how often to “beep”
@export var damage:        int   = 3      # same damage as grenade

const ExplosionScene = preload("res://Scenes/Effects/Explosion.tscn")

@onready var beep_sfx   := $BeepSfx       as AudioStreamPlayer2D
@onready var fuse_timer := $FuseTimer     as Timer
@onready var beep_timer := $BeepTimer     as Timer

var _exploded: bool = false

func _ready() -> void:
	# begin the fuse countdown
	fuse_timer.wait_time = fuse_time
	fuse_timer.one_shot  = true
	fuse_timer.start()
	fuse_timer.connect("timeout", Callable(self, "_on_fuse_timeout"))

	# start the repeating beeps
	beep_timer.wait_time = beep_interval
	beep_timer.one_shot  = false
	beep_timer.start()
	beep_timer.connect("timeout", Callable(self, "_on_beep"))

	# also detonate on first zombie collision
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_beep() -> void:
	beep_sfx.play()

func _on_body_entered(body: Node) -> void:
	if _exploded:
		return
	if body.is_in_group("Zombie"):
		_explode()

func _on_fuse_timeout() -> void:
	if _exploded:
		return
	_explode()

func _explode() -> void:
	_exploded = true
	# stop timers so no further callbacks
	beep_timer.stop()
	fuse_timer.stop()

	# spawn the explosion effect
	var exp = ExplosionScene.instantiate()
	exp.global_position = global_position
	get_tree().get_current_scene().add_child(exp)

	# deal damage immediately to overlapping bodies 
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(damage)

	queue_free()
