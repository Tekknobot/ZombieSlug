# GrappleHook.gd
extends Node2D

# — Only one hook instance may exist at a time —
static var active_hook: Node2D = null

@export var point_count: int          = 20
@export var rope_length: float        = 320.0
@export var gravity: Vector2          = Vector2(0, 600)
@export var stiffness_iterations: int = 5
@export var rope_width: float         = 4.0

@export var retract_speed: float      = 200.0
@export var latch_offset: Vector2     = Vector2.ZERO

var segment_length: float
var current_length: float
var points:      PackedVector2Array
var old_points:  PackedVector2Array

var dangling:    bool     = true
var rope_active: bool     = false

var hook_pos:    Vector2
var hook_target: Node2D  = null

var _target_was_processing := false

@onready var muzzle        = get_parent().get_node("Soldier/Point")
@export var player: CharacterBody2D
@onready var end_detector  = $EndDetector as Area2D

func _ready():
	# singleton guard: if another hook exists, kill this one
	if active_hook:
		queue_free()
		return
	active_hook = self

	segment_length  = rope_length / float(point_count - 1)
	current_length  = rope_length

	points    = PackedVector2Array()
	old_points= PackedVector2Array()
	for i in range(point_count):
		points.append(muzzle.global_position)
		old_points.append(muzzle.global_position)

	end_detector.connect("body_entered", Callable(self, "_on_end_body_entered"))
	set_physics_process(true)

func _exit_tree():
	if active_hook == self:
		active_hook = null

func fire():
	dangling        = true
	hook_target     = null
	rope_active     = true
	current_length  = rope_length

func latch(_hook_pos: Vector2, _target: Node2D) -> void:
	dangling        = false
	hook_target     = _target
	hook_pos        = _hook_pos + latch_offset

	# disable target’s own physics & AI
	_target_was_processing = hook_target.is_physics_processing()
	hook_target.set_physics_process(false)
	hook_target.set_process(false)

	# prevent collisions between player & hooked zombie
	player.add_collision_exception_with(hook_target)
	hook_target.add_collision_exception_with(player)

func _on_end_body_entered(body: Node) -> void:
	if dangling and body.is_in_group("Zombie"):
		var last_pt = points[points.size() - 1]
		latch(last_pt, body as Node2D)

func _physics_process(delta):
	# — bail out if rope isn’t active or muzzle/player has been freed —
	if not rope_active:
		return
	if not is_instance_valid(muzzle) or not is_instance_valid(player):
		# clean up so we don’t keep crashing
		rope_active = false
		queue_free()
		return
		
	# 0) allow “mine” to finish off a hooked zombie
	if hook_target and Input.is_action_just_pressed("mine"):
		if hook_target.has_method("take_damage"):
			hook_target.take_damage(player.mine_damage)
		_release_target()
		return

	# 1) Verlet integration
	for i in range(points.size()):
		var p  = points[i]
		var op = old_points[i]
		var vel = p - op
		old_points[i] = p
		points[i] += vel + gravity * delta * delta

	# 2) pin start
	points[0] = muzzle.global_position

	# 3) pin end
	var last_idx = points.size() - 1
	if hook_target and is_instance_valid(hook_target):
		points[last_idx] = hook_target.global_position + latch_offset
	elif not dangling:
		points[last_idx] = hook_pos

	# 4) satisfy constraints
	for pass_idx in range(stiffness_iterations):
		for i in range(points.size() - 1):
			var a = points[i]
			var b = points[i + 1]
			var diff = b - a
			var dist = diff.length()
			var err  = dist - segment_length
			var n    = diff / dist
			if i == 0:
				points[i + 1] -= n * err
			else:
				points[i]     += n * err * 0.5
				points[i + 1] -= n * err * 0.5

	# move end_detector & snap target to end
	var last_pt = points[last_idx]
	end_detector.global_position = last_pt
	if hook_target:
		hook_target.global_position = last_pt - latch_offset

	queue_redraw()

	# auto-release at roof level
	if hook_target and last_pt.y <= player.global_position.y:
		_release_target()

func _draw():
	if not rope_active:
		return
	for i in range(points.size() - 1):
		draw_line(points[i] - global_position,
				  points[i + 1] - global_position,
				  Color.DARK_RED, rope_width)

func _release_target() -> void:
	if not hook_target:
		return

	var target     = hook_target
	var start_pos  = target.global_position
	var roof_pos   = Vector2(start_pos.x, player.global_position.y - 1)
	var duration   = 1.0   # seconds to reel up
	var elapsed    = 0.0

	# smoothly move zombie up while drawing rope
	while elapsed < duration and is_instance_valid(target):
		var dt = get_physics_process_delta_time()
		elapsed += dt
		var t = clamp(elapsed / duration, 0.0, 1.0)
		target.global_position = start_pos.lerp(roof_pos, t)

		var last_idx = points.size() - 1
		points[last_idx] = target.global_position + latch_offset
		end_detector.global_position = points[last_idx]
		queue_redraw()

		await get_tree().physics_frame

	# final snap & restore
	if is_instance_valid(target):
		target.global_position = roof_pos
		target.set_physics_process(_target_was_processing)
		target.set_process(true)
		player.remove_collision_exception_with(target)
		target.remove_collision_exception_with(player)

	# hide & reset rope
	rope_active    = false
	dangling       = true
	current_length = rope_length
	for i in range(points.size()):
		points[i]     = muzzle.global_position
		old_points[i] = muzzle.global_position

	hook_target = null
	queue_redraw()

	# now that everything’s done, free this hook
	queue_free()
