# Zombie.gd
extends CharacterBody2D

@export var xp_award: int         = 5
@export var min_speed: float      = 25.0
@export var max_speed: float      = 75.0
@export var attack_range: float   = 24.0
@export var attack_damage: int    = 1
@export var attack_cooldown: float= 0.1
@export var max_health: int       = 5
@export var gravity: float        = 900.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

@onready var hit_sfx: AudioStreamPlayer2D   = $HitSfx
@onready var death_sfx: AudioStreamPlayer2D = $DeathSfx
@onready var health_label: Label = $HealthLabel

# Internal state
var speed: float   = 0.0
var health: int    = 0
var is_dead: bool  = false
var attack_timer: Timer

# shaking state
var _shake_active:    bool    = false
var _shake_timer:     Timer
var _shake_orig_pos:  Vector2
var _shake_magnitude: float   = 4.0

signal died(pos: Vector2)

var behavior: String = ""
@export var leap_cooldown: float          = 1.0
@export var leap_speed_multiplier: float = 2.0
@export var leap_vertical_velocity: float= -300.0
var can_leap: bool    = true
var leap_timer: Timer

@export var explosion_radius:        float = 128.0
@export var explosion_damage:        int   = 3
var is_charging: bool   = false

@export var spore_scene: PackedScene = preload("res://Scenes/Effects/SporePatch.tscn")
@export var spore_interval: float   = 2.0   # seconds between spore drops
var _spore_timer: Timer = null

@export var chain_radius: float = 48.0
@export var chain_damage: int   = 2
var _lightning_fx := preload("res://Scenes/Effects/Chain_Bolt.tscn")

@export var deflect_speed_multiplier: float = 1.2
@export var shield_health: int = 8  # maybe tougher

var is_roaming: bool = false
@export var roam_time: float = 2.0   # seconds to roam before stopping
var _ignored_surfaces: Array[PhysicsBody2D] = []

const LAYER_Z_FLOOR    := 0
const LAYER_Z_SIDEWALK := 2
const LAYER_Z_STREET   := 4

@export var spawn_layer: int = 0
var has_exploded: bool = false

# helper map
var _layer_map = {
	"Floor":    LAYER_Z_FLOOR,
	"Sidewalk": LAYER_Z_SIDEWALK,
	"Street":   LAYER_Z_STREET
}

