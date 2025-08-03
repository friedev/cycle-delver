extends CanvasItem

## Fade duration in seconds.
@export var duration: float
@export var tween_trans: Tween.TransitionType
@export var tween_ease: Tween.EaseType


func _ready() -> void:
	fade_in()
	SignalBus.game_over.connect(_on_game_over)


func fade_to(alpha: float) -> PropertyTweener:
	return create_tween().tween_property(self, "modulate", Color(1.0, 1.0, 1.0, alpha), duration).set_trans(tween_trans).set_ease(tween_ease)


func fade_in() -> PropertyTweener:
	return fade_to(0.0)


func fade_out() -> PropertyTweener:
	return fade_to(1.0)


func _on_game_over() -> void:
	await fade_out().finished
	get_tree().reload_current_scene()