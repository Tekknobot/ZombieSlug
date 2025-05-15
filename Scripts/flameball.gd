# FlameBall.gd
extends Area2D

@export var speed: float    = 300.0
@export var damage: float   = 5.0
@export var lifetime: float = 0.8

var dir: Vector2 = Vector2.RIGHT
var life: float

func _ready() -> void:
	life = lifetime
	connect("body_entered", Callable(self, "_on_body_entered"))
	$GPUParticles2D.emitting = true  # play the burst

func _physics_process(delta: float) -> void:
	# move
	position += dir * speed * delta

	# lifetime check
	life -= delta
	if life <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	# ignore the player entirely
	if body.is_in_group("Player"):
		return

	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