func _ready() -> void:
	randomize()
	speed  = randi_range(int(min_speed), int(max_speed))
	health = max_health
	update_health_label()
	print("Zombie speed=", speed, "health=", health)

	attack_timer = Timer.new()
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot  = false
	add_child(attack_timer)
	attack_timer.connect("timeout", Callable(self, "_on_attack_timeout"))

	if behavior == "leaper":
		# set up a dedicated timer for leaps
		leap_timer = Timer.new()
		leap_timer.wait_time = leap_cooldown
		leap_timer.one_shot  = true
		add_child(leap_timer)
		leap_timer.connect("timeout", Callable(self, "_on_leap_timeout"))

	if behavior == "charger":
		anim.play("move")  # ensure it’s in move state

	if behavior == "spore":
		# set up the repeating spore‐drop timer
		_spore_timer = Timer.new()
		_spore_timer.wait_time = spore_interval
		_spore_timer.one_shot  = false
		add_child(_spore_timer)
		#_spore_timer.start()
		_spore_timer.connect("timeout", Callable(self, "_drop_spore"))

	if behavior == "shield":
		health = max_health
		# apply the outline shader to AnimatedSprite2D
		anim.material = ShaderMaterial.new()
		anim.material.shader = preload("res://Shaders/ShieldEffect.tres")
			
	spawn_layer = z_index
						
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# find player
	var players = get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		return
	var p = players[0] as CharacterBody2D

	var same_ground: bool = (p.z_index == self.z_index)
	if same_ground and _ignored_surfaces.size() > 0:
		_restore_ground_collisions()
		
	# check for bullet collisions
	for i in range(get_slide_collision_count()):
		var col = get_slide_collision(i).get_collider()
		if col and col.is_in_group("Bullet") and col.has_method("get_velocity"):
			_deflect_bullet(col)

	# find your target first
	var players_target = get_tree().get_nodes_in_group("Player")
	if players_target.is_empty():
		return
	var player_pos        = players_target[0].global_position
	var to_player_target  = player_pos - global_position
	var player_dist       = to_player_target.length()

	# initial charger explode (will be skipped here now)
	if behavior == "charger" and player_dist <= 32 and same_ground:
		# don't explode here anymore
		pass

	# 1) If any homing grenades exist, chase the nearest one instead of the player:
	var grenades = get_tree().get_nodes_in_group("TNT_yellow")
	var target: Node2D = null
	if not grenades.is_empty():
		# find closest grenade
		var best_dist = INF
		for g in grenades:
			if not (g is Node2D):
				continue
			var d = global_position.distance_to(g.global_position)
			if d < best_dist:
				best_dist = d
				target    = g
	else:
		# fall back to the player
		if players.is_empty():
			if not attack_timer.is_stopped():
				attack_timer.stop()
			return
		target = players[0] as CharacterBody2D

	# 2) move/tackle exactly as before, but using `target`:
	var to_target  = target.global_position - global_position
	var dist       = to_target.length()
	var dx         = to_target.x
	var DEADZONE   := 1.0
	
	if dist > attack_range:
		velocity.x = sign(to_target.x) * speed
		if not attack_timer.is_stopped():
			attack_timer.stop()
		if anim.animation != "move":
			anim.play("move")
		# only re-flip if target is well to one side
		if abs(dx) > DEADZONE:
			anim.flip_h = velocity.x > 0
	else:
		velocity.x = 0
		if attack_timer.is_stopped():
			attack_timer.start()
		if anim.animation != "attack":
			death_sfx.play()
			anim.play("attack")
		anim.flip_h = to_target.x > 0
		# similarly, only flip during attack if target isn’t directly underneath
		if abs(dx) > DEADZONE:
			anim.flip_h = dx > 0

	# 3) gravity + slide
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	move_and_slide()

	# --- DYNAMIC GROUND LAYER UPDATE ---
	# look at your floor collisions this frame and pick the highest-priority surface
	for i in range(get_slide_collision_count()):
		var col = get_slide_collision(i).get_collider()
		if col is PhysicsBody2D:
			var new_layer: int = z_index
			if col.is_in_group("Street"):
				new_layer = _layer_map["Street"]
			elif col.is_in_group("Sidewalk"):
				new_layer = _layer_map["Sidewalk"]
			elif col.is_in_group("Floor") and not col.is_in_group("Sidewalk"):
				new_layer = _layer_map["Floor"]
			# if it actually changed, update z_index & re-ignore non-current grounds
			if new_layer != z_index:
				z_index = new_layer
				_restore_ground_collisions()
				_ignore_non_target_ground(col.global_position.y)
			break  # stop after first valid ground collision

	# 4) recompute same_ground now that z_index is correct
	same_ground = (p.get_child(0).z_index == self.z_index)
	player_dist = p.global_position.distance_to(global_position)

	# 5) final charger explode check
	if behavior == "charger" and player_dist <= 24 and same_ground:
		_explode()
						
func _on_attack_timeout() -> void:
	for p in get_tree().get_nodes_in_group("Player"):
		if not (p is CharacterBody2D and p.has_method("take_damage")):
			continue

		var dist = global_position.distance_to(p.global_position)
		# grab the player's sprite layer:
		var player_layer = p.get_node("AnimatedSprite2D").z_index
		# is that exactly one below this zombie root?
		var same_ground = (player_layer == self.z_index)

		print("DEBUG melee: player_layer= ", player_layer,"  zombie_root_z = ", self.z_index)

		if dist <= attack_range and same_ground:
			p.take_damage(attack_damage)
			print("Zombie attacked player for ", attack_damage)
		else:
			attack_timer.stop()
			start_roaming()
		return  # only need the first matching Player
			
