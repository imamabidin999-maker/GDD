class_name FloatingText
extends Label
## Angka atau teks singkat yang melayang ke atas lalu menghilang,
## misalnya damage, Tameng, atau "Kartu dikunci!".


static func spawn(parent: Node, text: String, at: Vector2, color: Color, big: bool = false) -> FloatingText:
	var ft := FloatingText.new()
	ft.text = text
	ft.add_theme_font_size_override("font_size", 24 if big else 16)
	ft.add_theme_color_override("font_color", color)
	ft.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.08))
	ft.add_theme_constant_override("outline_size", 3)
	ft.z_index = 50
	ft.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(ft)
	ft.reset_size()
	ft.position = at - Vector2(ft.size.x * 0.5, ft.size.y)
	ft._animate()
	return ft


func _animate() -> void:
	var start := position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", start + Vector2(0, -22), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.35).set_delay(0.6)
	tween.chain().tween_callback(queue_free)
