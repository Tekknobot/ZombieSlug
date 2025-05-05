extends Area2D

@export var speed := 600.0
var direction := Vector2.RIGHT

@onready var anim := $AnimatedSprite2D

func _ready() -> void:
	# start the animation you defined in the SpriteFrames
	anim.play("fly")

func _process(delta: float) -> void:
	global_position += direction * speed * delta