func _die_cleanup() -> void:
	# 1) prevent any further _physics_process/attack logic
	self.is_dead = true

	# if this was a spore zombie, drop one last patch on death
	if behavior == "spore" and is_instance_valid(self):
		_drop_spore()

	if behavior == "chain" and is_instance_valid(self):
		_do_chain_reaction()
	
	# 2) remove from the “Zombie” group
	remove_from_group("Zombie")

	# 3) stop and tear down the attack timer so it never calls back
	if attack_timer:
		attack_timer.stop()
		attack_timer.disconnect("timeout", Callable(self, "_on_attack_timeout"))
		attack_timer.queue_free()

	# 4) turn off ALL collisions on this body
	collision_layer = 0
	collision_mask  = 0

	# 5) disable every CollisionShape2D child
	for shape in get_children():
		if shape is CollisionShape2D:
			shape.disabled = true

	# 6) if you also have an Area2D hitbox, disable its monitoring
	if has_node("Hitbox"):
		$Hitbox.monitoring = false

func _do_chain_reaction() -> void:
	# Track which zombies we’ve already struck
	var visited: Array[CharacterBody2D] = [ self ]
	# Queue of positions to chain from (start with this zombie’s position)
	var queue_positions: Array[Vector2]  = [ global_position ]

	# Origin spark
	_spawn_chain_bolt(global_position, global_position)

	while queue_positions.size() > 0:
		var src_pos = queue_positions.pop_front()

		# Grab a fresh list of all live zombies
		for other_node in get_tree().get_nodes_in_group("Zombie").duplicate():
			# Must still exist and be a CharacterBody2D
			if not is_instance_valid(other_node) or not (other_node is CharacterBody2D):
				continue
			var other = other_node as CharacterBody2D
			# Skip if we’ve already hit it
			if other in visited:
				continue

			# If within chain radius of our current source position
			if src_pos.distance_to(other.global_position) <= chain_radius:
				# Spawn the bolt
				_spawn_chain_bolt(src_pos, other.global_position)
				# Deal chain damage
				other.take_damage(max_health/4)

				# Remember we’ve hit this one
				visited.append(other)
				# If it’s still alive, chain from its position;
				# if it died, use its last known position
				queue_positions.append(other.global_position)

				# Small pause so you can actually see the chain crawl
				await get_tree().create_timer(0.1).timeout

func _spawn_chain_bolt(start_pos: Vector2, end_pos: Vector2) -> void:
	# 1) Instantiate the bolt scene
	var bolt_scene = preload("res://Scenes/Effects/Chain_Bolt.tscn")
	var bolt = bolt_scene.instantiate()

	# 2) Make sure it isn’t in the “Zombie” group (so you don’t pick it up again)
	if bolt.is_in_group("Zombie"):
		bolt.remove_from_group("Zombie")

	start_pos.y -= 16
	
	# 3) Position and add to the world *before* you call its play() method
	bolt.global_position = start_pos
	get_tree().get_current_scene().add_child(bolt)

	# 4) Kick off the bolt’s own logic—no set_target, just use its play() API
	if bolt.has_method("play"):
		bolt.play(end_pos)
		
# Briefly tint the sprite red, then restore
func flash() -> void:
	var orig = anim.modulate
	anim.modulate = Color(1, 0, 0, 1)
	await get_tree().create_timer(0.1).timeout
	anim.modulate = orig

func start_shake(duration: float = 0.2, magnitude: float = 4.0) -> void:
	if _shake_active:
		return
	_shake_active    = true
	_shake_orig_pos  = position
	_shake_magnitude = magnitude

	# one-shot timer to end the shake
	_shake_timer = Timer.new()
	_shake_timer.wait_time = duration
	_shake_timer.one_shot  = true
	add_child(_shake_timer)
	_shake_timer.connect("timeout", Callable(self, "_on_shake_timeout"))
	_shake_timer.start()

	# enable processing so _process() will run
	set_process(true)

