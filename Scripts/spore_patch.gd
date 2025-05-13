extends Area2D

@export var dps: float = 5.0            # damage per second
@export var duration: float = 1.0       # how long this patch lasts
@export var slow_percent: float = 0.5   # fraction to slow (0.5 = 50%)
@export var fade_time: float = 0.5      # time at end to fade out effect

# Internal state
var _time: float = 0.0
var _inside_zombies: Array = []
var _original_speeds: Dictionary = {}
var _damage_accumulators: Dictionary = {}
var _initial_modulate: Color

func _ready() -> void:
	# Ensure area is monitoring overlaps
	monitoring = true
	monitorable = true
	# Enable collision shape
	if $CollisionShape2D:
		$CollisionShape2D.disabled = false

	# Capture initial modulate for fade
	_initial_modulate = modulate

	# Use physics process for collision and fade
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	_time += delta
	var remaining = duration - _time

	# Handle fade-out near end
	if remaining <= fade_time:
		var alpha = clamp(remaining / fade_time, 0.0, 1.0)
		modulate = Color(_initial_modulate.r, _initial_modulate.g, _initial_modulate.b, alpha)

	# Fetch overlapping bodies to apply DPS and slow
	var overlapping = get_overlapping_bodies()
	for body in overlapping:
		if body.is_in_group("Zombie") and body is CharacterBody2D:
			if not _inside_zombies.has(body):
				_on_zombie_enter(body)
			# accumulate and apply DPS
			var acc = _damage_accumulators.get(body, 0.0) + dps * delta
			var to_damage = int(acc)
			if to_damage > 0:
				if body.has_method("take_damage"):
					body.take_damage(to_damage)
				elif body.has_method("damage"):
					body.damage(to_damage)
				acc -= to_damage
			_damage_accumulators[body] = acc

	# Restore speed for zombies that left area
	for z in _inside_zombies.duplicate():
		if not overlapping.has(z):
			_on_zombie_exit(z)

	# Expire patch after duration
	if _time >= duration:
		for z in _inside_zombies:
			_restore_speed(z)
		_inside_zombies.clear()
		_damage_accumulators.clear()
		queue_free()

func _on_zombie_enter(body: CharacterBody2D) -> void:
	_inside_zombies.append(body)
	_damage_accumulators[body] = 0.0
	# immediate DPS tick
	var initial = int(dps)
	if initial > 0:
		if body.has_method("take_damage"):
			body.take_damage(initial)
		elif body.has_method("damage"):
			body.damage(initial)
	# apply slow
	if body.has_method("apply_slow"):
		body.apply_slow(slow_percent, duration - _time)
	elif body.has_meta("speed"):
		var orig = body.speed
		_original_speeds[body] = orig
		body.speed = orig * (1.0 - slow_percent)

func _on_zombie_exit(body: CharacterBody2D) -> void:
	_restore_speed(body)
	_inside_zombies.erase(body)
	_damage_accumulators.erase(body)

func _restore_speed(body: CharacterBody2D) -> void:
	if _original_speeds.has(body) and body.is_inside_tree():
		body.speed = _original_speeds[body]
		_original_speeds.erase(body)
