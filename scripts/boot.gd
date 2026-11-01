class_name Boot
extends Control
## Point d'entrée : splash de chargement, puis connexion ou vue principale selon
## la session restaurée automatiquement.

@onready var splash: Splash = %Splash
@onready var login: LoginScreen = %Login
@onready var main_shell: Main = %MainShell


func _ready() -> void:
	main_shell.visible = false
	login.visible = false
	splash.visible = true
	login.login_succeeded.connect(_on_login_succeeded)
	_boot()


func _boot() -> void:
	await splash.run()
	UiFx.fade_out(splash, 0.35)
	await get_tree().create_timer(0.35).timeout
	splash.visible = false
	if Auth.is_logged_in():
		_show_main()
	else:
		_show_login()


func _on_login_succeeded() -> void:
	UiFx.fade_out(login, 0.2)
	await get_tree().create_timer(0.2).timeout
	login.visible = false
	_show_main()


func _show_main() -> void:
	login.visible = false
	main_shell.visible = true
	UiFx.fade_in(main_shell, 0.35)


func _show_login() -> void:
	main_shell.visible = false
	login.visible = true
	login.reset()