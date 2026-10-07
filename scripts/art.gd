extends RefCounted
## Looks up picked art by slot name. Art lives at res://assets/art/<slot>.png
## (put there by tools/artgen); a slot with no file returns null so callers
## fall back to their procedural drawing.

const ART_DIR := "res://assets/art/"

static var _cache := {}


static func texture(slot: String) -> Texture2D:
	if slot.is_empty():
		return null
	if not _cache.has(slot):
		var path := ART_DIR + slot + ".png"
		_cache[slot] = load(path) if ResourceLoader.exists(path) else null
	return _cache[slot]
