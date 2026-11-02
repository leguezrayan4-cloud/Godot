extends Node
## Store global des tâches (autoload « TaskStore ») : CRUD, filtres, tri et persistance.

signal tasks_changed
signal task_added(task: TaskData)
signal task_updated(task: TaskData)
signal task_removed(id: int)

const SAVE_PATH := "user://tasks.json"

## Liste de toutes les tâches.
var tasks: Array[TaskData] = []

var _next_id: int = 1


func _ready() -> void:
	load_tasks()


## Ajoute une tâche et renvoie l'objet créé. `options` accepte icon, icon_color,
## category, description, reminder_enabled, reminder_unix, recurrence, subtasks.
func add_task(title: String, options: Dictionary = {}) -> TaskData:
	var t := TaskData.new()
	t.id = _next_id
	_next_id += 1
	t.title = title.strip_edges()
	t.created_unix = Time.get_unix_time_from_system()
	t.category = str(options.get("category", "Général"))
	t.icon = str(options.get("icon", TaskIcons.from_category(t.category)))
	t.icon_color = options.get("icon_color", TaskIcons.color(t.icon))
	t.icon_image = str(options.get("icon_image", ""))
	t.description = str(options.get("description", ""))
	t.reminder_enabled = bool(options.get("reminder_enabled", false))
	t.reminder_unix = float(options.get("reminder_unix", 0.0))
	t.recurrence = str(options.get("recurrence", "none"))
	t.subtasks = _normalize_subtasks(options.get("subtasks", []))
	tasks.append(t)
	task_added.emit(t)
	tasks_changed.emit()
	save_tasks()
	return t


## Crée une copie indépendante d'une tâche (rappel passé reporté à +1 h).
func duplicate_task(task: TaskData) -> TaskData:
	var reminder := task.reminder_unix
	if task.reminder_enabled and reminder <= Time.get_unix_time_from_system():
		reminder = Time.get_unix_time_from_system() + 3600.0
	return add_task(task.title, {
		"icon": task.icon,
		"icon_color": task.icon_color,
		"icon_image": task.icon_image,
		"category": task.category,
		"description": task.description,
		"reminder_enabled": task.reminder_enabled,
		"reminder_unix": reminder,
		"recurrence": task.recurrence,
		"subtasks": _copy_subtasks(task.subtasks),
	})


## Signale qu'une tâche existante a été modifiée.
func update_task(task: TaskData) -> void:
	task_updated.emit(task)
	tasks_changed.emit()
	save_tasks()


## Supprime la tâche d'identifiant `id`.
func remove_task(id: int) -> void:
	for i in range(tasks.size()):
		if tasks[i].id == id:
			tasks.remove_at(i)
			task_removed.emit(id)
			tasks_changed.emit()
			save_tasks()
			return


## Récupère une tâche par identifiant (null si absente).
func get_task(id: int) -> TaskData:
	for t in tasks:
		if t.id == id:
			return t
	return null


## Change l'état terminé. Les tâches récurrentes sont automatiquement reportées.
func set_done(id: int, done: bool) -> void:
	var t := get_task(id)
	if t == null:
		return
	if done and t.recurrence != "none":
		t.reminder_unix = _next_occurrence(t)
		t.done = false
	else:
		t.done = done
	task_updated.emit(t)
	tasks_changed.emit()
	save_tasks()


func _next_occurrence(t: TaskData) -> float:
	var base: float = t.reminder_unix if t.has_reminder() else Time.get_unix_time_from_system()
	match t.recurrence:
		"daily":
			return base + 86400.0
		"weekly":
			return base + 604800.0
		"monthly":
			return base + 2592000.0
		_:
			return base


func count_total() -> int:
	return tasks.size()


func count_active() -> int:
	var n: int = 0
	for t in tasks:
		if not t.done:
			n += 1
	return n


func count_done() -> int:
	var n: int = 0
	for t in tasks:
		if t.done:
			n += 1
	return n


## Renvoie les tâches filtrées et triées.
## status: "all" | "active" | "done" ; category: "" = toutes ;
## sort: "due" | "created" | "title" | "category".
func query(status: String = "all", category: String = "", sort: String = "due") -> Array[TaskData]:
	var out: Array[TaskData] = []
	for t in tasks:
		if status == "active" and t.done:
			continue
		if status == "done" and not t.done:
			continue
		if category != "" and t.category != category:
			continue
		out.append(t)
	match sort:
		"title":
			out.sort_custom(func(a: TaskData, b: TaskData) -> bool: return a.title.naturalnocasecmp_to(b.title) < 0)
		"created":
			out.sort_custom(func(a: TaskData, b: TaskData) -> bool: return a.created_unix > b.created_unix)
		"category":
			out.sort_custom(func(a: TaskData, b: TaskData) -> bool:
				if a.category == b.category:
					return _sort_by_due(a, b)
				return a.category.naturalnocasecmp_to(b.category) < 0)
		_:
			out.sort_custom(_sort_by_due)
	return out


func _sort_by_due(a: TaskData, b: TaskData) -> bool:
	var a_has: bool = a.has_reminder()
	var b_has: bool = b.has_reminder()
	if a_has != b_has:
		return a_has  # tâches avec rappel en premier
	if a_has and a.reminder_unix != b.reminder_unix:
		return a.reminder_unix < b.reminder_unix
	return a.created_unix > b.created_unix


## Catégories réellement utilisées, triées.
func used_categories() -> PackedStringArray:
	var category_set := {}
	for t in tasks:
		if t.category != "":
			category_set[t.category] = true
	var out := PackedStringArray(category_set.keys())
	out.sort()
	return out


func clear_all() -> void:
	tasks.clear()
	tasks_changed.emit()
	save_tasks()


static func _normalize_subtasks(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for entry in value:
		if typeof(entry) == TYPE_DICTIONARY:
			var title: String = str(entry.get("title", "")).strip_edges()
			if not title.is_empty():
				out.append({"title": title, "done": bool(entry.get("done", false))})
	return out


static func _copy_subtasks(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for entry in value:
		if typeof(entry) == TYPE_DICTIONARY:
			out.append({"title": str(entry.get("title", "")), "done": bool(entry.get("done", false))})
	return out


func save_tasks() -> void:
	var data := {"next_id": _next_id, "tasks": []}
	for t in tasks:
		data.tasks.append(t.to_dict())
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func load_tasks() -> void:
	tasks.clear()
	_next_id = 1
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_next_id = int(parsed.get("next_id", 1))
	for entry in parsed.get("tasks", []):
		tasks.append(TaskData.from_dict(entry))