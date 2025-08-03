extends Node2D

## Horizontal spacing between keys.
const SPACING := 32.0

func _ready() -> void:
	SignalBus.key_collected.connect(_on_key_collected)
	SignalBus.key_removed.connect(_on_key_removed)
	

func lay_out_keys() -> void:
	var position_index := 0
	for i in range(get_child_count()):
		var key: Key = get_child(i)
		if key.used:
			continue
		var texture_size := key.sprite.texture.get_size()
		var new_position := Vector2(
			texture_size.x * 0.5 + (texture_size.x + SPACING) * position_index,
			texture_size.y * 0.5
		)
		if key.just_collected:
			key.position = new_position
			key.just_collected = false
		else:
			create_tween().tween_property(key, "position", new_position, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		position_index += 1
	

func _on_key_collected(key: Key) -> void:
	add_child(key)
	key.just_collected = true
	lay_out_keys()


func _on_key_removed(key_id: int) -> void:
	for key: Key in get_children():
		if key.key_id == key_id:
			key.used = true
			lay_out_keys()
			await create_tween().tween_property(key, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).finished
			remove_child(key)
			key.queue_free()
			return
	assert(false, "Key %d not found" % key_id)
