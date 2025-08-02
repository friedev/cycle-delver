class_name Goal extends Vertex

const SCENE := preload("res://src/goal.tscn")

static func hue_to_color(hue: float) -> Color:
	return Color.from_hsv(hue, 0.5, 0.75)

func _ready() -> void:
	super._ready()
	modulate = hue_to_color(get_parent_loop().get_hue())
