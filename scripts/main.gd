class_name Main
extends Control
## Coquille de l'application : barre de navigation inférieure, bascule entre les
## trois onglets et gestion de la modale d'édition des tâches.

@onready var tasks_view: TasksView = %TasksView
@onready var assistant_view: AssistantView = %AssistantView
@onready var settings_view: SettingsView = %SettingsView
@onready var edit_dialog: TaskEditDialog = %EditDialog
@onready var nav_tasks: Button = %NavTasks
@onready var nav_assistant: Button = %NavAssistant
@onready var nav_settings: Button = %NavSettings
@onready var reminder_overlay: Control = %ReminderOverlay
@onready var alert_card: PanelContainer = %AlertCard
@onready var alert_task_label: Label = %AlertTask
@onready var alert_time_label: Label = %AlertTime
@onready var alert_done: Button = %AlertDone
@onready var alert_snooze: Button = %AlertSnooze

var _tabs: Dictionary = {}
var _current_tab: String = ""
var _alert_task: TaskData = null
var _editing_new: bool = false
var _sfx: AudioStreamPlayer


func _ready() -> void:
	UiFx.attach_recursive(self)
	_tabs = {
		"tasks": [tasks_view, nav_tasks],
		"assistant": [assistant_view, nav_assistant],
		"settings": [settings_view, nav_settings],
	}
	nav_tasks.pressed.connect(func() -> void: show_tab("tasks"))
	nav_assistant.pressed.connect(func() -> void: show_tab("assistant"))
	nav_settings.pressed.connect(func() -> void: show_tab("settings"))
	tasks_view.edit_requested.connect(_on_edit_requested)
	tasks_view.create_requested.connect(_on_create_requested)
	edit_dialog.saved.connect(_on_task_saved)
	alert_done.pressed.connect(_on_alert_done)
	alert_snooze.pressed.connect(_on_alert_snooze)
	Reminder.reminder_due.connect(_on_reminder_due)
	_sfx = AudioStreamPlayer.new()
	_sfx.stream = preload("res://assets/generated/audio/reminder.mp3")
	_sfx.volume_db = -5.0
	add_child(_sfx)
	reminder_overlay.visible = false
	nav_tasks.icon = _load_nav_icon("nav_tasks")
	nav_assistant.icon = _load_nav_icon("nav_assistant")
	nav_settings.icon = _load_nav_icon("nav_settings")
	show_tab("tasks")


## Charge une icône de navigation, avec repli lecture directe si non importée.
func _load_nav_icon(icon_name: String) -> Texture2D:
	var path := "res://assets/generated/%s.png" % icon_name
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		var img := Image.new()
		if img.load(path) == OK:
			tex = ImageTexture.create_from_image(img)
	return tex


## Affiche l'onglet demandé avec une transition par glissement.
func show_tab(tab_id: String) -> void:
	for key in _tabs:
		var button: Button = _tabs[key][1]
		button.theme_type_variation = &"NavActive" if key == tab_id else &"NavButton"

	if tab_id == _current_tab:
		return

	var order := ["tasks", "assistant", "settings"]
	var incoming: Control = _tabs[tab_id][0]
	var width: float = size.x if size.x > 0.0 else 400.0
	incoming.visible = true

	if _current_tab == "":
		incoming.position.x = 0.0
		incoming.modulate.a = 1.0
		_current_tab = tab_id
		UiFx.fade_in(incoming, 0.2)
		return

	var direction: int = signi(order.find(tab_id) - order.find(_current_tab))
	var outgoing: Control = _tabs[_current_tab][0]
	var offset: float = width * float(direction)
	incoming.position.x = offset
	incoming.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(incoming, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(incoming, "modulate:a", 1.0, 0.3)
	tw.tween_property(outgoing, "position:x", -offset, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(outgoing, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(func() -> void:
		outgoing.visible = false
		outgoing.position.x = 0.0
		outgoing.modulate.a = 1.0)
	_current_tab = tab_id


## Affiche l'alarme d'un rappel imminent.
func _on_reminder_due(task: TaskData) -> void:
	_alert_task = task
	alert_task_label.text = task.title
	alert_time_label.text = task.reminder_text()
	reminder_overlay.visible = true
	UiFx.fade_in(reminder_overlay, 0.2)
	if is_instance_valid(alert_card):
		UiFx.pop_in(alert_card, 0.3)
	if _sfx:
		_sfx.play()


func _on_alert_done() -> void:
	if _alert_task != null:
		TaskStore.set_done(_alert_task.id, true)
	_close_alert()


func _on_alert_snooze() -> void:
	if _alert_task != null:
		_alert_task.reminder_unix += 300.0
		_alert_task.reminder_fired = false
		TaskStore.update_task(_alert_task)
	_close_alert()


func _close_alert() -> void:
	_alert_task = null
	UiFx.fade_out(reminder_overlay, 0.2, func() -> void: reminder_overlay.visible = false)


func _on_edit_requested(task: TaskData) -> void:
	_editing_new = false
	edit_dialog.open(task)


func _on_create_requested() -> void:
	_editing_new = true
	edit_dialog.open(TaskData.new())


func _on_task_saved(task: TaskData) -> void:
	if _editing_new:
		TaskStore.add_task(task.title, {
			"icon": task.icon,
			"icon_color": task.icon_color,
			"icon_image": task.icon_image,
			"category": task.category,
			"description": task.description,
			"reminder_enabled": task.reminder_enabled,
			"reminder_unix": task.reminder_unix,
			"recurrence": task.recurrence,
		})
		_editing_new = false
	else:
		Reminder.rearm(task)
		TaskStore.update_task(task)