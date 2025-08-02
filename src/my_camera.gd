class_name MyCamera extends Camera2D

@onready var initial_zoom := zoom


func _ready() -> void:
	Player.instance.move_started.connect(_on_player_move_started)


func _on_player_move_started() -> void:
	var target_vertex := Player.instance.loop.get_vertex(Player.instance.target_angle)
	var focus_on_target := target_vertex is Loop and target_vertex.get_parent_loop() == Player.instance.loop
	var focus_vertex: Loop = target_vertex if focus_on_target else Player.instance.loop

	# Stay focused on the parent if this loop has no children
	#var has_children := false
	#for direction in Loop.DIRECTIONS:
	#	for vertex in loop.get_direction_vertices(direction):
	#		if vertex is Loop:
	#			has_children = true
	#			break
	#	if has_children:
	#		break
	#if not has_children and loop.has_parent_loop():
	#	loop = loop.get_parent_loop()

	var depth := (
		(focus_vertex as Loop).depth
		if focus_vertex is Loop
		else focus_vertex.get_parent_loop().depth
	)
	var new_zoom := initial_zoom / pow(Loop.CHILD_RADIUS, maxi(0, depth))

	var tweens: Array[PropertyTweener] = [
		create_tween().tween_property(self, "global_position", focus_vertex.global_position, 0.5),
		create_tween().tween_property(self, "zoom", new_zoom, 0.5),
	]
	for tween in tweens:
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_IN_OUT)
