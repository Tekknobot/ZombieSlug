# res://Scripts/LightningStrike.gd
extends Node2D

@export var line_color:     Color       = Color(0.8,0.9,1.0,1.0)
@export var line_width:     float       = 1.0
@export var segments:       int         = 12       # more = smoother bolt
@export var max_offset:     float       = 21.0     # jaggedness per segment
@export var flash_time:     float       = 0.15     # how long bolt lingers
@export var start_offset:   float       = 400.0    # how far above the viewport to begin
@export var sfx_stream:     AudioStream                # assign your lightning SFX here

const ExplosionScene = preload("res://Scenes/Effects/Explosion.tscn")

var _line:      Line2D
var _sfx_player: AudioStreamPlayer2D

func _ready() -> void:
	# 1) build the Line2D
	_line = Line2D.new()
	_line.width = line_width
	_line.default_color = line_color
	add_child(_line)

	# 2) build the AudioStreamPlayer2D if you gave us a stream
	if sfx_stream:
		_sfx_player = AudioStreamPlayer2D.new()
		_sfx_player.stream = sfx_stream
		add_child(_sfx_player)

func fire(target_pos: Vector2, damage: int) -> void:
	target_pos.y -= 8
	
	# play the sfx
	if _sfx_player:
		_sfx_player.play()

	# compute start way above the top of the viewport
	var vr = get_viewport().get_visible_rect()
	var start_pos = Vector2(target_pos.x, vr.position.y - start_offset)

	# build jagged bolt
	_line.clear_points()
	for i in range(segments + 1):
		var t = float(i) / segments
		var p = start_pos.lerp(target_pos, t)
		if i > 0 and i < segments:
			p.x += randf_range(-max_offset, max_offset)
		_line.add_point(to_local(p))

	# wait so player can see it
	await get_tree().create_timer(flash_time).timeout

	# explosion
	var exp = ExplosionScene.instantiate()
	exp.global_position = target_pos
	get_tree().get_current_scene().add_child(exp)

	# damage nearby zombies
	for z in get_tree().get_nodes_in_group("Zombie"):
		if z is CharacterBody2D and z.global_position.distance_to(target_pos) < 16:
			z.take_damage(damage)

	queue_free()