func _process(delta: float) -> void:
	if _shake_active:
		# jitter around original spot
		position = _shake_orig_pos + Vector2(
			randf_range(-_shake_magnitude, _shake_magnitude),
			randf_range(-_shake_magnitude, _shake_magnitude)
		)

func _on_shake_timeout() -> void:
	# end shake, restore exact position
	_shake_active = false
	position      = _shake_orig_pos
	set_process(false)
	_shake_timer.queue_free()

func update_health_label() -> void:
	if not is_instance_valid(health_label):
		return
			
	# Show “X HP”
	health_label.text = "%d" % health
	# Choose a color tier: >66% green, >33% yellow, else red
	var pct := float(health) / float(max_health)
	var tint := Color(1, 1, 1)
	if pct > 0.66:
		tint = Color(0, 1, 0)
	elif pct > 0.33:
		tint = Color(1, 1, 0)
	else:
		tint = Color(1, 0, 0)
	health_label.modulate = tint

func _drop_spore() -> void:
	# spawn the patch at the zombie's feet
	var patch = spore_scene.instantiate()
	patch.global_position = Vector2(global_position.x, global_position.y)
	patch.global_position.y -= 16
	patch.duration = 5
	get_tree().get_current_scene().add_child(patch)

func _deflect_bullet(bullet):
	# 1) grab its incoming velocity
	var in_vel = bullet.get_velocity()
	# 2) compute reflection off the zombie’s facing normal
	var normal = (bullet.global_position - global_position).normalized()
	var out_vel = in_vel.bounced(normal) * deflect_speed_multiplier
	# 3) relocate bullet slightly so it doesn’t re-hit immediately
	bullet.global_position = global_position + normal * (bullet.shape.get_extents().x + 2)
	# 4) apply new velocity
	if bullet.has_method("set_velocity"):
		bullet.set_velocity(out_vel)
	# 5) optionally play a clang sound
	$ShieldClangSfx.play()

func start_roaming() -> void:
	if is_roaming:
		return
	is_roaming = true

	# pick a random horizontal direction
	var dir: int
	if randf() < 0.5:
		dir = -1
	else:
		dir = 1

	# move and play "move" anim
	velocity.x = dir * speed
	anim.play("move")
	anim.flip_h = dir > 0

	# after roam_time seconds, stop
	await get_tree().create_timer(roam_time).timeout

	velocity.x = 0
	anim.play("default")
	is_roaming = false

# helper: ignore any ground whose Y ≠ target_y
func _ignore_non_target_ground(target_y: float) -> void:
	# floor (excluding sidewalks)
	for f in get_tree().get_nodes_in_group("Floor"):
		if not f.is_in_group("Sidewalk") and f is PhysicsBody2D:
			if abs(f.global_position.y - target_y) > 1.0:
				add_collision_exception_with(f)
				_ignored_surfaces.append(f)
	# sidewalks
	for sw in get_tree().get_nodes_in_group("Sidewalk"):
		if sw is PhysicsBody2D and abs(sw.global_position.y - target_y) > 1.0:
			add_collision_exception_with(sw)
			_ignored_surfaces.append(sw)
	# streets
	for st in get_tree().get_nodes_in_group("Street"):
		if st is PhysicsBody2D and abs(st.global_position.y - target_y) > 1.0:
			add_collision_exception_with(st)
			_ignored_surfaces.append(st)

# helper: restore all previously ignored surfaces
func _restore_ground_collisions() -> void:
	for s in _ignored_surfaces:
		if is_instance_valid(s):
			remove_collision_exception_with(s)
	_ignored_surfaces.clear()

