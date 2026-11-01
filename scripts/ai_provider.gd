class_name AiProvider
extends Node
## Client IA « OpenAI-compatible » (endpoint / clé / modèle configurables
## dans les Réglages). Interroge un modèle de chat et retourne une décision
## structurée que l'assistant exécute sur les tâches.
##
## Quand aucune clé n'est configurée, l'assistant reste en mode local
## (règles) — ce provider n'est alors jamais appelé.

const CATEGORIES := ["Travail", "Personnel", "Courses", "Santé", "Étude", "Loisirs"]
const ACTIONS := ["create", "complete", "delete", "list", "count", "chat"]

signal decided(result: Dictionary)

var _http: HTTPRequest
var _answered: bool = false


## Envoie la demande et retourne (await) un dictionnaire :
## {ok, action, title, category, message} ou {ok:false, error}.
func ask(user_text: String, tasks: Array[TaskData]) -> Dictionary:
	_answered = false

	_http = HTTPRequest.new()
	_http.timeout = 12.0
	add_child(_http)
	_http.request_completed.connect(func(res: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		if _answered:
			return
		_answered = true
		_emit(res, code, body))

	# Garde-fou : en cas de blocage réseau, la requête peut ne jamais se terminer.
	var timer := Timer.new()
	timer.wait_time = 13.0
	timer.one_shot = true
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(func() -> void:
		if _answered:
			return
		_answered = true
		decided.emit(_fallback("Délai dépassé")))

	var payload := {
		"model": AppSettings.ai_model,
		"messages": [
			{"role": "system", "content": _system_prompt(tasks)},
			{"role": "user", "content": user_text},
		],
		"temperature": 0.2,
		"max_tokens": 300,
	}
	var endpoint: String = AppSettings.ai_base_url.trim_suffix("/") + "/chat/completions"
	var err := _http.request(
		endpoint,
		["Authorization: Bearer " + AppSettings.ai_api_key, "Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(payload))
	if err != OK:
		timer.queue_free()
		_http.queue_free()
		return _fallback("Requête impossible")

	var outcome: Dictionary = await decided
	timer.queue_free()
	_http.queue_free()
	return outcome


func _emit(res: int, response_code: int, body: PackedByteArray) -> void:
	if res != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		decided.emit(_fallback("HTTP %d" % response_code))
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	var content := ""
	if typeof(parsed) == TYPE_DICTIONARY:
		var choices: Array = parsed.get("choices", [])
		if choices.size() > 0:
			content = str(choices[0].get("message", {}).get("content", ""))
	decided.emit(parse_decision(content))


static func _fallback(error: String) -> Dictionary:
	return {"ok": false, "error": error}


## Extrait la décision JSON du texte de réponse du modèle (tolère les
## fences markdown et le texte environnant). Statique pour les tests.
static func parse_decision(content: String) -> Dictionary:
	var text := content.strip_edges()
	var start := text.find("{")
	var end := text.rfind("}")
	if start == -1 or end <= start:
		return _fallback("Réponse sans JSON")
	var obj: Variant = JSON.parse_string(text.substr(start, end - start + 1))
	if typeof(obj) != TYPE_DICTIONARY:
		return _fallback("JSON invalide")

	var action := str(obj.get("action", "chat"))
	if not action in ACTIONS:
		action = "chat"
	var category := str(obj.get("category", "Personnel"))
	if not category in CATEGORIES:
		category = "Personnel"
	return {
		"ok": true,
		"action": action,
		"title": str(obj.get("title", "")).strip_edges(),
		"category": category,
		"message": str(obj.get("message", "")),
	}


static func _system_prompt(tasks: Array[TaskData]) -> String:
	var tasks_json := []
	for t in tasks:
		tasks_json.append({"title": t.title, "category": t.category, "done": t.done})
	return (
		"Tu es l'assistant de MyTaskUp, une application de gestion de tâches en français. "
		+ "Tu réponds UNIQUEMENT par un objet JSON, sans texte avant ni après, avec les champs : "
		+ "action (create | complete | delete | list | count | chat), "
		+ "title (titre de la tâche concernée, pour create/complete/delete), "
		+ "category (Travail, Personnel, Courses, Santé, Étude ou Loisirs, pour create), "
		+ "message (texte de réponse pour l'utilisateur, pour chat/list/count). "
		+ "Règles : « ajoute X » → create ; « termine/coche X » → complete ; "
		+ "« supprime X » → delete ; demande des tâches restantes → list ; "
		+ "demande un nombre → count ; tout le reste → chat. "
		+ "Tâches actuelles : " + JSON.stringify(tasks_json) + ".")
