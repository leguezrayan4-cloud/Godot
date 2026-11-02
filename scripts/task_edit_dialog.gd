class_name TaskEditDialog
extends Control
## Modale d'édition complète d'une tâche : titre, description, rappel, catégorie,
## icône et récurrence.

signal saved(task: TaskData)

@onready var title_input: LineEdit = %TitleInput
@onready var desc_input: TextEdit = %DescInput
@onready var reminder_toggle: CheckButton = %ReminderToggle
@onready var reminder_box: VBoxContainer = %ReminderBox
@onready var day_row: HBoxContainer = %DayRow
@onready var hour_spin: SpinBox = %HourSpin
@onready var minute_spin: SpinBox = %MinuteSpin
@onready var category_row: HFlowContainer = %CategoryRow
@onready var icon_row: HFlowContainer = %IconRow
@onready var recurrence_row: HFlowContainer = %RecurrenceRow
@onready var cancel_button: Button = %CancelButton
@onready var save_button: Button = %SaveButton
@onready var card: PanelContainer = $Center/Card
@onready var header: Label = %Header
@onready var import_image_button: Button = %ImportImageButton
@onready var clear_image_button: Button = %ClearImageButton
@onready var image_preview: TextureRect = %ImagePreview
@onready var image_file_dialog: FileDialog = %ImageFileDialog

const RECURRENCES := [
	["Aucune", "none"],
	["Quotidienne", "daily"],
	["Hebdomadaire", "weekly"],
	["Mensuelle", "monthly"],
]
const DAY_OFFSETS := [
	["Aujourd'hui", 0],
	["Demain", 1],
	["Dans 3 j", 3],
	["Dans 7 j", 7],
]

var _task: TaskData = null
var _day_offset: int = 0
var _category: String = "Personnel"
var _icon: String = "personal"
var _recurrence: String = "none"

var _image: String = ""
var _day_chips: Array[Button] = []
var _category_chips: Array[Button] = []
var _icon_buttons: Array[Button] = []
var _recurrence_chips: Array[Button] = []


func _ready() -> void:
	UiFx.attach_recursive(self)
	_build_day_chips()
	_build_category_chips()
	_build_icon_buttons()
	_build_recurrence_chips()
	reminder_toggle.toggled.connect(_on_reminder_toggled)
	cancel_button.pressed.connect(_on_cancel)
	save_button.pressed.connect(_on_save)
	import_image_button.pressed.connect(_on_import_pressed)
	clear_image_button.pressed.connect(_on_clear_image)
	image_file_dialog.file_selected.connect(_on_image_selected)
	KeyboardAvoid.register_pad($Center, -1.0)
	visible = false


## Ouvre la modale sur une tâche donnée.
func open(task: TaskData) -> void:
	_task = task
	header.text = "Nouvelle tâche" if task.id == 0 else "Éditer la tâche"
	title_input.text = task.title
	desc_input.text = task.description
	_image = task.icon_image
	_update_image_preview()
	reminder_toggle.button_pressed = task.reminder_enabled
	_category = task.category
	_icon = task.icon if TaskIcons.has_icon(task.icon) else TaskIcons.from_category(task.category)
	_recurrence = task.recurrence

	_day_offset = 0
	var dt := Time.get_datetime_dict_from_system()
	var hour: int = int(dt.hour) + 1
	var minute: int = 0
	if task.has_reminder():
		var rd := Time.get_datetime_dict_from_unix_time(int(task.reminder_unix))
		hour = rd.hour
		minute = int(int(rd.minute) / 5.0) * 5
		_day_offset = _offset_from_date(rd)
	hour_spin.value = clampi(hour, 0, 23)
	minute_spin.value = clampi(minute, 0, 55)

	reminder_box.visible = task.reminder_enabled
	_refresh_chips()
	visible = true
	title_input.grab_focus()
	UiFx.fade_in(self, 0.2)
	if is_instance_valid(card):
		UiFx.pop_in(card, 0.3)


func _on_reminder_toggled(pressed: bool) -> void:
	reminder_box.visible = pressed


func _on_cancel() -> void:
	_close_modal()


func _close_modal() -> void:
	UiFx.fade_out(self, 0.18, func() -> void: visible = false)


func _on_save() -> void:
	if _task == null:
		return
	var title: String = title_input.text.strip_edges()
	if title.is_empty():
		title_input.grab_focus()
		return
	_task.title = title
	_task.description = desc_input.text.strip_edges()
	_task.category = _category
	_task.icon = _icon
	_task.icon_color = TaskIcons.color(_icon)
	_task.icon_image = _image
	_task.recurrence = _recurrence
	_task.reminder_enabled = reminder_toggle.button_pressed
	_task.reminder_unix = _compute_reminder_unix() if _task.reminder_enabled else 0.0
	_task.reminder_fired = false
	saved.emit(_task)
	_close_modal()


