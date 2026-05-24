class_name RandomPitchSound extends AudioStreamPlayer

@export var pitch_scale_range := 0.25

@onready var base_pitch_scale := pitch_scale

func randomize_and_play(from_position := 0.0) -> void:
	pitch_scale = (
		base_pitch_scale
		+ randf_range(-1.0, +1.0) * pitch_scale_range
	)
	super.play(from_position)