# res://Scripts/PlayerStats.gd
extends Node
class_name PlayerStats

@export var max_health: int = 5       # Player's maximum health
@export var xp_base: int      = 50     # Base XP required per level
@export var initial_grenades: int = 5   # ← start with 5 TNT
@export var initial_mines:    int = 5   # ← start with 5 mines

# Runtime stats
var health:   int
var xp:       int
var kills:    int
var level:    int
var grenades: int
var mines:    int

# Signals for UI updates
signal health_changed(new_health: int)
signal xp_changed(new_xp: int)
signal kills_changed(new_kills: int)
signal level_changed(new_level: int)
signal grenades_changed(new_grenades: int)
signal mines_changed(new_mines: int)

func _ready() -> void:
	# Initialize default values
	health   = max_health
	xp       = 0
	kills    = 0
	level    = 1
	grenades = initial_grenades
	mines    = initial_mines
	
	# Emit initial signals so UI can populate
	emit_signal("health_changed", health)
	emit_signal("xp_changed", xp)
	emit_signal("kills_changed", kills)
	emit_signal("level_changed", level)
	emit_signal("grenades_changed", grenades)
	emit_signal("mines_changed", mines)

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
	health   = max_health
	xp       = 0
	kills    = 0
	level    = 1
	grenades = initial_grenades
	mines    = initial_mines
	
	# Emit signals so UI updates
	emit_signal("health_changed", health)
	emit_signal("xp_changed", xp)
	emit_signal("kills_changed", kills)
	emit_signal("level_changed", level)
	emit_signal("grenades_changed", grenades)
	emit_signal("mines_changed", mines)

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

func add_grenade(amount: int = 1) -> void:
	grenades += amount
	emit_signal("grenades_changed", grenades)

func add_mine(amount: int = 1) -> void:
	mines += amount
	emit_signal("mines_changed", mines)

func add_grenades(amount: int) -> void:
	grenades += amount
	emit_signal("grenades_changed", grenades)

func add_mines(amount: int) -> void:
	mines += amount
	emit_signal("mines_changed", mines)
