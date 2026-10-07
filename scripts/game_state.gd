extends Node
## Global game state (autoloaded as `Game`).
##
## Owns the shard balance, generators, tap upgrades, saving/loading and
## offline income. UI reads from here and calls the buy/tap methods.

## Emitted when the game resumes after being suspended (e.g. app backgrounded)
## and passive income was awarded for the time away.
signal offline_income_awarded(amount: float, seconds: float)

const SAVE_VERSION := 1
const COST_GROWTH := 1.15
const MAX_OFFLINE_SECONDS := 8.0 * 3600.0
## Gaps shorter than this are not reported as offline income.
const MIN_OFFLINE_SECONDS := 10.0
## A frame-to-frame wall clock gap larger than this means we were suspended.
const SUSPEND_THRESHOLD := 5.0
const AUTOSAVE_INTERVAL := 10.0
const TAP_UPGRADE_BASE_COST := 50.0
const TAP_UPGRADE_GROWTH := 6.0

const GENERATORS := [
	{"id": "miner", "name": "Shard Miner", "base_cost": 15.0, "rate": 0.1},
	{"id": "drill", "name": "Crystal Drill", "base_cost": 100.0, "rate": 1.0},
	{"id": "geode", "name": "Geode Farm", "base_cost": 1100.0, "rate": 8.0},
	{"id": "forge", "name": "Prism Forge", "base_cost": 12000.0, "rate": 47.0},
	{"id": "refinery", "name": "Lunar Refinery", "base_cost": 130000.0, "rate": 260.0},
	{"id": "temple", "name": "Crystal Temple", "base_cost": 1400000.0, "rate": 1400.0},
]

const NUMBER_SUFFIXES := ["K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]

var save_path := "user://save.json"

var shards := 0.0
var lifetime_shards := 0.0
var tap_level := 0
## Generator id -> number owned.
var owned: Dictionary = {}

var _autosave_timer := 0.0
var _last_tick_time := 0.0
var _offline_report := {"amount": 0.0, "seconds": 0.0}


func _ready() -> void:
	reset()
	load_game()


func _process(delta: float) -> void:
	var now := Time.get_unix_time_from_system()
	var gap := now - _last_tick_time
	_last_tick_time = now
	if gap > SUSPEND_THRESHOLD:
		# The app was suspended; pay out the gap as offline income instead of
		# relying on `delta`, which isn't meaningful across a suspend.
		var seconds := minf(gap, MAX_OFFLINE_SECONDS)
		var earned := award_offline(gap)
		if earned > 0.0 and gap >= MIN_OFFLINE_SECONDS:
			offline_income_awarded.emit(earned, seconds)
	else:
		add_shards(get_shards_per_second() * delta)

	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, \
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_GO_BACK_REQUEST:
			save_game()


func reset() -> void:
	shards = 0.0
	lifetime_shards = 0.0
	tap_level = 0
	owned.clear()
	for def in GENERATORS:
		owned[def.id] = 0
	_offline_report = {"amount": 0.0, "seconds": 0.0}
	_last_tick_time = Time.get_unix_time_from_system()


# --- Economy -----------------------------------------------------------------

func add_shards(amount: float) -> void:
	if amount <= 0.0:
		return
	shards += amount
	lifetime_shards += amount


func tap() -> float:
	var value := get_tap_value()
	add_shards(value)
	return value


func get_tap_value() -> float:
	return pow(2.0, tap_level)


func get_tap_upgrade_cost() -> float:
	return ceilf(TAP_UPGRADE_BASE_COST * pow(TAP_UPGRADE_GROWTH, tap_level))


func buy_tap_upgrade() -> bool:
	var cost := get_tap_upgrade_cost()
	if shards < cost:
		return false
	shards -= cost
	tap_level += 1
	return true


func get_generator(id: String) -> Dictionary:
	for def in GENERATORS:
		if def.id == id:
			return def
	return {}


func get_generator_cost(id: String) -> float:
	var def := get_generator(id)
	return ceilf(def.base_cost * pow(COST_GROWTH, owned.get(id, 0)))


func buy_generator(id: String) -> bool:
	if get_generator(id).is_empty():
		return false
	var cost := get_generator_cost(id)
	if shards < cost:
		return false
	shards -= cost
	owned[id] = owned.get(id, 0) + 1
	return true


func get_shards_per_second() -> float:
	var total := 0.0
	for def in GENERATORS:
		total += def.rate * owned.get(def.id, 0)
	return total


## Adds income for `seconds` spent away (capped) and returns the amount.
func award_offline(seconds: float) -> float:
	var capped := clampf(seconds, 0.0, MAX_OFFLINE_SECONDS)
	var earned := get_shards_per_second() * capped
	add_shards(earned)
	return earned


## Returns the offline income awarded when the save was loaded, then clears it.
func take_offline_report() -> Dictionary:
	var report := _offline_report
	_offline_report = {"amount": 0.0, "seconds": 0.0}
	return report


# --- Persistence -------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"shards": shards,
		"lifetime_shards": lifetime_shards,
		"tap_level": tap_level,
		"owned": owned.duplicate(),
		"saved_at": Time.get_unix_time_from_system(),
	}


func apply_dict(data: Dictionary) -> void:
	reset()
	shards = maxf(0.0, float(data.get("shards", 0.0)))
	lifetime_shards = maxf(shards, float(data.get("lifetime_shards", shards)))
	tap_level = maxi(0, int(data.get("tap_level", 0)))
	var saved_owned = data.get("owned", {})
	if saved_owned is Dictionary:
		for def in GENERATORS:
			owned[def.id] = maxi(0, int(saved_owned.get(def.id, 0)))


func save_game() -> bool:
	# Write to a temp file first so a crash mid-write can't corrupt the save.
	var tmp_path := save_path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(to_dict()))
	file.close()
	var err := DirAccess.rename_absolute(
			ProjectSettings.globalize_path(tmp_path), ProjectSettings.globalize_path(save_path))
	if err != OK:
		push_warning("Could not finalize save: %s" % error_string(err))
		return false
	return true


func load_game() -> bool:
	var now := Time.get_unix_time_from_system()
	_last_tick_time = now
	if not FileAccess.file_exists(save_path):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary:
		push_warning("Save file is unreadable; starting fresh.")
		return false
	apply_dict(data)
	var gap := now - float(data.get("saved_at", now))
	if gap >= MIN_OFFLINE_SECONDS:
		var earned := award_offline(gap)
		if earned > 0.0:
			_offline_report = {"amount": earned, "seconds": minf(gap, MAX_OFFLINE_SECONDS)}
	return true


func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	reset()


# --- Formatting --------------------------------------------------------------

static func format_number(value: float) -> String:
	if value < 1000.0:
		if value < 100.0 and not is_equal_approx(value, floorf(value)):
			return "%.1f" % (floorf(value * 10.0) / 10.0)
		return str(int(floorf(value)))
	var tier := mini(int(floorf(log(value) / log(1000.0))), NUMBER_SUFFIXES.size())
	var scaled := value / pow(1000.0, tier)
	if scaled >= 999.995 and tier < NUMBER_SUFFIXES.size():
		tier += 1
		scaled /= 1000.0
	return "%.2f%s" % [scaled, NUMBER_SUFFIXES[tier - 1]]


static func format_duration(seconds: float) -> String:
	var total := int(seconds)
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	if minutes > 0:
		return "%dm %ds" % [minutes, total % 60]
	return "%ds" % total
