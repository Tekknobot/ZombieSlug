# PlayerStats.gd
extends Node
class_name PlayerStats

# ───────────────────────────────────────────────────────────────────────────────
#               PLAYERSTATS.GD — COMPLETE WITH DYNAMIC REGISTRATION
# ───────────────────────────────────────────────────────────────────────────────

# Exported “base” values (editable in the inspector):
@export var max_health: int              = 5       # Player’s maximum health
@export var xp_base: int                 = 300     # Base XP required per level
@export var initial_grenades: int        = 5       # Start with 5 grenades
@export var initial_mines: int           = 5       # Start with 5 mines
@export var initial_shocks: int          = 5       # Start with 5 roof shocks

# ─────────────────────────────────────
# Allied‐damage exports (base and per‐level increments):
@export var dog_base_damage: int         = 3
@export var dog_damage_per_level: int    = 2

@export var merc_base_damage: int        = 5
@export var merc_damage_per_level: int   = 2

@export var mech_base_damage: int        = 10
@export var mech_damage_per_level: int   = 5

@export var panther_base_damage: int     = 10
@export var panther_damage_per_level: int= 5

# ─────────────────────────────────────
# Grenade & mine “base” damage exports:
@export var initial_grenade_damage: int  = 3
@export var initial_mine_damage: int     = 3

# ─────────────────────────────────────
@export var initial_speed: float         = 50.0    # Player’s starting speed
@export var initial_firerate: float      = 1.0     # Seconds between shots at level 1

# ───────────────────────────────────────────────────────────────────────────────
# Runtime stats (initialized in _ready()):
var health:    int
var xp:        int
var kills:     int
var level:     int
var grenades:  int
var mines:     int
var shocks:    int
var xp_needed: int                                          # XP required for next level

var currency:  int = 0

# ─────────────────────────────────────
# Runtime damage fields (current values, updated on level‐up):
var dog_damage:     int
var merc_damage:    int
var mech_damage:    int
var panther_damage: int

var grenade_damage: int
var mine_damage:    int

# ─────────────────────────────────────
# Runtime movement‐related stats:
var stats_initialized: bool = false
var speed: float
var firerate: float

# ───────────────────────────────────────────────────────────────────────────────
# SIGNALS for UI and gameplay updates:
signal health_changed(new_health: int)
signal xp_changed(new_xp: int)
signal xp_needed_changed(new_xp_needed: int)
signal kills_changed(new_kills: int)
signal level_changed(new_level: int)
signal currency_changed(new_currency: int)
signal grenades_changed(new_grenades: int)
signal mines_changed(new_mines: int)
signal shocks_changed(new_shocks: int)

signal merc_used
signal dog_used
signal mech_used
signal panther_used
signal mine_used
signal bullet_used
signal grenade_used

signal speed_changed(new_speed: float)
signal firerate_changed(new_firerate: float)

# ───────────────────────────────────────────────────────────────────────────────
# New “_damage_changed” signals (so others can connect):
signal dog_damage_changed(new_damage: int)
signal merc_damage_changed(new_damage: int)
signal mech_damage_changed(new_damage: int)
signal panther_damage_changed(new_damage: int)

signal grenade_damage_changed(new_damage: int)
signal mine_damage_changed(new_damage: int)

# ───────────────────────────────────────────────────────────────────────────────
# SIGNAL used to track which soldier(s) have been registered
signal soldier_registered(soldier: Node)
signal soldier_unregistered(soldier: Node)

