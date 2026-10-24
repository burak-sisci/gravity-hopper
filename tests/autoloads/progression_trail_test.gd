extends GdUnitTestSuite
## Kozmetik izler kalıcı ilerlemede (M4-08, GDD §11, architecture.md §11): satın alma cüzdanı
## düşürür ve kayda iner; sahip olunmayan iz kuşanılamaz; kuşanılan iz yeniden açılışta durur ve
## tur yüküyle gelir; başarım izleri satılmaz, koşul sağlanınca (toplam 500 kıl payı tur sonunda,
## Büyük Depo) bir kez açılır. Bozuk ya da bilinmeyen kayıt varsayılan ize düşer. Testler geçici
## kayıtla çalışır.

const TRAILS: TrailCatalog = preload("res://data/trails/trail_catalog.tres")
const GOLD: StringName = &"trail_gold"
const FROST: StringName = &"trail_frost"
const CLOSE_CALL: StringName = &"trail_close_call"
const GREAT_STORAGE: StringName = &"trail_great_storage"
const DEFAULT: StringName = &"trail_default"

var _unlocked: Array[StringName] = []
var _equipped: Array[StringName] = []


func before_test() -> void:
	Progression.reset()
	_unlocked.clear()
	_equipped.clear()
	Events.trail_unlocked.connect(_on_trail_unlocked)
	Events.trail_equipped.connect(_on_trail_equipped)


func after_test() -> void:
	Events.trail_unlocked.disconnect(_on_trail_unlocked)
	Events.trail_equipped.disconnect(_on_trail_equipped)
	Progression.reset()


func test_new_save_owns_and_wears_the_default_trail() -> void:
	assert_str(String(Progression.equipped_trail())).is_equal(String(DEFAULT))
	assert_bool(Progression.owns_trail(DEFAULT)).is_true()
	assert_bool(Progression.owns_trail(GOLD)).is_false()
	assert_object(Progression.loadout().trail).is_same(TRAILS.default_def())


func test_buying_a_trail_spends_and_saves() -> void:
	var cost: int = TRAILS.get_def(GOLD).cost
	Progression.add_glimmers(cost - 1)
	assert_bool(Progression.can_buy_trail(GOLD)).is_false()
	assert_bool(Progression.buy_trail(GOLD)).is_false()
	assert_bool(Progression.owns_trail(GOLD)).is_false()
	Progression.add_glimmers(1)
	assert_bool(Progression.buy_trail(GOLD)).is_true()
	assert_int(Progression.glimmers).is_equal(0)
	assert_bool(Progression.owns_trail(GOLD)).is_true()
	assert_array(_unlocked).is_equal([GOLD])
	# Satın almak kuşanmak değildir.
	assert_str(String(Progression.equipped_trail())).is_equal(String(DEFAULT))
	var saved: Dictionary = SaveManager.load_game()
	assert_int(saved["glimmers"]).is_equal(0)
	assert_array((saved["trails"] as Dictionary)["owned"]).contains([String(GOLD)])
	# İkinci kez alınmaz.
	Progression.add_glimmers(cost)
	assert_bool(Progression.buy_trail(GOLD)).is_false()
	assert_int(Progression.glimmers).is_equal(cost)


func test_achievement_and_default_trails_are_not_sold() -> void:
	Progression.add_glimmers(100000)
	for id: StringName in [CLOSE_CALL, GREAT_STORAGE, DEFAULT, &"trail_missing"]:
		assert_bool(Progression.can_buy_trail(id)).is_false()
		assert_bool(Progression.buy_trail(id)).is_false()
	assert_int(Progression.glimmers).is_equal(100000)
	assert_array(_unlocked).is_empty()


