# res://Scripts/PlayerStats.gd
extends Node

@export var max_health: int = 10

var health: int
var xp:     int
var kills:  int

signal health_changed(new_health: int)
signal xp_changed(new_xp: int)
signal kills_changed(new_kills: int)

func _ready() -> void:
	# initialize all values
	health = max_health
	xp     = 0
	kills  = 0
	# announce initial state
	emit_signal("health_changed", health)
	emit_signal("xp_changed",     xp)
	emit_signal("kills_changed",  kills)

func damage(amount: int) -> void:
	health = clamp(health - amount, 0, max_health)
	emit_signal("health_changed", health)

func add_xp(amount: int) -> void:
	xp += amount
	emit_signal("xp_changed", xp)

func add_kill(xp_award: int = 1) -> void:
	kills += 1
	emit_signal("kills_changed", kills)
	add_xp(xp_award)
