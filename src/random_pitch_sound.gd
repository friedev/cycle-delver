class_name RandomPitchSound extends AudioStreamPlayer

@export var pitch_scale_range := 0.25

@onready var base_pitch_scale := self.pitch_scale

func randomize_and_play(from_position := 0.0) -> void:
	self.pitch_scale = (
		self.base_pitch_scale
		+ randf_range(-1.0, +1.0) * self.pitch_scale_range
	)
	super.play(from_position)