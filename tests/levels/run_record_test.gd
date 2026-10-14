extends GdUnitTestSuite
## Turdaki rekor çizgisi (M3-14, architecture.md §9): rekor yüksekliğinde durur. HUD'un saydığı
## yükseklikle aynı hesap: oyuncu çizgiye vardığı adımda yükseklik tam rekordur. Rekor yokken ya
## da tur rekorun üstünden başlayınca çizgi görünmez. Main'in oturum rekorunu yeni tura vermesi
## main_test'te.

const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
const SECTORS: SectorCatalog = preload("res://data/sectors/sector_catalog.tres")
## İlk desen parçası 28,8 m ileride: oyuncu 10 m'lik rekora tehlikesiz varır.
const RECORD_M: int = 10
## 10 m, S1'de (12 m/sn) 50 adım; iniş ve pay dahil.
const MAX_FRAMES: int = 120

var _run: Run
var _start_y: float = 0.0
var _heights: Array[int] = []


func before_test() -> void:
	_heights.clear()
	Events.height_changed.connect(_on_height_changed)


func after_test() -> void:
	Events.height_changed.disconnect(_on_height_changed)
	_drop_run()


func test_line_is_reached_exactly_at_the_record_height() -> void:
	_start_run(RECORD_M, 1)
	var line: RecordLine = _line()
	assert_bool(line.visible).is_true()
	assert_float(line.position.y).is_equal_approx(_start_y - TuningConfig.to_px(RECORD_M), 0.001)
	var frames: int = 0
	while not line.is_passed() and frames < MAX_FRAMES:
		var last: int = 0 if _heights.is_empty() else _heights[_heights.size() - 1]
		assert_int(last).override_failure_message(
				"Rekora varılmadan yükseklik %d m" % last).is_less(RECORD_M)
		await get_tree().physics_frame
		frames += 1
	assert_bool(line.is_passed()).is_true()
	assert_int(_heights[_heights.size() - 1]).is_equal(RECORD_M)


func test_no_line_without_a_record() -> void:
	_start_run(0, 1)
	await _frames(10)
	assert_bool(_line().visible).is_false()


func test_line_counts_from_the_start_sector() -> void:
	var start_height: float = SECTORS.start_height(2)
	# Rekor turun başladığı yüksekliğin altındaysa çizgi yok.
	_start_run(floori(start_height) - 5, 2)
	assert_bool(_line().visible).is_false()
	_drop_run()
	_start_run(floori(start_height) + RECORD_M, 2)
	var line: RecordLine = _line()
	assert_bool(line.visible).is_true()
	assert_float(line.position.y).is_equal_approx(_start_y - TuningConfig.to_px(
			floori(start_height) + RECORD_M - start_height), 0.001)


## Diskteki varsayılan ayarların taze bir kopyasıyla tur kurar (paylaşılan örnek değişmez).
func _start_run(record: int, sector: int) -> void:
	_run = RUN_SCENE.instantiate() as Run
	_run.tuning = ResourceLoader.load(
			TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
	_run.run_seed = 12345
	_run.start_sector = sector
	_run.record_height = record
	_start_y = (_run.get_node("Player") as Player).position.y
	add_child(_run)


func _drop_run() -> void:
	if is_instance_valid(_run):
		remove_child(_run)
		_run.free()


func _line() -> RecordLine:
	return _run.get_node("%RecordLine") as RecordLine


func _on_height_changed(meters: int) -> void:
	_heights.append(meters)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
