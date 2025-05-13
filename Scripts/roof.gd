extends StaticBody2D

@export var one_way_margin: float = 2.0

func _ready() -> void:
	var cs = $CollisionShape2D
	# Expect that in the editor you've drawn a RectangleShape2D
	var rect = cs.shape as RectangleShape2D
	if rect:
		# grab half-width from your editor shape
		var half_w = rect.extents.x
		# build a matching segment so there are no side walls
		var seg = SegmentShape2D.new()
		seg.a = Vector2(-half_w, 0)
		seg.b = Vector2( half_w, 0)
		cs.shape = seg
	else:
		push_warning("Roof.gd: expected CollisionShape2D.shape to be RectangleShape2D")
	cs.one_way_collision = true
	cs.one_way_collision_margin = one_way_margin
	add_to_group("Roof")
