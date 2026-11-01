class_name UiFx
extends RefCounted
## Petites animations d'interface réutilisables (retour au clic, fondus).


## Branche un effet « rebond » à l'appui/relâchement d'un bouton.
static func attach(button: BaseButton) -> void:
	if button.has_meta("ui_fx"):
		return
	button.set_meta("ui_fx", true)
	button.button_down.connect(func() -> void: _scale_to(button, Vector2(0.94, 0.94), 0.07))
	button.button_up.connect(func() -> void: _scale_to(button, Vector2.ONE, 0.20, Tween.TRANS_BACK))
	button.mouse_exited.connect(func() -> void: _scale_to(button, Vector2.ONE, 0.12))


## Branche l'effet sur tous les boutons d'un sous-arbre.
static func attach_recursive(root: Node) -> void:
	if root is BaseButton:
		attach(root as BaseButton)
	for child in root.get_children():
		attach_recursive(child)


static func _scale_to(control: Control, target: Vector2, dur: float, trans: int = Tween.TRANS_SINE) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	control.pivot_offset = control.size * 0.5
	var tw: Tween = control.create_tween()
	tw.tween_property(control, "scale", target, dur).set_trans(trans).set_ease(Tween.EASE_OUT)


## Fondu d'apparition.
static func fade_in(control: CanvasItem, dur: float = 0.25) -> void:
	if not is_instance_valid(control):
		return
	control.modulate.a = 0.0
	var tw: Tween = control.create_tween()
	tw.tween_property(control, "modulate:a", 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Fondu de disparition, terminé par un appel optionnel.
static func fade_out(control: CanvasItem, dur: float = 0.2, on_done: Callable = Callable()) -> void:
	if not is_instance_valid(control):
		if on_done.is_valid():
			on_done.call()
		return
	var tw: Tween = control.create_tween()
	tw.tween_property(control, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if on_done.is_valid():
		tw.tween_callback(on_done)


## Apparition avec léger agrandissement depuis une échelle réduite.
static func pop_in(control: Control, dur: float = 0.28) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2(0.92, 0.92)
	control.modulate.a = 0.0
	var tw: Tween = control.create_tween()
	tw.set_parallel(true)
	tw.tween_property(control, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(control, "modulate:a", 1.0, dur * 0.8).set_trans(Tween.TRANS_SINE)