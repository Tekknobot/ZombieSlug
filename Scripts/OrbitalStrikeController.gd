extends Node2D

@export var sfx_stream      : AudioStream
@export var flash_color     : Color  = Color(1,1,1,1)
@export var flash_time      : float  = 0.25
@export var laser_width     : float  = 1.0
@export var laser_color     : Color  = Color(1,0,0,1)
@export var laser_delay     : float  = 0.1   # seconds between each beam start
@export var laser_linger    : float  = 0.05  # time beam stays at full alpha
@export var laser_fade      : float  = 0.2   # fade-out duration
@export var laser_height    : float  = 400.0 # how far above the top of the screen beams start
@export var start_offset_x  : float  = 200.0 # max horizontal offset from target

const ExplosionScene = preload("res://Scenes/Effects/Explosion.tscn")

func _ready() -> void:
	# 1) play strike SFX
	if sfx_stream:
		var sfx = AudioStreamPlayer2D.new()
		sfx.stream = sfx_stream
		add_child(sfx)
		sfx.play()

	# 2) full-screen flash
	var layer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var flash = ColorRect.new()
	flash.color = flash_color
	flash.anchor_left   = 0.0
	flash.anchor_top    = 0.0
	flash.anchor_right  = 1.0
	flash.anchor_bottom = 1.0
	layer.add_child(flash)
	var tw = create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, flash_time)
	tw.tween_callback(Callable(layer, "queue_free"))

	# 3) wait for flash then start lasers
	await get_tree().create_timer(flash_time).timeout
	await _strike_all()
	queue_free()

func _strike_all() -> void:
	var vr    = get_viewport().get_visible_rect()
	var top_y = vr.position.y - laser_height

	# 1) snapshot valid zombies and their positions
	var targets := []
	for z in get_tree().get_nodes_in_group("Zombie"):
		if z is CharacterBody2D and z.has_method("take_damage") and is_instance_valid(z):
			targets.append({
				"zombie": z,
				"pos": z.global_position
			})

	# 2) iterate that static list
	for entry in targets:
		var z = entry.zombie
		var target_pos = entry.pos
		target_pos.y -= 8   # offset your strike

		# a) pick a random beam start
		var start_x = target_pos.x + randf_range(-start_offset_x, start_offset_x)
		var start_pos = Vector2(start_x, top_y)

		# b) draw the beam
		var beam = Line2D.new()
		beam.width         = laser_width
		beam.default_color = laser_color
		beam.add_point( beam.to_local(start_pos) )
		beam.add_point( beam.to_local(target_pos) )
		get_tree().get_current_scene().add_child(beam)

		# c) fade & free the beam
		var twb = get_tree().create_tween()
		twb.tween_interval(laser_linger)
		twb.tween_property(beam, "modulate:a", 0.0, laser_fade)
		twb.tween_callback(Callable(beam, "queue_free"))

		# d) spawn explosion
		var exp = ExplosionScene.instantiate()
		exp.global_position = target_pos
		get_tree().get_current_scene().add_child(exp)

		# e) apply damage if still alive
		if is_instance_valid(z):
			z.take_damage(9999)

		# f) wait before the next beam
		await get_tree().create_timer(laser_delay).timeout
