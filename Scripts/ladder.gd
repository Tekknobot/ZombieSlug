extends Area2D

func _ready() -> void:
	add_to_group("Ladders")
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited",  Callable(self, "_on_body_exited"))

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		# flag the player as being *in* a ladder
		body.on_ladder = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		body.on_ladder = false
		body.is_climbing = false    # stop climbing the moment you leave
