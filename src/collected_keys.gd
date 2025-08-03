extends Node2D

## Horizontal spacing between keys.
const SPACING := 16.0

func _ready() -> void:
	SignalBus.key_collected.connect(_on_key_collected)
	SignalBus.key_removed.connect(_on_key_removed)
	

func lay_out_keys() -> void:
	for i in range(get_child_count()):
		var key: Key = get_child(i)
		var texture_size := key.sprite.texture.get_size()
		key.position = Vector2((texture_size.x + SPACING) * (i + 0.5), texture_size.y * 0.5)
	

func _on_key_collected(key: Key) -> void:
	add_child(key)
	lay_out_keys()


func _on_key_removed(key_id: int) -> void:
	for key: Key in get_children():
		if key.key_id == key_id:
			remove_child(key)
			key.queue_free()
			lay_out_keys()
			return
	assert(false, "Key %d not found" % key_id)
