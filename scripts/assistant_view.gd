class_name AssistantView
extends Control
## Assistant IA local : interprète des demandes en langage naturel et agit sur la
## liste des tâches (créer, terminer, supprimer, lister, compter).

@onready var chat_list: VBoxContainer = %ChatList
@onready var chat_scroll: ScrollContainer = %ChatScroll
@onready var chat_input: LineEdit = %ChatInput
@onready var suggest_row: HBoxContainer = %SuggestRow
@onready var activity_label: Label = %ActivityLabel

var _last_message: String = ""
var conversation_history := []

const SUGGESTIONS := [
	"Ajoute appeler le client",
	"Que me reste-t-il ?",
	"Combien de tâches ?",
]

const CATEGORY_KEYWORDS := {
	"médecin": "Santé", "sport": "Santé", "docteur": "Santé", "santé": "Santé",
	"réunion": "Travail", "boulot": "Travail", "travail": "Travail", "client": "Travail",
	"courses": "Courses", "acheter": "Courses", "supermarché": "Courses",
	"réviser": "Étude", "lire": "Étude", "cours": "Étude", "étude": "Étude",
	"jeu": "Loisirs", "film": "Loisirs", "loisir": "Loisirs",
}


func _ready() -> void:
	UiFx.attach_recursive(self)
	chat_input.text_submitted.connect(_on_submitted)
	%SendButton.pressed.connect(_on_send)
	KeyboardAvoid.register_pad($Margin, -1.0)
	_load_history()
	var mode_text := "Mode local — aucune donnée ne quitte l'appareil."
	if _ai_online():
		mode_text = "IA en ligne : %s." % AppSettings.ai_model
	var greet := "Bonjour ! Je peux créer, terminer ou supprimer des tâches pour vous.\nEssayez : « Ajoute appeler le client » ou « Que me reste-t-il ? ».\n%s" % mode_text
	_add_bubble(greet, false)
	conversation_history.append({"role": "assistant", "content": greet})
	_save_history()


func _process(_delta: float) -> void:
	KeyboardAvoid._compute_height()


func _build_suggestions() -> void:
	for text in SUGGESTIONS:
		var chip := Button.new()
		chip.text = text
		chip.focus_mode = Control.FOCUS_NONE
		chip.theme_type_variation = &"Chip"
		UiFx.attach(chip)
		var value: String = text
		chip.pressed.connect(func() -> void:
			chat_input.text = value
			_on_send())
		suggest_row.add_child(chip)


func _load_history() -> void:
	var hist_path := "user://assistant_history.json"
	var f := FileAccess.open(hist_path, FileAccess.READ)
	if f != null:
		var content := f.get_as_text()
		f.close()
		if content.length() > 0:
			var data: Array = JSON.parse_string(content)
			conversation_history = []
			for entry in data:
				conversation_history.append({"role": entry[0], "content": entry[1]})


