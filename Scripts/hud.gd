# res://Scripts/HUD.gd
extends CanvasLayer

@onready var kills_label  = $TopLeft/Kills       as RichTextLabel
@onready var health_bar   = $TopLeft/Health      as ProgressBar
@onready var xp_bar       = $TopLeft/XP          as ProgressBar
@onready var level_label  = $TopLeft/Level       as RichTextLabel
@onready var hp_label     = $TopLeft/HP          as RichTextLabel
@onready var xp_label     = $TopLeft/XPStatus    as RichTextLabel
@onready var name_label   = $TopLeft/Name        as RichTextLabel

@onready var currency_label    	= $TopLeft/Bumpers/CURRENCY			as RichTextLabel
@onready var tnt_label    		= $TopLeft/Bumpers/TNT    			as RichTextLabel
@onready var mines_label  		= $TopLeft/Bumpers/MINES  			as RichTextLabel
@onready var shock_label 		= $TopLeft/Bumpers/SHOCK 			as RichTextLabel

@onready var merc_portrait    = $TopLeft/Merc    as Panel
@onready var dog_portrait     = $TopLeft/Dog     as Panel
@onready var mech_portrait    = $TopLeft/Mech    as Panel
@onready var panther_portrait = $TopLeft/Panther as Panel

@export var merc_cooldown_time:     float = 20.0
@export var dog_cooldown_time:      float = 20.0
@export var mech_cooldown_time:     float = 20.0
@export var panther_cooldown_time:  float = 20.0

var level_names := [
	"Ghoul Gunner","Cadaver Crusher","Undead Eradicator","Corpse Conqueror",
	"Plague Purifier","Decay Destroyer","Rot Ranger","Necro Nemesis",
	"Zombie Exterminator","Flesh Fiend","Corpse Cleaver","Night Stalker",
	"Ghoul Guardian","Zombie Sentinel","Flesh Ravager","Skull Warden",
	"Risen Reaper","Dread Remover","Virus Vanquisher","Epidemic Enforcer",
	"Blight Banisher","Mortuary Mauler","Cadaver Conqueror","Bone Brawler",
	"Death Dealer"
]

func _ready() -> void:
	var stats = Playerstats

	# connect ally-used signals
	stats.connect("merc_used",    Callable(self, "_on_merc_used"))
	stats.connect("dog_used",     Callable(self, "_on_dog_used"))
	stats.connect("mech_used",    Callable(self, "_on_mech_used"))
	stats.connect("panther_used", Callable(self, "_on_panther_used"))
	
	# initialize
	kills_label.text      = "Kills: %d"  % stats.kills
	health_bar.max_value  = stats.max_health
	health_bar.value      = stats.health
	hp_label.text         = "HP: %d of %d" % [stats.health, stats.max_health]
	xp_label.text         = "XP: %d of %d" % [stats.xp, stats.xp_needed]
	xp_bar.max_value      = stats.xp_to_next_level()
	xp_bar.value          = stats.xp
	level_label.text      = "Level: %d"     % stats.level
	name_label.text       = level_names[0]

	currency_label.text        = "CURRENCY: %d"    % stats.currency
	tnt_label.text        = "TNT: %d"    % stats.grenades
	mines_label.text      = "MINES: %d"  % stats.mines
	shock_label.text     = "GLITCH: %d" % stats.shocks

	# connect the new signal:
	stats.connect("shocks_changed", Callable(self, "_on_shocks_changed"))

	# connect
	stats.connect("kills_changed",   Callable(self, "_on_kills_changed"))
	stats.connect("health_changed",  Callable(self, "_on_health_changed"))
	stats.connect("xp_changed",      Callable(self, "_on_xp_changed"))
	stats.connect("level_changed",   Callable(self, "_on_level_changed"))
	stats.connect("currency_changed",Callable(self, "_on_currency_changed"))
	stats.connect("grenades_changed",Callable(self, "_on_grenades_changed"))
	stats.connect("mines_changed",   Callable(self, "_on_mines_changed"))

func _on_kills_changed(k): kills_label.text = "Kills: %d" % k

func _on_health_changed(h): 
	health_bar.value = h
	hp_label.text    = "HP: %d of %d" % [h, Playerstats.max_health]

func _on_xp_changed(x):    
	xp_bar.value = x
	xp_label.text    = "XP: %d of %d" % [x, Playerstats.xp_needed]
	
func _on_level_changed(lvl: int) -> void:
	level_label.text     = "Level: %d" % lvl
	xp_bar.max_value     = Playerstats.xp_to_next_level()
	xp_bar.value         = Playerstats.xp
	health_bar.max_value = Playerstats.max_health
	hp_label.text        = "HP: %d of %d" % [Playerstats.health, Playerstats.max_health]

	# update the level name without a ternary
	var idx = lvl - 1
	if idx >= 0 and idx < level_names.size():
		name_label.text = level_names[idx]
	else:
		name_label.text = "Level %d" % lvl

func _on_grenades_changed(g):
	tnt_label.text   = "TNT: %d"   % g

func _on_mines_changed(m):
	mines_label.text = "MINES: %d" % m

func _on_shocks_changed(s: int) -> void:
	shock_label.text = "GLITCH: %d" % s

func _on_currency_changed(s: int) -> void:
	currency_label.text = "CURRENCY: %d" % s

func _on_merc_used() -> void:
	_start_cooldown(merc_portrait, merc_cooldown_time)

func _on_dog_used() -> void:
	_start_cooldown(dog_portrait, dog_cooldown_time)

func _on_mech_used() -> void:
	_start_cooldown(mech_portrait, mech_cooldown_time)

func _on_panther_used() -> void:
	_start_cooldown(panther_portrait, panther_cooldown_time)

# Helper to tween a panel’s alpha from fully opaque→transparent over `duration`.
func _start_cooldown(panel: Panel, duration: float) -> void:
	# Ensure it’s visible & fully opaque at start
	panel.modulate.a = 0.0

	# Create a tween on the panel
	var tw = panel.create_tween()
	# Over `duration`, animate its alpha down to 0
	tw.tween_property(panel, "modulate:a", 1.0, duration)
	tw.play()
