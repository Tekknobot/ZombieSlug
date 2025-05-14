extends AudioStreamPlayer2D

@export var tracks: Array[AudioStream] = []  # assign your audio files in the Inspector

var _current_index: int = 0

func _ready() -> void:
	if tracks.is_empty():
		return
	# start with the first track
	_current_index = 0
	stream = tracks[_current_index]
	play()
	# connect the finished signal to cycle tracks
	finished.connect(_on_track_finished)

func _on_track_finished() -> void:
	# advance index, wrap around
	_current_index = (_current_index + 1) % tracks.size()
	stream = tracks[_current_index]
	play()