# ───────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# If we’ve already run _ready() once, bail out immediately:
	if stats_initialized:
		return
			
	# Connect usage signals (optional hooks for UI or SFX, if you want to handle them here):
	self.connect("dog_used",     Callable(self, "_on_dog_used"))
	self.connect("mech_used",    Callable(self, "_on_mech_used"))
	self.connect("merc_used",    Callable(self, "_on_merc_used"))
	self.connect("panther_used", Callable(self, "_on_panther_used"))
	self.connect("mine_used",    Callable(self, "_on_mine_used"))
	self.connect("bullet_used",  Callable(self, "_on_bullet_used"))
	self.connect("grenade_used", Callable(self, "_on_grenade_used"))
	
	# ─── Initialize baseline runtime values ───────────────────────────────────────
	health   = max_health
	xp       = 0
	kills    = 0
	level    = 1
	grenades = initial_grenades
	mines    = initial_mines
	shocks   = initial_shocks
	
	# Compute XP needed for next level
	xp_needed = xp_to_next_level()
	
	# Initialize movement stats
	speed    = initial_speed
	firerate = initial_firerate
	
	# Initialize all damage fields
	dog_damage     = dog_base_damage
	merc_damage    = merc_base_damage
	mech_damage    = mech_base_damage
	panther_damage = panther_base_damage
	
	grenade_damage = initial_grenade_damage
	mine_damage    = initial_mine_damage
	
	# Mark the singleton as “done initializing.”
	stats_initialized = true

	# ─── Emit initial signals so any UI or gameplay elements can populate ────────
	emit_signal("health_changed", health)
	emit_signal("xp_changed", xp)
	emit_signal("xp_needed_changed", xp_needed)
	emit_signal("kills_changed", kills)
	emit_signal("level_changed", level)
	emit_signal("currency_changed", currency)
	emit_signal("grenades_changed", grenades)
	emit_signal("mines_changed", mines)
	emit_signal("shocks_changed", shocks)

	emit_signal("speed_changed", speed)
	emit_signal("firerate_changed", firerate)

	emit_signal("dog_damage_changed", dog_damage)
	emit_signal("merc_damage_changed", merc_damage)
	emit_signal("mech_damage_changed", mech_damage)
	emit_signal("panther_damage_changed", panther_damage)

	emit_signal("grenade_damage_changed", grenade_damage)
	emit_signal("mine_damage_changed", mine_damage)

# ───────────────────────────────────────────────────────────────────────────────
func xp_to_next_level() -> int:
	return xp_base * level


func _level_up() -> void:
	level += 1
	max_health += 2
	health = max_health
	xp_needed = xp_to_next_level()

	# Emit level + health signals
	emit_signal("level_changed", level)
	emit_signal("health_changed", health)
	emit_signal("xp_needed_changed", xp_needed)

	# ─── Recalculate ALL ally damage values ─────────────────────────────────────
	dog_damage     = dog_base_damage + (level - 1) * dog_damage_per_level
	emit_signal("dog_damage_changed", dog_damage)

	merc_damage    = merc_base_damage + (level - 1) * merc_damage_per_level
	emit_signal("merc_damage_changed", merc_damage)

	mech_damage    = mech_base_damage + (level - 1) * mech_damage_per_level
	emit_signal("mech_damage_changed", mech_damage)

	panther_damage = panther_base_damage + (level - 1) * panther_damage_per_level
	emit_signal("panther_damage_changed", panther_damage)

	# ─── Recalculate grenade & mine damage ───────────────────────────────────────
	grenade_damage = initial_grenade_damage + (level - 1)
	emit_signal("grenade_damage_changed", grenade_damage)

	mine_damage    = initial_mine_damage + (level - 1)
	emit_signal("mine_damage_changed", mine_damage)


# ───────────────────────────────────────────────────────────────────────────────
# Apply damage to player (e.g. negative damage = heal)
func damage(amount: int) -> void:
	health = clamp(health - amount, 0, max_health)
	emit_signal("health_changed", health)


# ───────────────────────────────────────────────────────────────────────────────
# Gain XP and handle level‐up
func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		_level_up()
	xp_needed = xp_to_next_level()
	emit_signal("xp_changed", xp)
	emit_signal("xp_needed_changed", xp_needed)


# ───────────────────────────────────────────────────────────────────────────────
# Register a kill: increments kill count and awards XP
func add_kill(xp_award: int = 1) -> void:
	kills += 1
	emit_signal("kills_changed", kills)
	add_xp(xp_award)


# ───────────────────────────────────────────────────────────────────────────────
# Reset all stats to initial values
func reset_stats() -> void:
	Engine.time_scale = 1
	health   = max_health
	xp       = 0
	kills    = 0
	level    = 1
	grenades = initial_grenades
	mines    = initial_mines
	shocks   = initial_shocks
	xp_needed = xp_to_next_level()

	emit_signal("health_changed", health)
	emit_signal("xp_changed", xp)
	emit_signal("xp_needed_changed", xp_needed)
	emit_signal("kills_changed", kills)
	emit_signal("level_changed", level)
	emit_signal("currency_changed", currency)
	emit_signal("grenades_changed", grenades)
	emit_signal("mines_changed", mines)
	emit_signal("shocks_changed", shocks)

	# Reset damage fields back to base
	dog_damage     = dog_base_damage
	merc_damage    = merc_base_damage
	mech_damage    = mech_base_damage
	panther_damage = panther_base_damage
	emit_signal("dog_damage_changed", dog_damage)
	emit_signal("merc_damage_changed", merc_damage)
	emit_signal("mech_damage_changed", mech_damage)
	emit_signal("panther_damage_changed", panther_damage)

	grenade_damage = initial_grenade_damage
	mine_damage    = initial_mine_damage
	emit_signal("grenade_damage_changed", grenade_damage)
	emit_signal("mine_damage_changed", mine_damage)

	# Reset movement stats
	speed    = initial_speed
	firerate = initial_firerate
	emit_signal("speed_changed", speed)
	emit_signal("firerate_changed", firerate)


