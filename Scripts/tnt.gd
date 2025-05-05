extends Area2D

@export var initial_speed:  float = 300.0
@export var initial_upward: float = -400.0
@export var gravity_force:  float = 900.0
@export var fuse_time:      float = 1.5
@export var damage:         int   = 3    # how much the grenade itself deals on impact

@onready var sprite: Sprite2D = $Sprite2D

var velocity: Vector2 = Vector2.ZERO
var fuse_timer: Timer

const ExplosionScene = preload("res://Scenes/Effects/Explosion.tscn")

func _ready() -> void:
	# backup fuse detonation
	fuse_timer = Timer.new()
	fuse_timer.wait_time = fuse_time
	fuse_timer.one_shot = true
	add_child(fuse_timer)
	fuse_timer.connect("timeout", Callable(self, "_explode"))
	fuse_timer.start()

	# explode (and damage) on hitting a Zombie
	monitoring = true
	connect("body_entered", Callable(self, "_on_body_entered"))

func _physics_process(delta: float) -> void:
	# arc under gravity
	velocity.y += gravity_force * delta
	position += velocity * delta
	rotation += velocity.x * delta * 0.2

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Zombie"):
		# first, damage the zombie
		if body.has_method("take_damage"):
			body.take_damage(damage)
		# then explode
		_explode()

func _explode() -> void:
	# guard against multiple calls
	if not is_inside_tree():
		return

	# spawn the visual explosion
	var exp = ExplosionScene.instantiate()
	exp.global_position = global_position
	get_tree().get_current_scene().add_child(exp)

	# remove the grenade
	queue_free()
