extends Node
class_name PlayerStats

@export var max_health: int       = 5       # Player's maximum health
@export var xp_base: int          = 200     # Base XP required per level
@export var initial_grenades: int = 5       # start with 5 TNT
@export var initial_mines: int    = 5       # start with 5 mines
@export var initial_shocks: int   = 5       # start with 5 roof shocks

# Runtime stats
var health:    int
var xp:        int
var kills:     int
var level:     int
var grenades:  int
var mines:     int
var shocks:    int
var xp_needed: int                 # XP required for next level

# Signals for UI updates
signal health_changed(new_health: int)
signal xp_changed(new_xp: int)
signal xp_needed_changed(new_xp_needed: int)
signal kills_changed(new_kills: int)
signal level_changed(new_level: int)
signal currency_changed(new_currency: int)
signal grenades_changed(new_grenades: int)
signal mines_changed(new_mines: int)
signal shocks_changed(new_shocks: int)

var currency = 0

func _ready() -> void:
	# Initialize default values
	health   = max_health
	xp       = 0
	kills    = 0
	level    = 1
	grenades = initial_grenades
	mines    = initial_mines
	shocks   = initial_shocks

	# Compute XP needed for next level
	xp_needed = xp_to_next_level()

	# Emit initial signals so UI can populate
	emit_signal("health_changed", health)
	emit_signal("xp_changed", xp)
	emit_signal("xp_needed_changed", xp_needed)
	emit_signal("kills_changed", kills)
	emit_signal("level_changed", level)
	emit_signal("currency_changed", currency)
	emit_signal("grenades_changed", grenades)
	emit_signal("mines_changed", mines)
	emit_signal("shocks_changed", shocks)

func xp_to_next_level() -> int:
	return xp_base * level

func _level_up() -> void:
	level += 1
	max_health += 2
	health = max_health
	xp_needed = xp_to_next_level()
	emit_signal("level_changed", level)
	emit_signal("health_changed", health)
	emit_signal("xp_needed_changed", xp_needed)

# Apply damage to player
func damage(amount: int) -> void:
	health = clamp(health - amount, 0, max_health)
	emit_signal("health_changed", health)

# Gain XP and handle level-up
func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		_level_up()
	xp_needed = xp_to_next_level()
	emit_signal("xp_changed", xp)
	emit_signal("xp_needed_changed", xp_needed)

# Register a kill: increments kill count and awards XP
func add_kill(xp_award: int = 1) -> void:
	kills += 1
	emit_signal("kills_changed", kills)
	add_xp(xp_award)

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

func use_currency(amount: int) -> bool:
	if currency >= amount:
		currency -= amount
		emit_signal("currency_changed", currency)
		return true
	return false

func add_currency(amount: int) -> void:
	currency += amount
	emit_signal("currency_changed", currency)

# Instantly bump to a target level for testing
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
