extends Area2D

@export var initial_speed:  float    = 300.0
@export var initial_upward: float    = -400.0
@export var gravity_force:  float    = 900.0
@export var fuse_time:      float    = 2.0
@export var damage:         int      = 3
@export var direction:      Vector2  = Vector2.RIGHT   # default if you never set velocity manually

@onready var sprite: Sprite2D = $Sprite2D

var velocity:       Vector2 = Vector2.ZERO
var _has_landed:    bool    = false
var _fuse_finished: bool    = false
var _fuse_timer:    Timer

const ExplosionScene = preload("res://Scenes/Effects/Explosion.tscn")

func _ready() -> void:
	# only do the “default toss” if nobody else already set velocity
	if velocity == Vector2.ZERO:
		velocity = direction.normalized() * initial_speed
		velocity.y = initial_upward

	# fuse timer
	_fuse_timer = Timer.new()
	_fuse_timer.wait_time = fuse_time
	_fuse_timer.one_shot  = true
	add_child(_fuse_timer)
	_fuse_timer.connect("timeout", Callable(self, "_on_fuse_timeout"))
	_fuse_timer.start()

	# floor collisions only (zombies masked out)
	monitoring = true
	connect("body_entered", Callable(self, "_on_body_entered"))


func _physics_process(delta: float) -> void:
	if not _has_landed:
		velocity.y += gravity_force * delta
		position   += velocity   * delta
		rotation   += velocity.x * delta * 0.2


func _on_body_entered(body: Node) -> void:
	if _has_landed:
		return
	if body.is_in_group("Floor"):
		_land()


func _land() -> void:
	_has_landed = true
	velocity     = Vector2.ZERO

	if _fuse_finished:
		_explode()


func _on_fuse_timeout() -> void:
	_fuse_finished = true
	if _has_landed:
		_explode()


func _explode() -> void:
	if not is_inside_tree():
		return

	# spawn VFX
	var exp = ExplosionScene.instantiate()
	exp.global_position = global_position
	get_tree().get_current_scene().add_child(exp)

	# area‐damage
	for z in get_tree().get_nodes_in_group("Zombie"):
		if z.has_method("take_damage") and z.global_position.distance_to(global_position) < 64.0:
			z.take_damage(damage)

	queue_free()
