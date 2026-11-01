extends Node
## Session utilisateur (autoload « Auth ») : connexion, restauration automatique
## et persistance locale du dernier compte.

signal session_changed
## Émis lorsqu'un code de validation doit être « envoyé » (email + code affiché).
signal verification_sent(mail: String, code: String)

const SAVE_PATH := "user://session.json"
const CODE_TTL := 300.0
const MAX_ATTEMPTS := 5

var logged_in: bool = false
var email: String = ""
var display_name: String = ""
var provider: String = ""
var token: String = ""
var signed_in_at: float = 0.0
## Dernier email connu, conservé même après déconnexion (pré-remplissage).
var last_email: String = ""

var _pending_email: String = ""
var _pending_code: String = ""
var _pending_expiry: float = 0.0
var _pending_attempts: int = 0


func _ready() -> void:
	load_session()


func is_logged_in() -> bool:
	return logged_in


func provider_label() -> String:
	match provider:
		"google":
			return "Connecté avec Google"
		"email":
			return "Connexion par email"
		_:
			return ""


## Étape 1 : valide le formulaire et « envoie » un code de validation.
## Renvoie {ok: bool, error: String}.
func begin_email_signin(mail: String, password: String) -> Dictionary:
	var normalized: String = mail.strip_edges()
	if not _valid_email(normalized):
		return {"ok": false, "error": "Adresse email invalide."}
	if password.length() < 6:
		return {"ok": false, "error": "Mot de passe : 6 caractères minimum."}
	_pending_email = normalized
	_pending_code = _generate_code()
	_pending_expiry = Time.get_unix_time_from_system() + CODE_TTL
	_pending_attempts = 0
	verification_sent.emit(_pending_email, _pending_code)
	return {"ok": true}


## Renvoie un nouveau code pour la demande en cours.
func resend_code() -> Dictionary:
	if _pending_email.is_empty():
		return {"ok": false, "error": "Aucune demande en cours."}
	_pending_code = _generate_code()
	_pending_expiry = Time.get_unix_time_from_system() + CODE_TTL
	_pending_attempts = 0
	verification_sent.emit(_pending_email, _pending_code)
	return {"ok": true}


## Étape 2 : vérifie le code et ouvre la session si correct.
func verify_code(code: String) -> Dictionary:
	if _pending_code.is_empty():
		return {"ok": false, "error": "Aucune demande en cours."}
	if Time.get_unix_time_from_system() > _pending_expiry:
		return {"ok": false, "error": "Code expiré, demandez-en un nouveau."}
	if _pending_attempts >= MAX_ATTEMPTS:
		return {"ok": false, "error": "Trop de tentatives, demandez un nouveau code."}
	if code.strip_edges() != _pending_code:
		_pending_attempts += 1
		return {"ok": false, "error": "Code incorrect (%d/%d)." % [_pending_attempts, MAX_ATTEMPTS]}
	_open_session(_pending_email, _pending_email.split("@")[0].capitalize(), "email")
	_clear_pending()
	return {"ok": true}


## Annule la demande de code en cours.
func cancel_pending() -> void:
	_clear_pending()


## Ouvre une session à partir d'un profil externe (Google OAuth).
func complete_external(profile: Dictionary) -> void:
	var mail: String = str(profile.get("email", "utilisateur@gmail.com"))
	if mail.is_empty():
		mail = "utilisateur@gmail.com"
	var display: String = str(profile.get("name", mail.split("@")[0].capitalize()))
	_open_session(mail, display, "google")


func _open_session(mail: String, display: String, prov: String) -> void:
	logged_in = true
	email = mail
	display_name = display
	provider = prov
	token = _random_token()
	signed_in_at = Time.get_unix_time_from_system()
	last_email = mail
	_commit()


func _clear_pending() -> void:
	_pending_email = ""
	_pending_code = ""
	_pending_expiry = 0.0
	_pending_attempts = 0


func _generate_code() -> String:
	return "%06d" % randi_range(0, 999999)


func _random_token() -> String:
	return Marshalls.raw_to_base64(Crypto.new().generate_random_bytes(24)).replace("+", "-").replace("/", "_").replace("=", "")


func sign_out() -> void:
	logged_in = false
	last_email = email
	email = ""
	display_name = ""
	provider = ""
	token = ""
	signed_in_at = 0.0
	_clear_pending()
	_commit()


func set_display_name(value: String) -> void:
	var cleaned: String = value.strip_edges()
	display_name = cleaned if not cleaned.is_empty() else email.split("@")[0]
	_commit()


func _valid_email(mail: String) -> bool:
	return mail.contains("@") and mail.contains(".") and mail.length() >= 5


func _commit() -> void:
	session_changed.emit()
	save_session()


func save_session() -> void:
	var data := {
		"logged_in": logged_in,
		"email": email,
		"display_name": display_name,
		"provider": provider,
		"token": token,
		"signed_in_at": signed_in_at,
		"last_email": last_email,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func load_session() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	logged_in = bool(parsed.get("logged_in", false))
	email = str(parsed.get("email", ""))
	display_name = str(parsed.get("display_name", ""))
	provider = str(parsed.get("provider", ""))
	token = str(parsed.get("token", ""))
	signed_in_at = float(parsed.get("signed_in_at", 0.0))
	last_email = str(parsed.get("last_email", email))
	# Cohérence : si "connecté" mais email vide, on invalide la session.
	if logged_in and email.is_empty():
		logged_in = false