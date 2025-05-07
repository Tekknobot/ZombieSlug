# res://Scripts/PlayerStats.gd
extends Node

@export var max_health: int = 5       # Player's maximum health
@export var xp_base: int      = 50     # Base XP required per level

# Runtime stats
var health: int
var xp:     int
var kills:  int
var level:  int

# Signals for UI updates
signal health_changed(new_health: int)
signal xp_changed(new_xp: int)
signal kills_changed(new_kills: int)
signal level_changed(new_level: int)

func _ready() -> void:
	# Initialize default values
	health = max_health
	xp     = 0
	kills  = 0
	level  = 1
	# Emit initial signals so UI can populate
	emit_signal("health_changed", health)
	emit_signal("xp_changed",     xp)
	emit_signal("kills_changed",  kills)
	emit_signal("level_changed",  level)

# Apply damage to player
func damage(amount: int) -> void:
	health = clamp(health - amount, 0, max_health)
	emit_signal("health_changed", health)

# Gain XP and handle level-up
func add_xp(amount: int) -> void:
	xp += amount
	# Check for level-ups
	while xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		_level_up()
	emit_signal("xp_changed", xp)

# Register a kill: increments kill count and awards XP
func add_kill(xp_award: int = 1) -> void:
	kills += 1
	emit_signal("kills_changed", kills)
	add_xp(xp_award)

# Calculate XP needed for next level
func xp_to_next_level() -> int:
	return xp_base * level

# Internal: level-up logic
func _level_up() -> void:
	level += 1
	max_health += 2
	health = max_health
	emit_signal("level_changed", level)
	emit_signal("health_changed", health)
	emit_signal("max_health_changed", max_health)

func reset_stats() -> void:
	# Reset runtime values
	health = max_health
	xp     = 0
	kills  = 0
	level  = 1

	# Emit signals so UI updates
	emit_signal("health_changed", health)
	emit_signal("xp_changed",     xp)
	emit_signal("kills_changed",  kills)
	emit_signal("level_changed",  level)
