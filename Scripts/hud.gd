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
@onready var mine_portrait    = $TopLeft/Mine    as Panel
@onready var bullet_portrait  = $TopLeft/Bullet   as Panel
@onready var grenade_portrait  = $TopLeft/Grenade   as Panel

@export var merc_cooldown_time:     float = 20.0
@export var dog_cooldown_time:      float = 20.0
@export var mech_cooldown_time:     float = 20.0
@export var panther_cooldown_time:  float = 20.0

@export var mine_cooldown_time:     float = 2.0
@export var bullet_cooldown_time:  float = 1.0
@export var grenade_cooldown_time:  float = 1.0

var _cooldown_tweens := {}

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
	stats.connect("mine_used",    Callable(self, "_on_mine_used"))
	stats.connect("bullet_used", Callable(self, "_on_bullet_used"))
	stats.connect("grenade_used", Callable(self, "_on_grenade_used"))
		
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

func _on_mine_used() -> void:
	_start_cooldown(mine_portrait, mine_cooldown_time)

func _on_bullet_used() -> void:
	_start_cooldown(bullet_portrait, bullet_cooldown_time)

func _on_grenade_used() -> void:
	_start_cooldown(grenade_portrait, grenade_cooldown_time)

# Helper to tween a panel’s alpha from fully opaque→transparent over `duration`.
func _start_cooldown(panel: Panel, duration: float) -> void:
	# 1) Cancel any existing tween on this panel
	if _cooldown_tweens.has(panel):
		_cooldown_tweens[panel].kill()
		_cooldown_tweens.erase(panel)

	# 2) Reset it to fully transparent & visible
	panel.visible = true
	panel.modulate = Color(0.25, 0.25, 0.25, 1.0)  # halfway grey
	
	var m = panel.modulate
	m.a = 0.0
	panel.modulate = m

	# 3) Create a new Tween and fade alpha → 1
	var tw = panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, duration)

	# 4) When finished, just cap at opaque (don’t hide), and remove our record
	var cb = Callable(self, "_on_cooldown_finished").bind(panel)
	tw.tween_callback(cb)

	_cooldown_tweens[panel] = tw

func _on_cooldown_finished(panel: Panel) -> void:
	# 1) Ensure fully visible
	var m = panel.modulate
	m.a = 1.0
	panel.modulate = m

	# 2) Remove from our active-tweens map
	_cooldown_tweens.erase(panel)

	# 2.5) Tween from grey → full colour
	var tw = panel.create_tween()
	tw.tween_property(panel, "modulate", Color(1, 1, 1, 1), 0.2) \
	  .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 3) Bounce effect: move up then spring back
	var start_pos = panel.position
	var up_pos    = start_pos + Vector2(0, -8)

	tw.tween_property(panel, "position", up_pos, 0.1) \
	  .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(panel, "position", start_pos, 0.3) \
	  .set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
