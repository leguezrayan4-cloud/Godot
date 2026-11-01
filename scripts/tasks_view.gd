class_name TasksView
extends Control
## Vue principale : filtres, tri et liste des tâches.

signal edit_requested(task: TaskData)
signal create_requested

@onready var task_list: VBoxContainer = %TaskList
@onready var empty_state: VBoxContainer = %EmptyState
@onready var count_label: Label = %CountLabel
@onready var search_input: LineEdit = %SearchInput
@onready var filter_button: Button = %FilterButton
@onready var filter_popup: PopupPanel = %FilterPopup
@onready var filter_box: VBoxContainer = %FilterBox

const STATUS_OPTIONS := [
	["Toutes", "all"],
	["À faire", "active"],
	["Terminées", "done"],
]
const SORT_OPTIONS := [
	["Échéance", "due"],
	["Récentes", "created"],
	["A-Z", "title"],
]

const COLOR_ACTIVE := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_DONE := Color(0.5, 0.52, 0.58, 1.0)
const COLOR_ACCENT := Color(0.72, 0.67, 1.0, 1.0)
const COLOR_DANGER := Color(0.98, 0.55, 0.58, 1.0)
const COLOR_LABEL := Color(0.55, 0.58, 0.65, 1.0)

var _status: String = "all"
var _category: String = ""
var _sort: String = "due"
var _search: String = ""

var _status_chips: Array[Button] = []
var _sort_chips: Array[Button] = []
var _category_chips: Array[Button] = []
var _category_values: Array[String] = []
var _cat_container: HBoxContainer


func _ready() -> void:
	UiFx.attach_recursive(self)
	search_input.text_changed.connect(_on_search_changed)
	filter_button.pressed.connect(_open_filters)
	%CreateButton.pressed.connect(func() -> void: create_requested.emit())
	TaskStore.tasks_changed.connect(_refresh)
	_build_filter_panel()
	_refresh()


func _on_search_changed(text: String) -> void:
	_search = text.strip_edges().to_lower()
	_render()


# --- Champ « puce » (chip) ---------------------------------------------------

func _make_chip(text: String) -> Button:
	var chip := Button.new()
	chip.text = text
	chip.focus_mode = Control.FOCUS_NONE
	chip.theme_type_variation = &"Chip"
	UiFx.attach(chip)
	return chip


func _set_chip_active(chip: Button, active: bool) -> void:
	chip.theme_type_variation = &"ChipActive" if active else &"Chip"


