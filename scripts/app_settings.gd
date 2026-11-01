extends Node
## Paramètres globaux de l'application (autoload « AppSettings »), persistés.

signal settings_changed

const SAVE_PATH := "user://settings.json"

var user_name: String = "Utilisateur"
var email: String = "utilisateur@email.com"
var sync_enabled: bool = true
var notifications: bool = true
var last_sync_text: String = "Jamais"
var ai_provider: String = "local"        # "local" (règles) | "http" (OpenAI-compatible)
var ai_base_url: String = "https://api.openai.com/v1"
var ai_model: String = "gpt-4o-mini"
var ai_api_key: String = ""


func _ready() -> void:
	load_settings()


func set_user_name(value: String) -> void:
	user_name = value.strip_edges()
	if user_name.is_empty():
		user_name = "Utilisateur"
	_commit()


func set_sync_enabled(value: bool) -> void:
	sync_enabled = value
	_commit()


func set_notifications(value: bool) -> void:
	notifications = value
	_commit()


func set_ai_provider(value: String) -> void:
	ai_provider = "http" if value == "http" else "local"
	_commit()


func set_ai_base_url(value: String) -> void:
	ai_base_url = value.strip_edges()
	if ai_base_url.is_empty():
		ai_base_url = "https://api.openai.com/v1"
	_commit()


func set_ai_model(value: String) -> void:
	ai_model = value.strip_edges()
	if ai_model.is_empty():
		ai_model = "gpt-4o-mini"
	_commit()


func set_ai_api_key(value: String) -> void:
	ai_api_key = value.strip_edges()
	_commit()


## Simule une synchronisation et horodate l'opération.
func sync_now() -> String:
	last_sync_text = Time.get_time_string_from_system()
	_commit()
	return last_sync_text


func _commit() -> void:
	settings_changed.emit()
	save_settings()


func save_settings() -> void:
	var data := {
		"user_name": user_name,
		"email": email,
		"sync_enabled": sync_enabled,
		"notifications": notifications,
		"last_sync_text": last_sync_text,
		"ai_provider": ai_provider,
		"ai_base_url": ai_base_url,
		"ai_model": ai_model,
		"ai_api_key": ai_api_key,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	user_name = str(parsed.get("user_name", user_name))
	email = str(parsed.get("email", email))
	sync_enabled = bool(parsed.get("sync_enabled", sync_enabled))
	notifications = bool(parsed.get("notifications", notifications))
	last_sync_text = str(parsed.get("last_sync_text", last_sync_text))
	ai_provider = str(parsed.get("ai_provider", ai_provider))
	ai_base_url = str(parsed.get("ai_base_url", ai_base_url))
	ai_model = str(parsed.get("ai_model", ai_model))
	ai_api_key = str(parsed.get("ai_api_key", ai_api_key))