# ───────────────────────────────────────────────────────────────────────────────
# Use and modify ammo counts
func use_grenade() -> bool:
	if grenades > 0:
		grenades -= 1
		emit_signal("grenades_changed", grenades)
		return true
	return false


func use_mine() -> bool:
	if mines > 0:
		mines -= 1
		emit_signal("mines_changed", mines)
		return true
	return false


func use_shock() -> bool:
	if shocks > 0:
		shocks -= 1
		emit_signal("shocks_changed", shocks)
		return true
	return false


func add_grenades(amount: int = 1) -> void:
	grenades += amount
	emit_signal("grenades_changed", grenades)


func add_mines(amount: int = 1) -> void:
	mines += amount
	emit_signal("mines_changed", mines)


func add_shock(amount: int = 1) -> void:
	shocks += amount
	emit_signal("shocks_changed", shocks)


# ───────────────────────────────────────────────────────────────────────────────
# Currency management
func use_currency(amount: int) -> bool:
	if currency >= amount:
		currency -= amount
		emit_signal("currency_changed", currency)
		return true
	return false


func add_currency(amount: int) -> void:
	currency += amount
	emit_signal("currency_changed", currency)


# ───────────────────────────────────────────────────────────────────────────────
# Instantly bump to a target level (for testing)
func set_level(target_level: int) -> void:
	if target_level <= level:
		return
	xp = 0
	kills = 0
	while level < target_level:
		_level_up()
	xp_needed = xp_to_next_level()
	emit_signal("level_changed", level)
	emit_signal("xp_changed", xp)
	emit_signal("xp_needed_changed", xp_needed)
	emit_signal("health_changed", health)
	emit_signal("kills_changed", kills)
	emit_signal("currency_changed", currency)
	emit_signal("grenades_changed", grenades)
	emit_signal("mines_changed", mines)
	emit_signal("shocks_changed", shocks)

	# Re‐emit damage signals at the forced level
	emit_signal("dog_damage_changed", dog_damage)
	emit_signal("merc_damage_changed", merc_damage)
	emit_signal("mech_damage_changed", mech_damage)
	emit_signal("panther_damage_changed", panther_damage)
	emit_signal("grenade_damage_changed", grenade_damage)
	emit_signal("mine_damage_changed", mine_damage)


# ───────────────────────────────────────────────────────────────────────────────
# Optional stubs: these get called when the respective “_used” signals fire.
# You can hook UI sound effects or other logic here. They are not strictly
# required if you have no special handling.

func _on_dog_used() -> void:
	pass

func _on_mech_used() -> void:
	pass

func _on_merc_used() -> void:
	pass

func _on_panther_used() -> void:
	pass

func _on_mine_used() -> void:
	pass

func _on_bullet_used() -> void:
	pass

func _on_grenade_used() -> void:
	pass


# ───────────────────────────────────────────────────────────────────────────────
# ─── DYNAMIC REGISTRATION METHODS ────────────────────────────────────────────

# Call this from each new Soldier (or Player) in its _ready() so it “pulls down”:
#   - the current speed/firerate
#   - current grenade_damage, mine_damage
#   - current allied damages
#   - current ammo counts (grenades, mines, shocks)
#   - etc.
# Then we connect each relevant signal so that, whenever PlayerStats changes,
# the soldier’s local values update automatically.

# ───────────────────────────────────────────────────────────────────────────────
# Assume everything above is exactly as before (exports, signals, _ready, etc.)
# ... (omitted for brevity)
#
# Now we add / replace the dynamic registration methods with syntax that actually compiles
# in Godot 4 (no more `Callable(self, func(...))`—just pass the inline func directly).
# ───────────────────────────────────────────────────────────────────────────────

# Call this from each new Soldier (or Player) in its _ready() so it “pulls down”:
#   - the current speed/firerate
#   - current grenade_damage, mine_damage
#   - current allied damages
#   - current ammo counts (grenades, mines, shocks)
#   - etc.
# Then we connect each relevant signal so that, whenever PlayerStats changes,
# the soldier’s local values update automatically.