func _add_section(title: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_color_override("font_color", COLOR_LABEL)
	label.add_theme_font_size_override("font_size", 12)
	filter_box.add_child(label)


func _build_filter_panel() -> void:
	filter_box.custom_minimum_size = Vector2(252, 0)

	_add_section("STATUT")
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	filter_box.add_child(status_row)
	for entry in STATUS_OPTIONS:
		var chip := _make_chip(str(entry[0]))
		var value: String = entry[1]
		chip.pressed.connect(func() -> void:
			_status = value
			_refresh())
		_status_chips.append(chip)
		status_row.add_child(chip)

	_add_section("CATÉGORIE")
	_cat_container = HBoxContainer.new()
	_cat_container.add_theme_constant_override("separation", 8)
	filter_box.add_child(_cat_container)
	_build_categories()

	_add_section("TRIER PAR")
	var sort_row := HBoxContainer.new()
	sort_row.add_theme_constant_override("separation", 8)
	filter_box.add_child(sort_row)
	for entry in SORT_OPTIONS:
		var chip := _make_chip(str(entry[0]))
		var value: String = entry[1]
		chip.pressed.connect(func() -> void:
			_sort = value
			_refresh())
		_sort_chips.append(chip)
		sort_row.add_child(chip)


func _open_filters() -> void:
	_build_categories()
	_update_chip_states()
	filter_popup.reset_size()
	var rect: Rect2 = filter_button.get_global_rect()
	filter_popup.position = Vector2i(int(rect.end.x - filter_popup.size.x), int(rect.end.y + 6))
	filter_popup.popup()


func _build_categories() -> void:
	if _cat_container == null:
		return
	for child in _cat_container.get_children():
		_cat_container.remove_child(child)
		child.free()
	_category_chips.clear()
	_category_values.clear()
	_category_values.append("")
	for cat in TaskIcons.CATEGORIES:
		_category_values.append(cat)
	for cat in TaskStore.used_categories():
		if not _category_values.has(cat):
			_category_values.append(cat)
	for i in _category_values.size():
		var label: String = "Toutes" if _category_values[i] == "" else _category_values[i]
		var chip := _make_chip(label)
		var value: String = _category_values[i]
		chip.pressed.connect(func() -> void:
			_category = value
			_refresh())
		_category_chips.append(chip)
		_cat_container.add_child(chip)


func _update_chip_states() -> void:
	for i in _status_chips.size():
		_set_chip_active(_status_chips[i], STATUS_OPTIONS[i][1] == _status)
	for i in _sort_chips.size():
		_set_chip_active(_sort_chips[i], SORT_OPTIONS[i][1] == _sort)
	for i in _category_chips.size():
		if i < _category_values.size():
			_set_chip_active(_category_chips[i], _category_values[i] == _category)


func _update_filter_button() -> void:
	var active_filters: int = 0
	if _status != "all":
		active_filters += 1
	if _category != "":
		active_filters += 1
	if _sort != "due":
		active_filters += 1
	filter_button.text = "Filtrer" if active_filters == 0 else "Filtrer (%d)" % active_filters


# --- Mise à jour globale -----------------------------------------------------

func _refresh() -> void:
	_build_categories()
	_update_chip_states()
	_update_count()
	_update_filter_button()
	_render()


func _update_count() -> void:
	var active: int = TaskStore.count_active()
	var done: int = TaskStore.count_done()
	count_label.text = "%d à faire · %d terminée%s" % [active, done, "s" if done > 1 else ""]


func _render() -> void:
	for child in task_list.get_children():
		child.queue_free()
	var list: Array[TaskData] = TaskStore.query(_status, _category, _sort)
	var shown: int = 0
	for task in list:
		if _search != "" and not _matches(task):
			continue
		var card: PanelContainer = _build_card(task)
		task_list.add_child(card)
		UiFx.fade_in(card, 0.22)
		shown += 1
	empty_state.visible = shown == 0


func _matches(task: TaskData) -> bool:
	return task.title.to_lower().contains(_search) or task.description.to_lower().contains(_search)


# --- Construction d'une carte ------------------------------------------------

func _build_card(task: TaskData) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"TaskCard"

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	row.add_child(_make_icon_badge(task))

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)

	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.set_meta("task_id", task.id)
	_apply_title(title, task)
	info.add_child(title)

	var meta := _make_meta_row(task)
	if meta.get_child_count() > 0:
		info.add_child(meta)

	var check := CheckBox.new()
	check.custom_minimum_size = Vector2(36, 0)
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	check.button_pressed = task.done
	check.toggled.connect(func(pressed: bool) -> void: TaskStore.set_done(task.id, pressed))
	row.add_child(check)

	var menu := Button.new()
	menu.text = "•••"
	menu.custom_minimum_size = Vector2(44, 40)
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu.focus_mode = Control.FOCUS_NONE
	menu.tooltip_text = "Options"
	row.add_child(menu)
	UiFx.attach(menu)

	var popup := PopupMenu.new()
	popup.add_item("Éditer", 0)
	popup.add_item("Supprimer", 1)
	menu.add_child(popup)

	menu.pressed.connect(func() -> void: _open_menu(menu, popup))
	popup.id_pressed.connect(func(id: int) -> void:
		if id == 0:
			edit_requested.emit(task)
		else:
			TaskStore.remove_task(task.id))

	return card


func _apply_title(label: RichTextLabel, task: TaskData) -> void:
	if task.done:
		label.text = "[s]%s[/s]" % task.title
		label.modulate = COLOR_DONE
	else:
		label.text = task.title
		label.modulate = COLOR_ACTIVE


func _make_meta_row(task: TaskData) -> HBoxContainer:
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 8)

	if task.has_reminder():
		var color: Color = COLOR_DANGER if task.is_overdue() else COLOR_ACCENT
		meta.add_child(_make_badge(task.reminder_text(), color))

	var cat := Label.new()
	cat.text = task.category
	cat.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65, 1))
	cat.add_theme_font_size_override("font_size", 12)
	meta.add_child(cat)

	if task.recurrence != "none":
		var rec := Label.new()
		rec.text = task.recurrence_label()
		rec.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65, 1))
		rec.add_theme_font_size_override("font_size", 12)
		meta.add_child(rec)

	return meta


func _make_badge(text: String, color: Color) -> PanelContainer:
	var badge := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, 0.18)
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	badge.add_theme_stylebox_override("panel", sb)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 12)
	badge.add_child(label)
	return badge


func _make_icon_badge(task: TaskData) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(46, 46)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var img_tex: Texture2D = TaskIcons.image_texture(task.icon_image)
	var has_image: bool = img_tex != null
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.18, 0.22) if has_image else TaskIcons.color(task.icon)
	sb.set_corner_radius_all(15)
	badge.add_theme_stylebox_override("panel", sb)

	var tex := TextureRect.new()
	tex.texture = img_tex if has_image else TaskIcons.texture(task.icon)
	tex.custom_minimum_size = Vector2(26, 26)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(tex)
	return badge


func _open_menu(button: Button, popup: PopupMenu) -> void:
	popup.reset_size()
	var rect: Rect2 = button.get_global_rect()
	popup.position = Vector2i(int(rect.end.x - popup.size.x), int(rect.end.y + 4))
	popup.popup()