# —————————————————————————————————————————————————————
# 2) New central death method, containing every bit of your old logic
# —————————————————————————————————————————————————————
func _die() -> void:
	if is_dead:
		return
	self.is_dead = true

	# show “0 HP”, hide the label
	update_health_label()
	health_label.hide()

	# 1) award kill + XP
	Playerstats.add_kill(xp_award)

	# 2) play death SFX
	death_sfx.play()

	# 3) Define your pickups and their relative weights (including “nothing”)
	var drops = [
		{ "scene": null,                                                   "weight": 40.0 },  # nothing
		{ "scene": preload("res://Scenes/Sprites/TNTPickup.tscn"),          "weight": 1  },
		{ "scene": preload("res://Scenes/Sprites/TNT_YellowPickup.tscn"),   "weight": 1  },
		{ "scene": preload("res://Scenes/Sprites/MinePickup.tscn"),         "weight": 1  },
		{ "scene": preload("res://Scenes/Sprites/FreezePickup.tscn"),       "weight": 1  },
		{ "scene": preload("res://Scenes/Sprites/HealthPickup.tscn"),       "weight": 0.75 },
		{ "scene": preload("res://Scenes/Sprites/BulletPickup.tscn"),       "weight": 0.5  },
		{ "scene": preload("res://Scenes/Sprites/LightningPickup.tscn"),    "weight": 0.5  },
		{ "scene": preload("res://Scenes/Sprites/FirestormPickup.tscn"),    "weight": 0.5  },
		{ "scene": preload("res://Scenes/Sprites/SporePickup.tscn"),        "weight": 0.5  },
		{ "scene": preload("res://Scenes/Sprites/TimeWarpPickup.tscn"),     "weight": 0.0  },
		{ "scene": preload("res://Scenes/Sprites/GlitchPickup.tscn"),       "weight": 0.5  },
		{ "scene": preload("res://Scenes/Sprites/OrbitalPickup.tscn"),      "weight": 0.25 },
		{ "scene": preload("res://Scenes/Sprites/StarPickup.tscn"),         "weight": 0.25 },
	]

	# 4) pick one based on weights
	var total_weight = 0.0
	for drop in drops:
		total_weight += drop.weight
	var r = randf() * total_weight
	for drop in drops:
		r -= drop.weight
		if r <= 0:
			if drop.scene != null:
				var instance = drop.scene.instantiate()
				instance.global_position = global_position
				instance.global_position.y -= 8
				get_tree().get_current_scene().add_child(instance)
			break

	# 5) any extra “on‐death” behavior
	_die_cleanup()           # your existing timer-stop & collision teardown
	$Blood.emitting = true   # blood particle burst

	# (you were adding XP twice—if that was intentional leave it, otherwise drop one)
	Playerstats.add_kill(xp_award)

	# 6) single died signal for your spawner
	emit_signal("died", global_position)

	# 7) play death animation, wait, then free
	anim.play("death")
	await get_tree().create_timer(1).timeout
	queue_free()

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return

	hit_sfx.play()
	flash()

	health -= amount
	update_health_label()
	print("Zombie took %d damage; remaining=%d" % [amount, health])

	if health <= 0:
		match behavior.to_lower():
			"charger":
				_explode()
			"spore", "shield", "chain", "":
				_die()

# —————————————————————————————————————————————————————
# 3) In `_explode`, remove any direct `emit_signal("died",…)`, `queue_free()` or sfx calls,
#    and just call `_die()` after your explosion effect and area-damage:
# —————————————————————————————————————————————————————
func _explode() -> void:
	if has_exploded:
		return
	has_exploded = true
		
	if self.is_dead:
		return
	# play explosion VFX
	var FX = preload("res://Scenes/Effects/Explosion.tscn").instantiate()
	FX.global_position = global_position + Vector2(0, -8)
	get_tree().get_current_scene().add_child(FX)

	# area-damage to player(s) and other zombies…
	for p in get_tree().get_nodes_in_group("Player"):
		if p.global_position.distance_to(global_position) <= 32:
			p.take_damage(p.max_health/2)
	for z in get_tree().get_nodes_in_group("Zombie"):
		if z != self and z is CharacterBody2D:
			if global_position.distance_to(z.global_position) <= explosion_radius:
				z.take_damage(explosion_damage)
	_die()
