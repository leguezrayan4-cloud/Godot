class_name LoginScreen
extends Control
## Écran de connexion en trois étapes : identifiants, code de validation email,
## et attente OAuth Google.

signal login_succeeded

@onready var card: PanelContainer = %LoginCard
@onready var creds_page: VBoxContainer = %CredsPage
@onready var code_page: VBoxContainer = %CodePage
@onready var wait_page: VBoxContainer = %WaitPage
@onready var email_input: LineEdit = %EmailInput
@onready var password_input: LineEdit = %PasswordInput
@onready var creds_error: Label = %CredsError
@onready var google_button: Button = %GoogleButton
@onready var login_button: Button = %LoginButton
@onready var code_input: LineEdit = %CodeInput
@onready var code_error: Label = %CodeError
@onready var code_hint: Label = %CodeHint
@onready var code_validate_button: Button = %CodeValidateButton
@onready var resend_button: Button = %ResendButton
@onready var back_button: Button = %BackButton
@onready var wait_state: Label = %WaitState
@onready var wait_cancel_button: Button = %WaitCancelButton


func _ready() -> void:
	UiFx.attach_recursive(self)
	login_button.pressed.connect(_on_login)
	google_button.pressed.connect(_on_google)
	password_input.text_submitted.connect(func(_t: String) -> void: _on_login())
	email_input.text_submitted.connect(func(_t: String) -> void: password_input.grab_focus())
	code_validate_button.pressed.connect(_on_validate)
	code_input.text_submitted.connect(func(_t: String) -> void: _on_validate())
	resend_button.pressed.connect(_on_resend)
	back_button.pressed.connect(_show_creds)
	wait_cancel_button.pressed.connect(_show_creds)
	Auth.verification_sent.connect(_on_code_sent)
	GoogleAuth.flow_state.connect(_on_google_state)


## Réinitialise le formulaire (email pré-rempli avec le dernier compte connu).
func reset() -> void:
	email_input.text = Auth.last_email
	password_input.text = ""
	code_input.text = ""
	cred_error_clear()
	_show_page(creds_page)
	UiFx.fade_in(self, 0.3)
	if is_instance_valid(card):
		UiFx.pop_in(card, 0.4)


func cred_error_clear() -> void:
	creds_error.visible = false
	code_error.visible = false


func _show_page(page: Control) -> void:
	creds_page.visible = page == creds_page
	code_page.visible = page == code_page
	wait_page.visible = page == wait_page


func _show_creds() -> void:
	creds_error.visible = false
	_show_page(creds_page)


func _on_login() -> void:
	var result: Dictionary = Auth.begin_email_signin(email_input.text, password_input.text)
	if result.get("ok", false):
		code_input.text = ""
		code_error.visible = false
		_show_page(code_page)
		code_input.grab_focus()
	else:
		_show_error(creds_error, str(result.get("error", "Connexion impossible.")))


func _on_code_sent(_mail: String, code: String) -> void:
	code_hint.text = "Code envoyé (simulation d'email) : %s" % code
	code_hint.visible = true


func _on_validate() -> void:
	var result: Dictionary = Auth.verify_code(code_input.text)
	if result.get("ok", false):
		_succeed()
	else:
		_show_error(code_error, str(result.get("error", "Code invalide.")))


func _on_resend() -> void:
	Auth.resend_code()
	code_input.text = ""
	code_error.visible = false
	code_input.grab_focus()


func _on_google() -> void:
	wait_state.text = "Connexion à Google…"
	_show_page(wait_page)
	var result: Dictionary = await GoogleAuth.sign_in()
	if result.get("ok", false):
		Auth.complete_external({"email": result.get("email", ""), "name": result.get("name", "")})
		_succeed()
	else:
		_show_page(creds_page)
		_show_error(creds_error, str(result.get("error", "Échec de la connexion Google.")))


func _on_google_state(state: String) -> void:
	if wait_page.visible:
		wait_state.text = state


func _show_error(label: Label, message: String) -> void:
	label.text = message
	label.visible = true
	UiFx.fade_in(label, 0.2)


func _succeed() -> void:
	password_input.text = ""
	code_input.text = ""
	Auth.cancel_pending()
	login_succeeded.emit()