func register_soldier(soldier: Node) -> void:
	# 1) Copy every current stat into the soldier instance:
	if soldier.has_method("set_speed"):
		soldier.set_speed(speed)
	elif soldier.has_meta("speed"):
		soldier.speed = speed

	if soldier.has_method("set_firerate"):
		soldier.set_firerate(firerate)
	elif soldier.has_meta("firerate"):
		soldier.firerate = firerate

	if soldier.has_meta("grenade_damage"):
		soldier.grenade_damage = grenade_damage
	if soldier.has_meta("mine_damage"):
		soldier.mine_damage = mine_damage

	if soldier.has_meta("dog_base_damage"):
		soldier.dog_base_damage = dog_damage
	if soldier.has_meta("merc_base_damage"):
		soldier.merc_base_damage = merc_damage
	if soldier.has_meta("mech_base_damage"):
		soldier.mech_base_damage = mech_damage
	if soldier.has_meta("mech_panther_base_damage"):
		soldier.mech_panther_base_damage = panther_damage

	if soldier.has_meta("grenades"):
		soldier.grenades = grenades
	if soldier.has_meta("mines"):
		soldier.mines = mines
	if soldier.has_meta("shocks"):
		soldier.shocks = shocks

	if soldier.has_meta("health"):
		soldier.health = health
	# …copy any other fields you need…

	# 2) Now connect every relevant signal so the soldier “listens” for future changes:
	#
	#    Whenever PlayerStats emits “speed_changed(new_speed)”, we update soldier.speed.
	#    We pass an inline func directly, which is itself a Callable.

	# Speed / Firerate:
	connect("speed_changed", func(new_speed):
		if is_instance_valid(soldier):
			if soldier.has_method("set_speed"):
				soldier.set_speed(new_speed)
			elif soldier.has_meta("speed"):
				soldier.speed = new_speed
	)

	connect("firerate_changed", func(new_firerate):
		if is_instance_valid(soldier):
			if soldier.has_method("set_firerate"):
				soldier.set_firerate(new_firerate)
			elif soldier.has_meta("firerate"):
				soldier.firerate = new_firerate
	)

	# Grenade & Mine damage:
	connect("grenade_damage_changed", func(new_gd):
		if is_instance_valid(soldier) and soldier.has_meta("grenade_damage"):
			soldier.grenade_damage = new_gd
	)

	connect("mine_damage_changed", func(new_md):
		if is_instance_valid(soldier) and soldier.has_meta("mine_damage"):
			soldier.mine_damage = new_md
	)

	# Allied damage (dog, merc, mech, panther):
	connect("dog_damage_changed", func(new_dd):
		if is_instance_valid(soldier) and soldier.has_meta("dog_base_damage"):
			soldier.dog_base_damage = new_dd
	)

	connect("merc_damage_changed", func(new_md):
		if is_instance_valid(soldier) and soldier.has_meta("merc_base_damage"):
			soldier.merc_base_damage = new_md
	)

	connect("mech_damage_changed", func(new_mhd):
		if is_instance_valid(soldier) and soldier.has_meta("mech_base_damage"):
			soldier.mech_base_damage = new_mhd
	)

	connect("panther_damage_changed", func(new_phd):
		if is_instance_valid(soldier) and soldier.has_meta("mech_panther_base_damage"):
			soldier.mech_panther_base_damage = new_phd
	)

	# Ammo counts (grenades, mines, shocks):
	connect("grenades_changed", func(new_gcount):
		if is_instance_valid(soldier) and soldier.has_meta("grenades"):
			soldier.grenades = new_gcount
	)

	connect("mines_changed", func(new_mcount):
		if is_instance_valid(soldier) and soldier.has_meta("mines"):
			soldier.mines = new_mcount
	)

	connect("shocks_changed", func(new_scount):
		if is_instance_valid(soldier) and soldier.has_meta("shocks"):
			soldier.shocks = new_scount
	)

	# Health (if soldier keeps its own copy):
	connect("health_changed", func(new_h):
		if is_instance_valid(soldier) and soldier.has_meta("health"):
			soldier.health = new_h
	)

	# If you also keep xp/kills/level in soldier, you can do:
	connect("xp_changed", func(new_xp):
		if is_instance_valid(soldier) and soldier.has_meta("xp"):
			soldier.xp = new_xp
	)
	connect("kills_changed", func(new_kills):
		if is_instance_valid(soldier) and soldier.has_meta("kills"):
			soldier.kills = new_kills
	)
	connect("level_changed", func(new_lvl):
		if is_instance_valid(soldier) and soldier.has_meta("level"):
			soldier.level = new_lvl
	)

	# Finally, emit that we registered this soldier:
	emit_signal("soldier_registered", soldier)


func unregister_soldier(soldier: Node) -> void:
	# If you ever free a soldier, call this to disconnect all pending callbacks.
	# (If you need actual disconnection logic, you can keep track of ConnectionIDs.)
	if not is_instance_valid(soldier):
		return

	emit_signal("soldier_unregistered", soldier)
