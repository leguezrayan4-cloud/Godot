class_name NotificationBridge
## Passerelle de notifications système.
##
## - Android : utilise le singleton du plugin « GodotNotifications »
##   (https://github.com/arconsis/godot-notifications) lorsqu'il est installé
##   dans le projet exporté — notifications réelles dans la barre système,
##   y compris alarmes planifiées, même application fermée.
## - Desktop / éditeur : repli sur le dialogue natif du système
##   (DisplayServer.dialog_show), non bloquant.
## - Sans aucun des deux : retourne false et l'appelant garde l'alerte in-app.

const PLUGIN_NAME := "GodotNotifications"


## Vrai si un plugin de notification système est présent (build Android).
static func system_available() -> bool:
	return Engine.has_singleton(PLUGIN_NAME)


## Notification immédiate. [param id] permet d'annuler la notification plus tard.
static func notify(id: int, title: String, body: String) -> bool:
	var plugin: Object = _plugin()
	if plugin != null:
		if plugin.has_method("notify"):
			plugin.notify(id, title, body)
			return true
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG):
		DisplayServer.dialog_show(title, body, ["OK"], func(_idx: int) -> void: pass)
		return true
	return false


## Planifie une alarme système à une date Unix (plugin Android uniquement).
static func schedule(id: int, title: String, body: String, at_unix: int) -> bool:
	var plugin: Object = _plugin()
	if plugin == null:
		return false
	if plugin.has_method("schedule"):
		plugin.schedule(id, title, body, at_unix)
		return true
	if plugin.has_method("notifyAt"):
		plugin.notifyAt(id, title, body, at_unix)
		return true
	if plugin.has_method("notify"):
		# Repli : notification immédiate plutôt que rien.
		plugin.notify(id, title, body)
		return true
	return false


## Annule une notification planifiée.
static func cancel(id: int) -> void:
	var plugin: Object = _plugin()
	if plugin != null and plugin.has_method("cancel"):
		plugin.cancel(id)


static func _plugin() -> Object:
	if Engine.has_singleton(PLUGIN_NAME):
		return Engine.get_singleton(PLUGIN_NAME)
	return null


## Identifiant stable dérivé de l'id de la tâche.
static func task_notification_id(task_id: int) -> int:
	return abs(task_id) % 1000000
