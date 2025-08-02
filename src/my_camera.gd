class_name MyCamera extends Camera2D


@onready var initial_zoom := zoom


func _ready() -> void:
	Player.instance.move_finished.connect(_on_player_move_finished)


func _on_player_move_finished() -> void:
	var loop := Player.instance.loop
	if loop.has_parent_loop():
		loop = loop.get_parent_loop()
	var new_zoom := initial_zoom / pow(Loop.CHILD_RADIUS, maxi(0, Player.instance.loop.depth - 1))

	var tweens: Array[PropertyTweener] = [
		create_tween().tween_property(self, "global_position", loop.global_position, 1.0 / 3.0),
		create_tween().tween_property(self, "zoom", new_zoom, 1.0 / 3.0)
	]
	for tween in tweens:
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_IN_OUT)
