# res://Scripts/FreezeController.gd
extends Node2D

@export var duration:    float         = 3.0     # how long to keep zombies frozen
@export var sfx_stream:  AudioStream               # optional “freeze” sound

const FROST_COLOR      = Color(0.5, 0.8, 1.0, 1.0)
const FreezeCloudScene = preload("res://Scenes/Effects/FreezeCloud.tscn")

var _timer:      Timer
var _sfx_player: AudioStreamPlayer2D
var _frozen:     Array = []

func _ready() -> void:
	# 1) optional SFX
	if sfx_stream:
		_sfx_player = AudioStreamPlayer2D.new()
		_sfx_player.stream = sfx_stream
		add_child(_sfx_player)
		_sfx_player.play()

	# 2) freeze logic + spawn cloud over each
	for z in get_tree().get_nodes_in_group("Zombie"):
		if z is CharacterBody2D:
			# record so we can restore later
			_frozen.append(z)

			# stop their processing
			z.set_physics_process(false)
			z.set_process(false)

			# tint their sprite blue
			if z.has_node("AnimatedSprite2D"):
				var a = z.get_node("AnimatedSprite2D") as AnimatedSprite2D
				a.modulate = FROST_COLOR

			# spawn a freeze‐cloud effect at their position
			var cloud = FreezeCloudScene.instantiate()
			cloud.global_position = z.global_position
			cloud.global_position.y -= 16
			cloud.emitting = true
			get_tree().get_current_scene().add_child(cloud)

	# 3) start countdown to unfreeze
	_timer = Timer.new()
	_timer.wait_time = duration
	_timer.one_shot  = true
	add_child(_timer)
	_timer.connect("timeout", Callable(self, "_on_unfreeze"))
	_timer.start()

func _on_unfreeze() -> void:
	# restore each zombie
	for z in _frozen:
		if is_instance_valid(z):
			z.set_physics_process(true)
			z.set_process(true)
			if z.has_node("AnimatedSprite2D"):
				var a = z.get_node("AnimatedSprite2D") as AnimatedSprite2D
				a.modulate = Color(1, 1, 1, 1)

	queue_free()
