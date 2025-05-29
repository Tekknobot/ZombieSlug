# res://Scripts/HUD.gd
extends CanvasLayer

@onready var kills_label       = $TopLeft/Kills       as RichTextLabel
@onready var health_bar        = $TopLeft/Health      as ProgressBar
@onready var xp_bar            = $TopLeft/XP          as ProgressBar
@onready var level_label       = $TopLeft/Level       as RichTextLabel
@onready var hp_label          = $TopLeft/HP          as RichTextLabel
@onready var xp_label          = $TopLeft/XPStatus    as RichTextLabel
@onready var name_label        = $TopLeft/Name        as RichTextLabel

@onready var currency_label    = $TopLeft/Bumpers/CURRENCY as RichTextLabel
@onready var tnt_label         = $TopLeft/Bumpers/TNT      as RichTextLabel
@onready var mines_label       = $TopLeft/Bumpers/MINES    as RichTextLabel
@onready var shock_label       = $TopLeft/Bumpers/SHOCK    as RichTextLabel

@onready var merc_portrait     = $TopLeft/Merc     as Panel
@onready var dog_portrait      = $TopLeft/Dog      as Panel
@onready var mech_portrait     = $TopLeft/Mech     as Panel
@onready var panther_portrait  = $TopLeft/Panther  as Panel
@onready var mine_portrait     = $TopLeft/Mine     as Panel
@onready var bullet_portrait   = $TopLeft/Bullet   as Panel
@onready var grenade_portrait  = $TopLeft/Grenade  as Panel

@export var merc_cooldown_time:    float = 20.0
@export var dog_cooldown_time:     float = 20.0
@export var mech_cooldown_time:    float = 20.0
@export var panther_cooldown_time: float = 20.0
@export var mine_cooldown_time:    float = 2.0
@export var bullet_cooldown_time:  float = 1.0
@export var grenade_cooldown_time: float = 1.0

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
	var s = Playerstats

	# connect “used” signals
	s.connect("merc_used",    Callable(self, "_on_merc_used"))
	s.connect("dog_used",     Callable(self, "_on_dog_used"))
	s.connect("mech_used",    Callable(self, "_on_mech_used"))
	s.connect("panther_used", Callable(self, "_on_panther_used"))
	s.connect("mine_used",    Callable(self, "_on_mine_used"))
	s.connect("bullet_used",  Callable(self, "_on_bullet_used"))
	s.connect("grenade_used", Callable(self, "_on_grenade_used"))

	# connect “changed” signals
	s.connect("kills_changed",   Callable(self, "_on_kills_changed"))
	s.connect("health_changed",  Callable(self, "_on_health_changed"))
	s.connect("xp_changed",      Callable(self, "_on_xp_changed"))
	s.connect("level_changed",   Callable(self, "_on_level_changed"))
	s.connect("currency_changed",Callable(self, "_on_currency_changed"))
	s.connect("grenades_changed",Callable(self, "_on_grenades_changed"))
	s.connect("mines_changed",   Callable(self, "_on_mines_changed"))
	s.connect("shocks_changed",  Callable(self, "_on_shocks_changed"))

	s.connect("speed_changed",    Callable(self, "_on_speed_changed"))
	s.connect("firerate_changed", Callable(self, "_on_firerate_changed"))
	
	# one‐time pull of all values on scene load
	refresh()

func _on_kills_changed(k): 
	kills_label.text = "Kills: %d" % k

func _on_health_changed(h): 
	health_bar.value = h
	hp_label.text   = "HP: %d of %d" % [h, Playerstats.max_health]

func _on_xp_changed(x):    
	xp_bar.value   = x
	xp_label.text = "XP: %d of %d" % [x, Playerstats.xp_to_next_level()]

func _on_level_changed(lvl: int) -> void:
	level_label.text     = "Level: %d" % lvl
	xp_bar.max_value     = Playerstats.xp_to_next_level()
	xp_bar.value         = Playerstats.xp
	health_bar.max_value = Playerstats.max_health
	hp_label.text        = "HP: %d of %d" % [Playerstats.health, Playerstats.max_health]
	var idx = clamp(lvl - 1, 0, level_names.size() - 1)
	name_label.text      = level_names[idx]

func _on_currency_changed(c: int) -> void:
	currency_label.text = "CURRENCY: %d" % c

func _on_grenades_changed(g: int) -> void:
	tnt_label.text     = "TNT: %d" % g

func _on_mines_changed(m: int) -> void:
	mines_label.text   = "MINES: %d" % m

func _on_shocks_changed(s: int) -> void:
	shock_label.text   = "GLITCH: %d" % s

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
	
func _start_cooldown(panel: Panel, duration: float) -> void:
	if _cooldown_tweens.has(panel):
		_cooldown_tweens[panel].kill()
		_cooldown_tweens.erase(panel)

	panel.visible = true
	panel.modulate = Color(0.25,0.25,0.25,0)
	var tw = panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, duration)
	tw.tween_callback(Callable(self, "_on_cooldown_finished").bind(panel))
	_cooldown_tweens[panel] = tw

func _on_cooldown_finished(panel: Panel) -> void:
	var m = panel.modulate
	m.a = 1.0
	panel.modulate = m
	_cooldown_tweens.erase(panel)

	var tw = panel.create_tween()
	tw.tween_property(panel, "modulate", Color(1,1,1,1), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var start = panel.position
	var up    = start + Vector2(0, -8)
	tw.tween_property(panel, "position", up, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(panel, "position", start, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func refresh() -> void:
	var s = Playerstats

	kills_label.text       = "Kills: %d"      % s.kills
	health_bar.max_value   = s.max_health
	health_bar.value       = s.health
	hp_label.text          = "HP: %d of %d"   % [s.health, s.max_health]

	xp_bar.max_value       = s.xp_to_next_level()
	xp_bar.value           = s.xp
	xp_label.text          = "XP: %d of %d"   % [s.xp, s.xp_to_next_level()]

	level_label.text       = "Level: %d"      % s.level
	name_label.text        = level_names[clamp(s.level - 1, 0, level_names.size() - 1)]

	currency_label.text    = "CURRENCY: %d"   % s.currency
	tnt_label.text         = "TNT: %d"        % s.grenades
	mines_label.text       = "MINES: %d"      % s.mines
	shock_label.text       = "GLITCH: %d"     % s.shocks
