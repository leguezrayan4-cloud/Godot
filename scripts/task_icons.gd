class_name TaskIcons
extends RefCounted
## Catalogue des icônes de tâches (pictogrammes PNG) et couleurs associées.

const DEFAULT_ID := "personal"

## Identifiants ordonnés des icônes disponibles.
const IDS: Array[String] = ["work", "personal", "shopping", "health", "study", "leisure"]

## Catégories proposées par défaut (nom -> icône).
const CATEGORIES: Array[String] = ["Travail", "Personnel", "Courses", "Santé", "Étude", "Loisirs"]


static func has_icon(id: String) -> bool:
	return IDS.has(id)


static func _path(id: String) -> String:
	match id:
		"work":
			return "res://assets/generated/icon_work.png"
		"shopping":
			return "res://assets/generated/icon_shopping.png"
		"health":
			return "res://assets/generated/icon_health.png"
		"study":
			return "res://assets/generated/icon_study.png"
		"leisure":
			return "res://assets/generated/icon_leisure.png"
		_:
			return "res://assets/generated/icon_personal.png"


static func texture(id: String) -> Texture2D:
	return load(_path(id)) as Texture2D


static func color(id: String) -> Color:
	match id:
		"work":
			return Color(0.36, 0.55, 0.98)
		"shopping":
			return Color(0.20, 0.72, 0.62)
		"health":
			return Color(0.94, 0.40, 0.47)
		"study":
			return Color(0.95, 0.66, 0.25)
		"leisure":
			return Color(0.56, 0.66, 0.96)
		_:
			return Color(0.55, 0.42, 0.94)


static func label(id: String) -> String:
	match id:
		"work":
			return "Travail"
		"shopping":
			return "Courses"
		"health":
			return "Santé"
		"study":
			return "Étude"
		"leisure":
			return "Loisirs"
		_:
			return "Personnel"


## Charge une texture depuis un chemin (res:// importé ou fichier utilisateur).
static func image_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if path.begins_with("res://"):
		return load(path) as Texture2D
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return ImageTexture.create_from_image(img)


## Identifiant d'icône associé par défaut à une catégorie.
static func from_category(category: String) -> String:
	match category:
		"Travail":
			return "work"
		"Courses":
			return "shopping"
		"Santé":
			return "health"
		"Étude":
			return "study"
		"Loisirs":
			return "leisure"
		_:
			return "personal"