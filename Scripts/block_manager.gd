# res://Scripts/BlockManager.gd
extends Node2D

@export var block_scene: PackedScene      # drag in your Block.tscn here
@export var block_width: float = 1024.0   # width of one block, in world units
@export var preload_radius: int = 2       # how many blocks on each side of the camera to keep loaded

# keep track of which “index” of block is in the world already
var _blocks := {}  # Dictionary<int, Node2D>

func _ready() -> void:
	# prime the world with some blocks before we start moving
	_update_blocks()

func _process(delta: float) -> void:
	# every frame see if we need to add/remove
	_update_blocks()

func _update_blocks() -> void:
	var cam = get_viewport().get_camera_2d()
	if not cam:
		return

	var cam_index = int(round(cam.global_position.x / block_width))

	# spawn blocks from (cam_index - preload_radius) to (cam_index + preload_radius), inclusive:
	for idx in range(cam_index - preload_radius, cam_index + preload_radius + 1):
		if not _blocks.has(idx):
			var b = block_scene.instantiate() as Node2D
			add_child(b)
			b.position = Vector2(idx * block_width, 0)
			_blocks[idx] = b

	# remove any that are too far away
	# (we can safely iterate a copy of the keys so we don’t modify the dict while looping)
	for existing_idx in _blocks.keys().duplicate():
		if existing_idx < cam_index - preload_radius - 1 \
		or existing_idx > cam_index + preload_radius + 1:
			_blocks[existing_idx].queue_free()
			_blocks.erase(existing_idx)
