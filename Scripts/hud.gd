# HUD.gd
extends CanvasLayer

@onready var kills_label  = $TopLeft/Kills
@onready var health_bar   = $TopLeft/Health
@onready var xp_bar       = $TopLeft/XP

func _ready() -> void:
	# correct singleton name too!
	kills_label.text  = "Kills: %d"  % Playerstats.kills
	health_bar.value  = Playerstats.health
	xp_bar.value      = Playerstats.xp

	Playerstats.connect("kills_changed",  Callable(self, "_on_kills_changed"))
	Playerstats.connect("health_changed", Callable(self, "_on_health_changed"))
	Playerstats.connect("xp_changed",     Callable(self, "_on_xp_changed"))

func _on_kills_changed(new_kills: int) -> void:
	kills_label.text = "Kills: %d" % new_kills

func _on_health_changed(new_health: int) -> void:
	health_bar.value = new_health

func _on_xp_changed(new_xp: int) -> void:
	xp_bar.value = new_xp