func test_equip_needs_ownership_and_survives_a_restart() -> void:
	assert_bool(Progression.equip_trail(GOLD)).is_false()
	assert_bool(Progression.equip_trail(CLOSE_CALL)).is_false()
	assert_bool(Progression.equip_trail(&"trail_missing")).is_false()
	assert_array(_equipped).is_empty()
	Progression.add_glimmers(TRAILS.get_def(GOLD).cost)
	Progression.buy_trail(GOLD)
	assert_bool(Progression.equip_trail(GOLD)).is_true()
	assert_array(_equipped).is_equal([GOLD])
	assert_str(String((SaveManager.load_game()["trails"] as Dictionary)["equipped"])) \
			.is_equal(String(GOLD))
	Progression.reload()
	assert_str(String(Progression.equipped_trail())).is_equal(String(GOLD))
	assert_object(Progression.loadout().trail).is_same(TRAILS.get_def(GOLD))
	assert_bool(Progression.equip_trail(DEFAULT)).is_true()
	assert_object(Progression.loadout().trail).is_same(TRAILS.default_def())


## Kayıtta bilinmeyen ya da sahip olunmayan kuşanılı iz varsayılan ize düşer.
func test_broken_equipped_trail_falls_back_to_the_default() -> void:
	for equipped: String in ["trail_missing", String(FROST)]:
		var data: Dictionary[String, Variant] = SaveManager.default_data()
		(data["trails"] as Dictionary)["equipped"] = equipped
		(data["trails"] as Dictionary)["owned"] = ["trail_default", "trail_missing"]
		SaveManager.save_game(data)
		Progression.reload()
		assert_str(String(Progression.equipped_trail())).is_equal(String(DEFAULT))
		assert_bool(Progression.owns_trail(&"trail_missing")).is_false()
		assert_object(Progression.loadout().trail).is_same(TRAILS.default_def())


func test_near_misses_unlock_the_close_call_trail_once() -> void:
	var goal: int = TRAILS.get_def(CLOSE_CALL).goal
	Progression.finish_run(_result(goal - 1))
	assert_bool(Progression.owns_trail(CLOSE_CALL)).is_false()
	assert_array(_unlocked).is_empty()
	Progression.finish_run(_result(1))
	assert_bool(Progression.owns_trail(CLOSE_CALL)).is_true()
	assert_array(_unlocked).is_equal([CLOSE_CALL])
	assert_array((SaveManager.load_game()["trails"] as Dictionary)["owned"]) \
			.contains([String(CLOSE_CALL)])
	Progression.finish_run(_result(3))
	assert_array(_unlocked).is_equal([CLOSE_CALL])
	assert_bool(Progression.equip_trail(CLOSE_CALL)).is_true()
	Progression.reload()
	assert_str(String(Progression.equipped_trail())).is_equal(String(CLOSE_CALL))


func test_great_storage_unlocks_its_trail() -> void:
	Progression.finish_run(_result(0))
	assert_bool(Progression.owns_trail(GREAT_STORAGE)).is_false()
	Progression.mark_great_storage_reached()
	assert_bool(Progression.owns_trail(GREAT_STORAGE)).is_true()
	assert_array(_unlocked).is_equal([GREAT_STORAGE])
	# Varış tur sırasındadır: dosya hemen yazılmaz, tur sonunda yazılır.
	assert_bool(SaveManager.load_game()["great_storage_reached"]).is_false()
	Progression.finish_run(_result(0))
	var saved: Dictionary = SaveManager.load_game()
	assert_bool(saved["great_storage_reached"]).is_true()
	assert_array((saved["trails"] as Dictionary)["owned"]).contains([String(GREAT_STORAGE)])
	Progression.mark_great_storage_reached()
	assert_array(_unlocked).is_equal([GREAT_STORAGE])


func test_granted_trail_is_owned_without_cost() -> void:
	Progression.grant_trail(GOLD)
	Progression.grant_trail(&"trail_missing")
	assert_bool(Progression.owns_trail(GOLD)).is_true()
	assert_int(Progression.glimmers).is_equal(0)
	assert_array(_unlocked).is_equal([GOLD])


func _result(near_misses: int) -> RunResult:
	var result: RunResult = RunResult.new()
	result.height_m = 10
	result.start_sector = 1
	result.sector_reached = 1
	result.near_misses = near_misses
	return result


func _on_trail_unlocked(id: StringName) -> void:
	_unlocked.append(id)


func _on_trail_equipped(id: StringName) -> void:
	_equipped.append(id)
