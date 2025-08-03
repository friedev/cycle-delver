class_name MyCamera extends Camera2D

@onready var initial_zoom := zoom

var loop: Loop


func _ready() -> void:
	Player.instance.move_started.connect(_on_player_move_started)
	smooth_zoom_to_loop(Player.instance.loop)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		if loop != Player.instance.loop:
			var new_loop := Player.instance.loop
			while new_loop.has_parent_loop() and new_loop.get_parent_loop() != loop:
				new_loop = new_loop.get_parent_loop()
			smooth_zoom_to_loop(new_loop)
	elif event.is_action_pressed("zoom_out"):
		if loop.has_parent_loop():
			smooth_zoom_to_loop(loop.get_parent_loop())
	elif event.is_action_pressed("toggle_zoom"):
		# Zoom out to the root loop
		if loop == Player.instance.loop:
			var new_loop := loop
			while new_loop.has_parent_loop():
				new_loop = new_loop.get_parent_loop()
			smooth_zoom_to_loop(new_loop)
		# Zoom in to the player's loop
		else:
			smooth_zoom_to_loop(Player.instance.loop)


func _on_player_move_started() -> void:
	smooth_zoom_to_vertex(Player.instance.get_target_vertex())


func smooth_zoom_to_vertex(target_vertex: Vertex) -> void:
	var focus_on_target := target_vertex is Loop and target_vertex.get_parent_loop() == Player.instance.loop
	smooth_zoom_to_loop(target_vertex if focus_on_target else Player.instance.loop)


func smooth_zoom_to_loop(new_loop: Loop) -> void:
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
	loop = new_loop
	var new_zoom := initial_zoom / pow(Loop.CHILD_RADIUS, maxi(0, loop.depth))
	var new_global_position := loop.global_position
	create_tween().tween_property(self, "zoom", new_zoom, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	create_tween().tween_property(self, "global_position", new_global_position, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
