class_name AccentTheme
extends RefCounted
## Génère le thème de l'application à partir de taskup_theme.tres en recolant
## les éléments violets avec la couleur d'accent choisie dans les Réglages.

const BASE_THEME := "res://theme/taskup_theme.tres"


static func build(accent: Color) -> Theme:
	var base: Theme = load(BASE_THEME) as Theme
	if base == null:
		return Theme.new()
	var theme: Theme = base.duplicate(true) as Theme
	if theme == null:
		return base
	_recolor_button(theme, accent)
	_recolor_chips(theme, accent)
	_recolor_nav(theme, accent)
	_recolor_inputs(theme, accent)
	_recolor_misc(theme, accent)
	return theme


static func _flat(theme: Theme, style: String, type: String) -> StyleBoxFlat:
	var sb: StyleBox = theme.get_stylebox(style, type)
	return sb as StyleBoxFlat


static func _recolor_button(theme: Theme, accent: Color) -> void:
	_set_bg(theme, "Button", "normal", accent)
	_set_bg(theme, "Button", "hover", accent.lightened(0.09))
	_set_bg(theme, "Button", "pressed", accent.darkened(0.12))


static func _recolor_chips(theme: Theme, accent: Color) -> void:
	for style in ["normal", "hover", "pressed"]:
		var sb := _flat(theme, style, "ChipActive")
		if sb != null:
			sb.bg_color = Color(accent.r, accent.g, accent.b, 0.22)
			sb.border_color = Color(accent.r, accent.g, accent.b, 0.9)
	theme.set_color("font_color", "ChipActive", accent.lightened(0.45))
	theme.set_color("font_hover_color", "ChipActive", Color(1, 1, 1, 1))


static func _recolor_nav(theme: Theme, accent: Color) -> void:
	for style in ["normal", "hover", "pressed"]:
		var sb := _flat(theme, style, "NavActive")
		if sb != null:
			sb.bg_color = Color(accent.r, accent.g, accent.b, 0.18)
	theme.set_color("font_color", "NavActive", accent.lightened(0.45))
	theme.set_color("font_hover_color", "NavActive", Color(1, 1, 1, 1))
	theme.set_color("icon_normal_color", "NavActive", accent.lightened(0.35))
	theme.set_color("icon_hover_color", "NavActive", Color(1, 1, 1, 1))


static func _recolor_inputs(theme: Theme, accent: Color) -> void:
	for pair in [["LineEdit", "focus"], ["TextEdit", "focus"], ["OptionButton", "pressed"]]:
		var sb := _flat(theme, pair[1], pair[0])
		if sb != null:
			sb.border_color = accent
	theme.set_color("caret_color", "LineEdit", accent.lightened(0.2))
	theme.set_color("caret_color", "TextEdit", accent.lightened(0.2))
	theme.set_color("selection_color", "LineEdit", Color(accent.r, accent.g, accent.b, 0.45))
	theme.set_color("selection_color", "TextEdit", Color(accent.r, accent.g, accent.b, 0.45))


static func _recolor_misc(theme: Theme, accent: Color) -> void:
	var fill := _flat(theme, "fill", "ProgressBar")
	if fill != null:
		fill.bg_color = accent
	var hover := _flat(theme, "hover", "PopupMenu")
	if hover != null:
		hover.bg_color = Color(accent.r, accent.g, accent.b, 0.28)


static func _set_bg(theme: Theme, type: String, style: String, color: Color) -> void:
	var sb := _flat(theme, style, type)
	if sb != null:
		sb.bg_color = color