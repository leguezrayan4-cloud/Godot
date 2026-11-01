class_name SettingsView
extends Control
## Vue Paramètres : profil, synchronisation, préférences et gestion des données.

@onready var avatar: PanelContainer = %Avatar
@onready var avatar_label: Label = %AvatarLabel
@onready var name_label: Label = %NameLabel
@onready var email_label: Label = %EmailLabel
@onready var provider_label: Label = %ProviderLabel
@onready var name_input: LineEdit = %NameInput
@onready var sign_out_button: Button = %SignOutButton
@onready var sync_toggle: CheckButton = %SyncToggle
@onready var sync_status: Label = %SyncStatus
@onready var sync_button: Button = %SyncButton
@onready var notif_toggle: CheckButton = %NotifToggle
@onready var ai_toggle: CheckButton = %AiToggle
@onready var ai_url_input: LineEdit = %AiUrlInput
@onready var ai_model_input: LineEdit = %AiModelInput
@onready var ai_key_input: LineEdit = %AiKeyInput
@onready var ai_status: Label = %AiStatus
@onready var data_count: Label = %DataCount
@onready var clear_button: Button = %ClearButton


func _ready() -> void:
	_style_avatar()
	UiFx.attach_recursive(self)
	name_input.text_submitted.connect(func(_t: String) -> void: _apply_name())
	name_input.focus_exited.connect(_apply_name)
	sign_out_button.pressed.connect(_on_sign_out)
	sync_toggle.toggled.connect(func(v: bool) -> void:
		AppSettings.set_sync_enabled(v)
		_refresh())
	sync_button.pressed.connect(_on_sync)
	notif_toggle.toggled.connect(func(v: bool) -> void: AppSettings.set_notifications(v))
	ai_toggle.toggled.connect(func(v: bool) -> void:
		AppSettings.set_ai_provider("http" if v else "local"))
	ai_url_input.focus_exited.connect(_apply_ai)
	ai_model_input.focus_exited.connect(_apply_ai)
	ai_key_input.focus_exited.connect(_apply_ai)
	ai_url_input.text_submitted.connect(func(_t: String) -> void: _apply_ai())
	ai_model_input.text_submitted.connect(func(_t: String) -> void: _apply_ai())
	ai_key_input.text_submitted.connect(func(_t: String) -> void: _apply_ai())
	clear_button.pressed.connect(func() -> void: TaskStore.clear_all())
	AppSettings.settings_changed.connect(_refresh)
	Auth.session_changed.connect(_refresh)
	TaskStore.tasks_changed.connect(_refresh)
	_refresh()


func _style_avatar() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.42, 0.36, 0.91)
	sb.set_corner_radius_all(29)
	avatar.add_theme_stylebox_override("panel", sb)


func _refresh() -> void:
	var display: String = Auth.display_name if Auth.logged_in else "Invité"
	name_label.text = display
	email_label.text = Auth.email if Auth.logged_in else "Non connecté"
	provider_label.text = Auth.provider_label()
	if not name_input.has_focus():
		name_input.text = display
	sync_toggle.button_pressed = AppSettings.sync_enabled
	notif_toggle.button_pressed = AppSettings.notifications
	ai_toggle.button_pressed = AppSettings.ai_provider == "http"
	if not ai_url_input.has_focus():
		ai_url_input.text = AppSettings.ai_base_url
	if not ai_model_input.has_focus():
		ai_model_input.text = AppSettings.ai_model
	if not ai_key_input.has_focus():
		ai_key_input.text = AppSettings.ai_api_key
	ai_status.text = _ai_status_text()
	sync_status.text = "Dernière synchronisation : %s" % AppSettings.last_sync_text
	data_count.text = "%d tâche(s) enregistrée(s)" % TaskStore.count_total()
	var initial: String = display.substr(0, 1)
	avatar_label.text = initial.to_upper() if not initial.is_empty() else "?"


func _apply_name() -> void:
	Auth.set_display_name(name_input.text)
	name_label.text = Auth.display_name


func _on_sign_out() -> void:
	Auth.sign_out()
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	await tw.finished
	get_tree().reload_current_scene()


func _on_sync() -> void:
	if not AppSettings.sync_enabled:
		AppSettings.set_sync_enabled(true)
	var when: String = AppSettings.sync_now()
	sync_status.text = "Dernière synchronisation : %s" % when


func _apply_ai() -> void:
	AppSettings.set_ai_base_url(ai_url_input.text)
	AppSettings.set_ai_model(ai_model_input.text)
	AppSettings.set_ai_api_key(ai_key_input.text)
	_refresh()


func _ai_status_text() -> String:
	if AppSettings.ai_provider != "http":
		return "Mode local : aucune donnée ne quitte l'appareil."
	if AppSettings.ai_api_key.is_empty():
		return "Mode en ligne choisi, mais la clé API est vide — repli sur le mode local."
	return "IA en ligne · %s" % AppSettings.ai_model