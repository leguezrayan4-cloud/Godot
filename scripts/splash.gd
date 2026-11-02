class_name Splash
extends Control
## Écran de chargement : effectue réellement les initialisations (préférences,
## lecture du stockage local, tâches, session) et adapte sa durée à la charge.

@onready var logo: TextureRect = %Logo
@onready var title: Label = %SplashTitle
@onready var status_label: Label = %StatusLabel
@onready var bar: ProgressBar = %ProgressBar
@onready var center: CenterContainer = $Center


func _ready() -> void:
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)


func _apply_safe_area() -> void:
	var insets := ViewportUtil.safe_area_insets()
	center.offset_left = insets.z
	center.offset_top = insets.x
	center.offset_right = -insets.w
	center.offset_bottom = -insets.y


## Exécute la séquence de chargement ; à attendre (`await splash.run()`).
func run() -> void:
	_animate_intro()
	await get_tree().create_timer(0.4).timeout

	_step(12.0, "Chargement des préférences…")
	AppSettings.load_settings()
	await get_tree().create_timer(0.25).timeout

	_step(28.0, "Lecture du stockage local…")
	TaskStore.load_tasks()
	await get_tree().create_timer(0.2).timeout

	# Durée proportionnelle au nombre de tâches récupérées (bornée).
	var total: int = TaskStore.count_total()
	var steps: int = clampi(total, 1, 40)
	for i in range(steps):
		await get_tree().create_timer(0.022).timeout
		_step(28.0 + 46.0 * float(i + 1) / float(steps), "Récupération des tâches… (%d)" % total)

	_step(86.0, "Vérification de la session…")
	Auth.load_session()
	await get_tree().create_timer(0.28).timeout

	_step(100.0, "Prêt")
	await get_tree().create_timer(0.35).timeout


func _animate_intro() -> void:
	UiFx.fade_in(title, 0.5)
	UiFx.fade_in(status_label, 0.5)
	UiFx.fade_in(bar, 0.5)
	if is_instance_valid(logo):
		logo.pivot_offset = logo.size * 0.5
		logo.scale = Vector2(0.8, 0.8)
		logo.modulate.a = 0.0
		var tw: Tween = logo.create_tween()
		tw.set_parallel(true)
		tw.tween_property(logo, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(logo, "modulate:a", 1.0, 0.5)


func _step(value: float, text: String) -> void:
	status_label.text = text
	var tw: Tween = create_tween()
	tw.tween_property(bar, "value", value, 0.2).set_trans(Tween.TRANS_SINE)