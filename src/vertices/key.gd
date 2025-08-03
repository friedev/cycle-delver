class_name Key extends Vertex

const SCENE := preload("res://src/vertices/key.tscn")

## Additional distance added to the radius at which the key is drawn.
const PADDING := 192.0

## Total number of key IDs assigned. Key IDs are assigned in ascending order, so
## the next key will be assigned an ID equal to the current ID count.
static var id_count := 0

## The text to display for each key. Randomized so that the displayed IDs don't
## give any hints about the level generation process.
static var display_text: Array[String]


## Return the next key ID and increment the total ID count.
static func new_id() -> int:
	id_count += 1
	return id_count - 1


## Generate the text to display for each key ID.
static func generate_display_text() -> void:
	display_text.clear()
	for i in range(id_count):
		display_text.append(str(i + 1))
	display_text.shuffle()


@export var sprite: Sprite2D
@export var label: Label

## ID of this key; it unlocks locks with the matching ID. Must be non-negative.
var key_id: int:
	set(value):
		assert(value >= 0)
		key_id = value
		update_label()


func _ready() -> void:
	super._ready()
	update_label()
	var parent_loop := get_parent_loop()
	if parent_loop != null:
		sprite.modulate = parent_loop.get_border_color()
		label.modulate = parent_loop.get_fill_color()


func update_position() -> void:
	position = Vector2(Loop.DRAW_RADIUS + PADDING, 0).rotated(angle)


func update_label() -> void:
	if key_id < len(Key.display_text):
		label.text = str(Key.display_text[key_id])
