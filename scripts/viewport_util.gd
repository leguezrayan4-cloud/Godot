class_name ViewportUtil
extends RefCounted
## Utilitaires d'adaptation d'écran : zone sûre (encoche / barre du bas) et
## conversion pixels fenêtres <-> unités viewport. Tous les appels d'API récents
## sont gardés par has_method pour rester compatible Godot 4.3.


## Zone sûre en unités viewport : (top, bottom, left, right).
static func safe_area_insets() -> Vector4:
	var out := Vector4.ZERO
	if not DisplayServer.has_method("get_display_safe_area"):
		return out
	var st := Engine.get_main_loop() as SceneTree
	if st == null or st.root == null:
		return out
	var win := st.root
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var win_pos: Vector2i = win.position
	var win_size: Vector2i = win.size
	if win_size.x <= 0 or win_size.y <= 0:
		return out
	var vp_size: Vector2 = win.get_viewport().get_visible_rect().size
	var sx := vp_size.x / float(win_size.x)
	var sy := vp_size.y / float(win_size.y)
	out.x = maxf(float(safe.position.y - win_pos.y) * sy, 0.0)
	out.y = maxf(float(win_pos.y + win_size.y - safe.end.y) * sy, 0.0)
	out.z = maxf(float(safe.position.x - win_pos.x) * sx, 0.0)
	out.w = maxf(float(win_pos.x + win_size.x - safe.end.x) * sx, 0.0)
	return out


## Convertit une hauteur en pixels écran vers des unités viewport.
static func px_to_viewport_y(px: float) -> float:
	var st := Engine.get_main_loop() as SceneTree
	if st == null or st.root == null:
		return px
	var win_size: Vector2i = st.root.size
	if win_size.y <= 0:
		return px
	var vp_size: Vector2 = st.root.get_viewport().get_visible_rect().size
	return px * (vp_size.y / float(win_size.y))


## Vrai si le clavier virtuel expose sa hauteur (Godot 4.4+ ; garde-fou 4.3).
static func keyboard_api_available() -> bool:
	return DisplayServer.has_method("virtual_keyboard_get_height") and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD)


## Hauteur du clavier en pixels écran (0 si inconnu).
static func keyboard_height_px() -> int:
	if not keyboard_api_available():
		return 0
	return DisplayServer.virtual_keyboard_get_height()


## Vrai si un champ de saisie de texte a actuellement le focus.
static func text_focused() -> bool:
	var st := Engine.get_main_loop() as SceneTree
	if st == null or st.root == null:
		return false
	var owner: Control = st.root.get_viewport().gui_get_focus_owner()
	return owner is LineEdit or owner is TextEdit or owner is SpinBox


## Vrai sur un appareil tactile (estimation de clavier uniquement dans ce cas).
static func touchscreen() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_TOUCHSCREEN)