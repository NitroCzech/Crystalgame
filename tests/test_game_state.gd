extends SceneTree
## Headless logic tests. Run with:
##   godot --headless --path . -s tests/test_game_state.gd

const GameState := preload("res://scripts/game_state.gd")
const SAVE_PATH := "user://test_save.json"

var _failures := 0
var _checks := 0


func _init() -> void:
	test_tapping()
	test_buying_generators()
	test_tap_upgrade()
	test_save_round_trip()
	test_offline_income()
	test_offline_income_is_capped()
	test_corrupt_save()
	test_formatting()
	test_buying_and_opening_geodes()
	test_rarity_odds()
	test_crystal_bonus()
	test_geodes_saved()
	_cleanup()
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _new_game() -> Node:
	var game: Node = GameState.new()
	game.save_path = SAVE_PATH
	game.reset()
	return game


func _cleanup() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)


func test_tapping() -> void:
	var g := _new_game()
	g.rng.seed = 1
	check(g.tap() == 1.0, "first tap is worth 1")
	g.tap()
	check(g.shards == 2.0, "two taps give 2 shards")
	g.free()


func test_buying_generators() -> void:
	var g := _new_game()
	check(not g.buy_generator("miner"), "can't buy without shards")
	g.shards = 100.0
	check(g.buy_generator("miner"), "can buy miner with 100 shards")
	check(g.shards == 85.0, "miner costs 15")
	check(g.owned.miner == 1, "own one miner")
	check(g.get_generator_cost("miner") == 18.0, "second miner costs ceil(15*1.15)=18")
	check(is_equal_approx(g.get_shards_per_second(), 0.1), "one miner makes 0.1/s")
	check(not g.buy_generator("nope"), "unknown generator is rejected")
	g.free()


func test_tap_upgrade() -> void:
	var g := _new_game()
	g.shards = 50.0
	check(g.buy_tap_upgrade(), "can buy tap upgrade for 50")
	check(g.tap() == 2.0, "tap doubles after upgrade")
	check(g.get_tap_upgrade_cost() == 300.0, "next tap upgrade costs 300")
	g.free()


func test_save_round_trip() -> void:
	var g := _new_game()
	g.shards = 1234.5
	g.tap_level = 2
	g.owned.drill = 3
	check(g.save_game(), "save succeeds")
	var g2 := _new_game()
	check(g2.load_game(), "load succeeds")
	check(is_equal_approx(g2.shards, 1234.5), "shards restored (got %s)" % g2.shards)
	check(g2.tap_level == 2, "tap level restored")
	check(g2.owned.drill == 3, "generators restored")
	check(g2.take_offline_report().amount == 0.0, "no offline income for an instant reload")
	g.free()
	g2.free()


func _write_save_from(g: Node, seconds_ago: float) -> void:
	var data: Dictionary = g.to_dict()
	data.saved_at = Time.get_unix_time_from_system() - seconds_ago
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func test_offline_income() -> void:
	var g := _new_game()
	g.owned.drill = 2 # 2 shards/sec
	_write_save_from(g, 3600.0)
	var g2 := _new_game()
	g2.load_game()
	var report: Dictionary = g2.take_offline_report()
	check(absf(report.amount - 7200.0) < 5.0, "1h at 2/s earns ~7200 (got %s)" % report.amount)
	check(absf(g2.shards - 7200.0) < 5.0, "offline income is added to shards")
	check(g2.take_offline_report().amount == 0.0, "report is only handed out once")
	g.free()
	g2.free()


func test_offline_income_is_capped() -> void:
	var g := _new_game()
	g.owned.miner = 10 # 1 shard/sec
	_write_save_from(g, 100.0 * 3600.0)
	var g2 := _new_game()
	g2.load_game()
	check(is_equal_approx(g2.shards, GameState.MAX_OFFLINE_SECONDS), "offline capped at 8h (got %s)" % g2.shards)
	g.free()
	g2.free()


func test_corrupt_save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var g := _new_game()
	check(not g.load_game(), "corrupt save is rejected")
	check(g.shards == 0.0, "corrupt save leaves a fresh game")
	g.free()


func test_formatting() -> void:
	check(GameState.format_number(0) == "0", "format 0")
	check(GameState.format_number(0.1) == "0.1", "format 0.1")
	check(GameState.format_number(999) == "999", "format 999")
	check(GameState.format_number(1500) == "1.50K", "format 1.5K")
	check(GameState.format_number(2_000_000) == "2.00M", "format 2M")
	check(GameState.format_number(999_999.999) == "1.00M", "rounds up to next suffix")
	check(GameState.format_duration(3725) == "1h 2m", "format duration")


func test_buying_and_opening_geodes() -> void:
	var g := _new_game()
	check(g.open_geode().is_empty(), "can't open a geode you don't have")
	g.shards = 150.0
	check(g.buy_geode(), "can buy a geode for 150")
	check(g.shards == 0.0 and g.geodes == 1, "geode bought")
	check(g.get_geode_cost() == 177.0, "next geode costs ceil(150*1.18)=177")
	var found: Dictionary = g.open_geode()
	check(not found.is_empty(), "opening a geode finds a crystal")
	check(g.geodes == 0 and g.geodes_opened == 1, "geode used up")
	check(g.crystals[found.id] == 1, "crystal added to collection")
	g.free()


func test_rarity_odds() -> void:
	var g := _new_game()
	check(g.roll_rarity(0.0).id == "common", "lowest roll is common")
	check(g.roll_rarity(0.5499).id == "common", "55% common")
	check(g.roll_rarity(0.55).id == "uncommon", "then uncommon")
	check(g.roll_rarity(0.9999).id == "celestial", "top roll is celestial")
	check(g.roll_rarity(0.9994).id == "mythic", "just below celestial is mythic")
	var total := 0
	for r in GameState.RARITIES:
		total += r.weight
	check(total == 10000, "rarity weights add up to 10000")
	g.rng.seed = 42
	var counts := {}
	for i in 20000:
		g.geodes = 1
		var id: String = g.open_geode().id
		counts[id] = counts.get(id, 0) + 1
	check(absf(counts.common / 20000.0 - 0.55) < 0.02, "common rate near 55%% (got %s)" % counts.common)
	check(counts.get("legendary", 0) > 0, "legendaries show up over 20000 opens")
	g.free()


func test_crystal_bonus() -> void:
	var g := _new_game()
	g.owned.drill = 10 # 10/s
	g.crystals.common = 5 # +5%
	g.crystals.legendary = 1 # +50%
	check(is_equal_approx(g.get_production_multiplier(), 1.55), "bonuses add up")
	check(is_equal_approx(g.get_shards_per_second(), 15.5), "bonus boosts generators")
	check(is_equal_approx(g.get_tap_value(), 1.55), "bonus boosts taps")
	g.free()


func test_geodes_saved() -> void:
	var g := _new_game()
	g.geodes = 4
	g.geodes_bought = 7
	g.crystals.epic = 2
	g.save_game()
	var g2 := _new_game()
	g2.load_game()
	check(g2.geodes == 4 and g2.geodes_bought == 7, "geodes restored")
	check(g2.crystals.epic == 2, "collection restored")
	g.free()
	g2.free()
