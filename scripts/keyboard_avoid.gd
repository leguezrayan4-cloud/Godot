extends Node
## Autoload « KeyboardAvoid » : maintient les zones de saisie au-dessus du
## clavier virtuel. Combine trois signaux (API hauteur, redimensionnement de
## fenêtre, estimation au focus) et applique un padding bas aux contrôles
## enregistrés (MarginContainer via constante de thème, autre Control via
## offset_bottom). Compatible Godot 4.3 (estimation tactile en repli).

signal keyboard_changed(height: float)

const ESTIMATE_RATIO := 0.34
const RESIZE_THRESHOLD := 40.0

var _pads: Array[Dictionary] = []
var _baseline_h: float = -1.0
var _applied: float = -1.0


func _process(_delta: float) -> void:
	var height := _compute_height()
	if absf(height - _applied) < 0.5:
		return
	_applied = height
	for pad in _pads:
		_apply_pad(pad, height)
	keyboard_changed.emit(height)


## Enregistre un contrôle à remonter quand le clavier s'ouvre.
## base_bottom : marge basse de repos (zone sûre incluse si nécessaire).
func register_pad(control: Control, base_bottom: float = -1.0) -> void:
	for pad in _pads:
		if pad.control == control:
			return
	var base := base_bottom
	if base < 0.0:
		base = _read_base(control)
	_pads.append({"control": control, "base": base})
	_apply_pad({"control": control, "base": base}, _applied if _applied > 0.0 else 0.0)


func unregister_pad(control: Control) -> void:
	for i in range(_pads.size()):
		if _pads[i].control == control:
			_apply_pad(_pads[i], 0.0)
			_pads.remove_at(i)
			return


## Met à jour la marge de repos (après changement de zone sûre par exemple).
func set_base(control: Control, base_bottom: float) -> void:
	for pad in _pads:
		if pad.control == control:
			pad.base = base_bottom
			return


func _read_base(control: Control) -> float:
	if control is MarginContainer:
		return float(int(control.get_theme_constant("margin_bottom")))
	return control.offset_bottom


func _apply_pad(pad: Dictionary, kb: float) -> void:
	var control: Control = pad.control
	if not is_instance_valid(control):
		return
	var total := float(pad.base) + kb
	if control is MarginContainer:
		control.add_theme_constant_override("margin_bottom", int(total))
	else:
		control.offset_bottom = total


func _compute_height() -> float:
	var st := Engine.get_main_loop() as SceneTree
	if st == null or st.root == null:
		return 0.0
	var win := st.root
	var win_size: Vector2i = win.size
	if win_size.y <= 0:
		return 0.0
	var vp_size: Vector2 = win.get_viewport().get_visible_rect().size
	var current_h := float(win_size.y)
	if _baseline_h < 0.0:
		_baseline_h = current_h
	var shrink := _baseline_h - current_h
	if shrink < RESIZE_THRESHOLD:
		# Pas de redimensionnement : on prend la hauteur courante comme référence.
		_baseline_h = current_h
		shrink = 0.0
	if shrink > 0.0:
		# Mode « adjustResize » (fenêtre réduite par le système) : le contenu
		# s'adapte déjà tout seul, aucun padding nécessaire.
		return 0.0
	var api_px := ViewportUtil.keyboard_height_px()
	if api_px > 0:
		return minf(ViewportUtil.px_to_viewport_y(float(api_px)), vp_size.y * 0.7)
	if ViewportUtil.text_focused() and ViewportUtil.touchscreen():
		# Clavier virtuel sans API de hauteur (Godot 4.3) : estimation.
		return vp_size.y * ESTIMATE_RATIO
	return 0.0