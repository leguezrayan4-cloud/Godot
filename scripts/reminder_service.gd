extends Node
## Service de rappels (autoload « Reminder ») : surveille les échéances à la
## seconde, déclenche l'alarme in-app (signal « reminder_due ») et pousse une
## notification système quand le plugin Android est installé ou, sur desktop,
## quand la fenêtre n'a plus le focus.

signal reminder_due(task: TaskData)

const CHECK_INTERVAL := 1.0

var _timer: Timer
var _window_focused: bool = true
var _scheduled: Dictionary = {}  # task_id -> identifiant de notification


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = CHECK_INTERVAL
	_timer.autostart = true
	_timer.timeout.connect(_check)
	add_child(_timer)
	get_window().focus_entered.connect(func() -> void: _window_focused = true)
	get_window().focus_exited.connect(func() -> void: _window_focused = false)
	TaskStore.tasks_changed.connect(_reconcile)
	AppSettings.settings_changed.connect(_on_settings_changed)
	_reconcile()


func _check() -> void:
	var now: float = Time.get_unix_time_from_system()
	for task in TaskStore.tasks:
		if task.done or task.reminder_fired or not task.has_reminder():
			continue
		if task.reminder_unix <= now:
			task.reminder_fired = true
			TaskStore.update_task(task)
			_fire(task)


func _fire(task: TaskData) -> void:
	reminder_due.emit(task)
	if not AppSettings.notifications:
		return
	var nid := NotificationBridge.task_notification_id(task.id)
	var title := "MyTaskUp — rappel"
	var body := "%s · %s" % [task.title, task.reminder_text()]
	if NotificationBridge.system_available() or not _window_focused:
		NotificationBridge.notify(nid, title, body)


## Planifie une alarme système pour une tâche à venir (plugin Android) et
## réordonnance au changement de l'heure.
func schedule(task: TaskData) -> void:
	if not NotificationBridge.system_available():
		return
	_cancel_id(task.id)
	if task.done or not task.has_reminder():
		return
	var nid := NotificationBridge.task_notification_id(task.id)
	var body := "%s · %s" % [task.title, task.reminder_text()]
	if NotificationBridge.schedule(nid, "MyTaskUp — rappel", body, int(task.reminder_unix)):
		_scheduled[task.id] = nid


## Annule l'alarme système d'une tâche.
func cancel(task_id: int) -> void:
	_cancel_id(task_id)


## Réarme le rappel d'une tâche (après édition).
func rearm(task: TaskData) -> void:
	task.reminder_fired = false


## Aligne les alarmes système avec l'état réel des tâches (ajouts, edits,
## suppressions, coches, chargement au démarrage).
func _reconcile() -> void:
	if not NotificationBridge.system_available():
		return
	var now: float = Time.get_unix_time_from_system()
	var stale: Array[int] = []
	for key in _scheduled.keys():
		var t: TaskData = TaskStore.get_task(key)
		if t == null or t.done or not t.has_reminder() or t.reminder_unix <= now:
			stale.append(key)
	for key in stale:
		_cancel_id(key)
	for t in TaskStore.tasks:
		if not t.done and t.has_reminder() and t.reminder_unix > now and not _scheduled.has(t.id):
			schedule(t)


func _on_settings_changed() -> void:
	if AppSettings.notifications:
		_reconcile()
		return
	var all: Array[int] = []
	for key in _scheduled.keys():
		all.append(key)
	for key in all:
		_cancel_id(key)


func _cancel_id(task_id: int) -> void:
	if _scheduled.has(task_id):
		NotificationBridge.cancel(_scheduled[task_id])
		_scheduled.erase(task_id)