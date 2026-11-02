class_name TaskData
extends Resource
## Modèle de données d'une tâche.

var id: int = 0
var title: String = ""
var description: String = ""
var done: bool = false
var category: String = "Général"
var icon: String = "personal"
var icon_color: Color = Color(0.42, 0.36, 0.91)
## Chemin d'une image importée pour l'icône (prioritaire sur `icon` si non vide).
var icon_image: String = ""
var reminder_enabled: bool = false
var reminder_unix: float = 0.0
## Vrai une fois l'alarme déclenchée (réarmé à chaque modification du rappel).
var reminder_fired: bool = false
var recurrence: String = "none"
var created_unix: float = 0.0
## Sous-tâches : tableau de dictionnaires {"title": String, "done": bool}.
var subtasks: Array = []


## Vrai si la tâche possède un rappel actif.
func has_reminder() -> bool:
	return reminder_enabled and reminder_unix > 0.0


## Vrai si le rappel est dépassé et la tâche non terminée.
func is_overdue() -> bool:
	return has_reminder() and not done and reminder_unix < Time.get_unix_time_from_system()


## Rappel formaté pour l'affichage (« Aujourd'hui 09:00 » ou « 12/05 09:00 »).
func reminder_text() -> String:
	if not has_reminder():
		return ""
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(int(reminder_unix))
	var today: Dictionary = Time.get_date_dict_from_system()
	if dt.year == today.year and dt.month == today.month and dt.day == today.day:
		return "Aujourd'hui %02d:%02d" % [dt.hour, dt.minute]
	return "%02d/%02d %02d:%02d" % [dt.day, dt.month, dt.hour, dt.minute]


## Libellé lisible de la récurrence (vide si aucune).
func recurrence_label() -> String:
	match recurrence:
		"daily":
			return "Quotidienne"
		"weekly":
			return "Hebdomadaire"
		"monthly":
			return "Mensuelle"
		_:
			return ""


# --- Sous-tâches -------------------------------------------------------------

func subtasks_count() -> int:
	return subtasks.size()


func subtasks_done_count() -> int:
	var n: int = 0
	for entry in subtasks:
		if typeof(entry) == TYPE_DICTIONARY and bool(entry.get("done", false)):
			n += 1
	return n


func subtask_at(index: int) -> Dictionary:
	if index < 0 or index >= subtasks.size():
		return {}
	var entry: Variant = subtasks[index]
	return entry if typeof(entry) == TYPE_DICTIONARY else {}


func toggle_subtask(index: int) -> void:
	var st: Dictionary = subtask_at(index)
	if st.is_empty():
		return
	st["done"] = not bool(st.get("done", false))
	subtasks[index] = st


func add_subtask(title: String) -> void:
	var clean: String = title.strip_edges()
	if clean.is_empty():
		return
	subtasks.append({"title": clean, "done": false})


func remove_subtask(index: int) -> void:
	if index >= 0 and index < subtasks.size():
		subtasks.remove_at(index)


## Sérialise la tâche en dictionnaire.
func to_dict() -> Dictionary:
	var subs: Array = []
	for entry in subtasks:
		if typeof(entry) == TYPE_DICTIONARY:
			subs.append({
				"title": str(entry.get("title", "")),
				"done": bool(entry.get("done", false)),
			})
	return {
		"id": id,
		"title": title,
		"description": description,
		"done": done,
		"category": category,
		"icon": icon,
		"icon_color": icon_color.to_html(),
		"icon_image": icon_image,
		"reminder_enabled": reminder_enabled,
		"reminder_unix": reminder_unix,
		"reminder_fired": reminder_fired,
		"recurrence": recurrence,
		"created_unix": created_unix,
		"subtasks": subs,
	}


## Reconstruit une tâche depuis un dictionnaire.
static func from_dict(d: Dictionary) -> TaskData:
	var t := TaskData.new()
	t.id = int(d.get("id", 0))
	t.title = str(d.get("title", ""))
	t.description = str(d.get("description", ""))
	t.done = bool(d.get("done", false))
	t.category = str(d.get("category", "Général"))
	t.icon = str(d.get("icon", "personal"))
	t.icon_color = Color(str(d.get("icon_color", "6c5ce7")))
	t.icon_image = str(d.get("icon_image", ""))
	t.reminder_enabled = bool(d.get("reminder_enabled", false))
	t.reminder_unix = float(d.get("reminder_unix", 0.0))
	t.reminder_fired = bool(d.get("reminder_fired", false))
	t.recurrence = str(d.get("recurrence", "none"))
	t.created_unix = float(d.get("created_unix", 0.0))
	t.subtasks = []
	var raw: Variant = d.get("subtasks", [])
	if typeof(raw) == TYPE_ARRAY:
		for entry in raw:
			if typeof(entry) == TYPE_DICTIONARY:
				var title: String = str(entry.get("title", "")).strip_edges()
				if not title.is_empty():
					t.subtasks.append({"title": title, "done": bool(entry.get("done", false))})
	return t


## Copie indépendante de la tâche.
func clone() -> TaskData:
	return TaskData.from_dict(to_dict())