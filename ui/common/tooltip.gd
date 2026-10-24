class_name GameTooltip
extends PanelContainer
## Kotak keterangan yang muncul di dekat kursor saat kartu, Buto, atau ikon
## disorot. Satu tooltip dipakai bersama oleh seluruh layar.

const MAX_WIDTH := 190.0

var _label: RichTextLabel


func _ready() -> void:
	theme_type_variation = &"TooltipPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	visible = false
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(MAX_WIDTH, 0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


## Menampilkan teks (boleh BBCode) di dekat posisi layar `at`.
func show_text(text: String, at: Vector2) -> void:
	_label.text = text
	visible = true
	reset_size()
	# Tunggu ukuran label dihitung ulang sebelum memosisikan.
	await get_tree().process_frame
	if not visible:
		return
	reset_size()
	var screen := get_viewport_rect().size
	var pos := at + Vector2(10, -size.y - 6)
	pos.x = clampf(pos.x, 2, screen.x - size.x - 2)
	if pos.y < 2:
		pos.y = at.y + 14
	pos.y = clampf(pos.y, 2, screen.y - size.y - 2)
	global_position = pos


func hide_tip() -> void:
	visible = false
