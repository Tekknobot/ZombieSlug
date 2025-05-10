# res://Scenes/Effects/MuzzleFlashParticles.gd
extends Node2D

@onready var p := $Flash

func _ready() -> void:
	# start emitting immediately
	p.emitting = true
	# free after the particles finish their lifetime
	await get_tree().create_timer(p.lifetime).timeout
	queue_free()