func _compute_reminder_unix() -> float:
	var today := Time.get_date_dict_from_system()
	var base := Time.get_unix_time_from_datetime_dict({
		"year": today.year, "month": today.month, "day": today.day,
		"hour": int(hour_spin.value), "minute": int(minute_spin.value), "second": 0,
	})
	return float(base) + float(_day_offset) * 86400.0


func _offset_from_date(dt: Dictionary) -> int:
	var target := Time.get_unix_time_from_datetime_dict({
		"year": dt.year, "month": dt.month, "day": dt.day, "hour": 0, "minute": 0, "second": 0,
	})
	var now := Time.get_date_dict_from_system()
	var today := Time.get_unix_time_from_datetime_dict({
		"year": now.year, "month": now.month, "day": now.day, "hour": 0, "minute": 0, "second": 0,
	})
	return int(round((target - today) / 86400.0))


# --- Construction des puces (chips) -----------------------------------------

func _build_day_chips() -> void:
	for entry in DAY_OFFSETS:
		var chip := _make_chip(str(entry[0]))
		var offset: int = entry[1]
		chip.pressed.connect(func() -> void:
			_day_offset = offset
			_refresh_chips())
		_day_chips.append(chip)
		day_row.add_child(chip)


func _build_category_chips() -> void:
	for cat in TaskIcons.CATEGORIES:
		var chip := _make_chip(cat)
		chip.pressed.connect(func() -> void:
			_category = cat
			if _icon == TaskIcons.from_category(_category) or _icon == TaskIcons.DEFAULT_ID:
				_icon = TaskIcons.from_category(_category)
			_refresh_chips())
		_category_chips.append(chip)
		category_row.add_child(chip)


func _build_icon_buttons() -> void:
	for id in TaskIcons.IDS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(52, 52)
		b.focus_mode = Control.FOCUS_NONE
		b.icon = TaskIcons.texture(id)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 26)
		b.tooltip_text = TaskIcons.label(id)
		UiFx.attach(b)
		var chosen := id
		b.pressed.connect(func() -> void:
			_icon = chosen
			_refresh_chips())
		_icon_buttons.append(b)
		icon_row.add_child(b)


func _build_recurrence_chips() -> void:
	for entry in RECURRENCES:
		var chip := _make_chip(str(entry[0]))
		var value: String = entry[1]
		chip.pressed.connect(func() -> void:
			_recurrence = value
			_refresh_chips())
		_recurrence_chips.append(chip)
		recurrence_row.add_child(chip)


func _make_chip(text: String) -> Button:
	var chip := Button.new()
	chip.text = text
	chip.focus_mode = Control.FOCUS_NONE
	chip.theme_type_variation = &"Chip"
	UiFx.attach(chip)
	return chip


func _refresh_chips() -> void:
	for i in _day_chips.size():
		_set_chip_active(_day_chips[i], int(DAY_OFFSETS[i][1]) == _day_offset)
	for i in _category_chips.size():
		_set_chip_active(_category_chips[i], TaskIcons.CATEGORIES[i] == _category)
	for i in _recurrence_chips.size():
		_set_chip_active(_recurrence_chips[i], RECURRENCES[i][1] == _recurrence)
	for i in _icon_buttons.size():
		_refresh_icon_button(_icon_buttons[i], TaskIcons.IDS[i], TaskIcons.IDS[i] == _icon)


func _set_chip_active(chip: Button, active: bool) -> void:
	chip.theme_type_variation = &"ChipActive" if active else &"Chip"


func _refresh_icon_button(button: Button, id: String, active: bool) -> void:
	var base := TaskIcons.color(id)
	var normal := _badge_style(base, active)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", _badge_style(base, true))


func _badge_style(color: Color, active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color if active else Color(color.r, color.g, color.b, 0.7)
	sb.set_corner_radius_all(15)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	if active:
		sb.border_color = Color(1, 1, 1, 0.95)
		sb.set_border_width_all(2)
	return sb


# --- Import d'image ----------------------------------------------------------

func _on_import_pressed() -> void:
	image_file_dialog.popup_centered_ratio(0.85)


func _on_clear_image() -> void:
	_image = ""
	_update_image_preview()


func _on_image_selected(path: String) -> void:
	var ext: String = path.get_extension().to_lower()
	if ext.is_empty():
		ext = "png"
	DirAccess.make_dir_recursive_absolute("user://task_icons")
	var dest := "user://task_icons/item_%d.%s" % [Time.get_ticks_msec(), ext]
	if DirAccess.copy_absolute(path, dest) != OK:
		var src := FileAccess.open(path, FileAccess.READ)
		if src == null:
			return
		var data := src.get_buffer(src.get_length())
		src.close()
		var out := FileAccess.open(dest, FileAccess.WRITE)
		if out == null:
			return
		out.store_buffer(data)
		out.close()
	_image = dest
	_update_image_preview()


func _update_image_preview() -> void:
	var tex: Texture2D = TaskIcons.image_texture(_image)
	image_preview.texture = tex
	image_preview.visible = tex != null