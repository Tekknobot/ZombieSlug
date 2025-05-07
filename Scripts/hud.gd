extends CanvasLayer

@onready var kills_label  = $TopLeft/Kills      # Label
@onready var health_bar   = $TopLeft/Health     # ProgressBar
@onready var xp_bar       = $TopLeft/XP         # ProgressBar
@onready var level_label  = $TopLeft/Level      # Label
@onready var hp_label     = $TopLeft/HP         # Label
	
func _ready() -> void:
	var stats = Playerstats

	# Initial values
	kills_label.text       = "Kills: %d"  % stats.kills
	health_bar.max_value   = stats.max_health
	health_bar.value       = stats.health
	xp_bar.max_value       = stats.xp_to_next_level()
	xp_bar.value           = stats.xp
	level_label.text       = "Level: %d"  % stats.level
	hp_label.text          = "HP: %d of %d" % [stats.health, stats.max_health]

	# Connect signals
	stats.connect("kills_changed",   Callable(self, "_on_kills_changed"))
	stats.connect("health_changed",  Callable(self, "_on_health_changed"))
	stats.connect("xp_changed",      Callable(self, "_on_xp_changed"))
	stats.connect("level_changed",   Callable(self, "_on_level_changed"))

func _on_kills_changed(new_kills: int) -> void:
	kills_label.text = "Kills: %d" % new_kills

func _on_health_changed(new_health: int) -> void:
	health_bar.value = new_health
	hp_label.text    = "HP: %d of %d" % [new_health, Playerstats.max_health]

func _on_xp_changed(new_xp: int) -> void:
	xp_bar.value = new_xp

func _on_level_changed(new_level: int) -> void:
	level_label.text     = "Level: %d" % new_level
	xp_bar.max_value     = Playerstats.xp_to_next_level()
	xp_bar.value         = Playerstats.xp
	# also refresh HP bar max in case max_health grew
	health_bar.max_value = Playerstats.max_health
	hp_label.text        = "HP: %d of %d" % [Playerstats.health, Playerstats.max_health]