func _save_history() -> void:
	var data := []
	for entry in conversation_history:
		data.append([entry.role, entry.content])
	var hist_path := "user://assistant_history.json"
	var f := FileAccess.open(hist_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()


func _on_submitted(_text: String) -> void:
	var message: String = _text.strip_edges()
	if message.is_empty():
		chat_input.grab_focus()
		return
	_add_bubble(message, true)
	chat_input.clear()
	chat_input.grab_focus()
	await _respond(message)


func _on_send() -> void:
	var message: String = chat_input.text.strip_edges()
	if message.is_empty():
		chat_input.grab_focus()
		return
	_add_bubble(message, true)
	conversation_history.append({"role": "user", "content": message})
	_save_history()
	chat_input.clear()
	chat_input.grab_focus()
	await _respond(message)


## Déroule la ligne d'activité en direct puis publie la réponse.
func _respond(message: String) -> void:
	_last_message = message
	for step in _steps_for(message):
		_show_activity(step)
		await _pause(0.34)
	var typing: Node = _add_bubble("…", false)
	var reply: String
	if _ai_online():
		reply = _reply_from_decision(await _ask_ai(message))
	else:
		await _pause(0.35)
		reply = _interpret(message)
	if is_instance_valid(typing):
		typing.queue_free()
	_hide_activity()
	_add_bubble(reply, false)


func _steps_for(message: String) -> Array[String]:
	var low: String = message.to_lower()
	var steps: Array[String] = ["Analyse de la demande…"]
	if low.contains("ajoute") or low.contains("ajouter") or low.contains("crée") or low.contains("créer") or low.contains("nouvelle"):
		steps.append("Création de la tâche…")
		steps.append("Enregistrement…")
	elif low.contains("supprime") or low.contains("efface") or low.contains("retire"):
		steps.append("Recherche de la tâche…")
		steps.append("Suppression…")
	elif low.contains("termine") or low.contains("coche"):
		steps.append("Recherche de la tâche…")
		steps.append("Mise à jour de l'état…")
	elif low.contains("rappel") or low.contains("rappelle"):
		steps.append("Mise à jour du rappel…")
	else:
		steps.append("Lecture de vos tâches…")
	return steps


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _show_activity(text: String) -> void:
	activity_label.text = text
	if not activity_label.visible:
		activity_label.visible = true
		UiFx.fade_in(activity_label, 0.15)


func _hide_activity() -> void:
	activity_label.visible = false


# --- Interprétation ----------------------------------------------------------

func _interpret(raw: String) -> String:
	var text: String = raw.strip_edges()
	var low: String = text.to_lower()

	if low.contains("combien") or low.contains("nombre"):
		return _reply_count()

	if low.contains("reste") or low.contains("liste") or low.contains("quelles") or low.contains("à faire") or low.contains("a faire"):
		return _reply_list()

	if low.contains("supprime") or low.contains("efface") or low.contains("retire"):
		var target: String = _strip_stopwords(_after(text, ["supprime", "supprimer", "efface", "effacer", "retire", "retirer"]))
		var task: TaskData = _find_task(target)
		if task == null:
			return "Je n'ai pas trouvé cette tâche. Précisez son nom."
		TaskStore.remove_task(task.id)
		return "Tâche « %s » supprimée." % task.title

	if low.contains("termine") or low.contains("terminé") or low.contains("coche") or low.contains("fait"):
		var target2: String = _strip_stopwords(_after(text, ["termine", "terminer", "terminé", "coche", "cocher", "fait", "finis", "fini"]))
		var task2: TaskData = _find_task(target2)
		if task2 == null:
			return "Je n'ai pas trouvé cette tâche à terminer."
		TaskStore.set_done(task2.id, true)
		return "Bravo, « %s » est terminée." % task2.title

	if low.contains("ajoute") or low.contains("ajouter") or low.contains("crée") or low.contains("créer") or low.contains("nouvelle tache") or low.contains("nouvelle tâche") or low.contains("rappelle"):
		var title: String = _strip_stopwords(_after(text, ["ajoute", "ajouter", "crée", "créer", "nouvelle tache", "nouvelle tâche", "rappelle", "rappeler"]))
		if title.is_empty():
			return "Quel est le titre de la tâche à ajouter ?"
		var category: String = _detect_category(low)
		TaskStore.add_task(title, {"category": category})
		return "C'est noté : « %s » (%s) a été ajoutée." % [title, category]

	return "Je n'ai pas bien compris. Essayez : « Ajoute <tâche> », « Termine <tâche> », « Supprime <tâche> » ou « Que me reste-t-il ? »."


# --- Assistant IA en ligne (OpenAI-compatible) ------------------------------

func _ai_online() -> bool:
	return AppSettings.ai_provider == "http" and not AppSettings.ai_api_key.is_empty()


func _ask_ai(message: String) -> Dictionary:
	var provider := AiProvider.new()
	add_child(provider)
	var result: Dictionary = await provider.ask(message, TaskStore.tasks)
	provider.queue_free()
	return result


func _reply_from_decision(decision: Dictionary) -> String:
	if not decision.get("ok", false):
		# Échec réseau/modèle : repli silencieux sur les règles locales.
		return _interpret(_last_message)
	return _execute_decision(decision)


func _execute_decision(decision: Dictionary) -> String:
	match decision.get("action", "chat"):
		"create":
			var title: String = str(decision.get("title", "")).strip_edges()
			if title.is_empty():
				return "Quel est le titre de la tâche à ajouter ?"
			var category: String = str(decision.get("category", "Personnel"))
			TaskStore.add_task(title, {"category": category})
			return "C'est noté : « %s » (%s) a été ajoutée." % [title, category]
		"complete":
			var task: TaskData = _find_task(str(decision.get("title", "")))
			if task == null:
				return "Je n'ai pas trouvé cette tâche à terminer."
			TaskStore.set_done(task.id, true)
			return "Bravo, « %s » est terminée." % task.title
		"delete":
			var target: TaskData = _find_task(str(decision.get("title", "")))
			if target == null:
				return "Je n'ai pas trouvé cette tâche à supprimer."
			TaskStore.remove_task(target.id)
			return "Tâche « %s » supprimée." % target.title
		"list":
			return _reply_list()
		"count":
			return _reply_count()
		_:
			var msg: String = str(decision.get("message", ""))
			return msg if not msg.is_empty() else "Je n'ai pas bien compris."


func _reply_count() -> String:
	return "Vous avez %d tâche(s) : %d à faire et %d terminée(s)." % [
		TaskStore.count_total(), TaskStore.count_active(), TaskStore.count_done()]


func _reply_list() -> String:
	var active: Array[TaskData] = TaskStore.query("active", "", "due")
	if active.is_empty():
		return "Tout est fait : aucune tâche en attente."
	var lines: PackedStringArray = PackedStringArray()
	for t in active:
		var suffix: String = " (%s)" % t.reminder_text() if t.has_reminder() else ""
		lines.append("• %s%s" % [t.title, suffix])
	return "Il vous reste %d tâche(s) :\n%s" % [active.size(), "\n".join(lines)]


func _after(text: String, keywords: Array) -> String:
	var low: String = text.to_lower()
	for kw in keywords:
		var idx: int = low.find(kw)
		if idx != -1:
			return text.substr(idx + String(kw).length()).strip_edges()
	return ""


func _strip_stopwords(value: String) -> String:
	var words: PackedStringArray = value.split(" ", false)
	var stop := ["de", "du", "des", "la", "le", "les", "une", "un", "à", "a", "pour", "tâche", "tache", "d'", "l'"]
	while words.size() > 0 and stop.has(words[0].to_lower()):
		words.remove_at(0)
	return " ".join(words).strip_edges()


func _detect_category(low: String) -> String:
	for key in CATEGORY_KEYWORDS:
		if low.contains(key):
			return CATEGORY_KEYWORDS[key]
	return "Personnel"


func _find_task(phrase: String) -> TaskData:
	if phrase.strip_edges().is_empty():
		return null
	var needle: String = phrase.to_lower()
	for t in TaskStore.tasks:
		if t.title.to_lower().contains(needle):
			return t
	var first_word: String = needle.split(" ", false)[0] if not needle.is_empty() else ""
	for t in TaskStore.tasks:
		if first_word != "" and t.title.to_lower().contains(first_word):
			return t
	return null


# --- Bulles de discussion ----------------------------------------------------

func _add_bubble(text: String, from_user: bool) -> Node:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_END if from_user else BoxContainer.ALIGNMENT_BEGIN

	var bubble := PanelContainer.new()
	bubble.custom_minimum_size = Vector2(190, 0)
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_END
	var sb := StyleBoxFlat.new()
	if from_user:
		sb.bg_color = Color(0.42, 0.36, 0.91, 1.0)
	else:
		sb.bg_color = Color(0.11, 0.122, 0.152, 1.0)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	bubble.add_theme_stylebox_override("panel", sb)

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.custom_minimum_size = Vector2(200, 0)
	label.add_theme_color_override("default_color", Color(1, 1, 1, 0.97) if from_user else Color(0.9, 0.91, 0.94, 1))
	label.text = text
	bubble.add_child(label)

	row.add_child(bubble)
	chat_list.add_child(row)
	UiFx.fade_in(row, 0.2)
	_scroll_to_bottom()
	return row


func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value)