extends GdUnitTestSuite
## Arka plan veri ağı (M3-07, architecture.md §9): dünyanın ardında, dokunuşu yutmaz; kaliteye
## göre katmanlar (düşükte düz renk); paralaks kayma ve satır sarılması; vuruşta nabız ve
## parlayan düğümler; sektör renkleri. Renk dalgası (M3-08): önün üstü eski, altı yeni renkte,
## ön alttan üste yürür; düşük kalitede düz renk ve çizgi.

const BACKGROUND_SCENE: PackedScene = preload("res://scenes/levels/background.tscn")
const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const SECTORS: SectorCatalog = preload("res://data/sectors/sector_catalog.tres")

var _stored_quality: GameTypes.Quality


func before_test() -> void:
	_stored_quality = Neon.quality


func after_test() -> void:
	Neon.set_quality(_stored_quality, get_tree())


func test_grid_is_behind_world_and_has_no_controls() -> void:
	var background: Background = _make()
	assert_int(background.layer).is_less(0)
	# Control olmadığı için dokunuşları yutamaz (oyuncunun çevirmesi hep çalışır).
	assert_array(background.find_children("*", "Control", true, false)).is_empty()


func test_quality_sets_layers_and_low_is_flat_color() -> void:
	var background: Background = _make()
	Neon.set_quality(GameTypes.Quality.HIGH, get_tree())
	assert_bool(_node(background, "%Grid").visible).is_true()
	assert_bool(_node(background, "%Far").visible).is_true()
	Neon.set_quality(GameTypes.Quality.MEDIUM, get_tree())
	assert_bool(_node(background, "%Grid").visible).is_true()
	assert_bool(_node(background, "%Far").visible).is_false()
	Neon.set_quality(GameTypes.Quality.LOW, get_tree())
	assert_bool(_node(background, "%Grid").visible).is_false()
	assert_bool(_node(background, "%Flash").visible).is_false()


func test_layers_scroll_down_slower_than_world_far_slowest() -> void:
	var style: NeonStyle = Neon.STYLE
	var climb: float = 100.0
	var near: float = _moved(climb, style.grid_near_parallax, style.grid_near_cell)
	var far: float = _moved(climb, style.grid_far_parallax, style.grid_far_cell)
	# Kamera yukarı çıkınca ağ dünyayla aynı yönde (aşağı), ondan yavaş kayar; uzak katman daha
	# da yavaş (derinlik).
	assert_float(near).is_equal_approx(climb * style.grid_near_parallax, 0.001)
	assert_float(far).is_equal_approx(climb * style.grid_far_parallax, 0.001)
	assert_float(near).is_less(climb)
	assert_float(far).is_less(near)


func test_row_wrap_keeps_the_pattern_in_place_on_long_runs() -> void:
	var style: NeonStyle = Neon.STYLE
	var cell: float = style.grid_near_cell
	var parallax: float = style.grid_near_parallax
	# 7500 m'lik tur dahil: kayma bir hücreden küçük kalır; satır sayacıyla birlikte desenin yeri
	# kameranın paralaks yoluyla aynıdır (sarılmada sıçrama yok).
	for camera_y: float in [0.0, -1234.5, -1000.0, -375010.0]:
		var offset: float = Background.layer_offset(camera_y, parallax, cell)
		var row: int = Background.layer_row(camera_y, parallax, cell)
		assert_float(offset).is_greater_equal(0.0)
		assert_float(offset).is_less(cell)
		assert_float(offset + row * cell).is_equal_approx(-camera_y * parallax, 0.001)


func test_reset_scroll_places_layers_at_once() -> void:
	var background: Background = _make()
	var style: NeonStyle = Neon.STYLE
	background.reset_scroll(-5000.0)
	assert_float(_node(background, "%Near").position.y).is_equal_approx(
			Background.layer_offset(-5000.0, style.grid_near_parallax, style.grid_near_cell), 0.001)
	assert_float(_node(background, "%Far").position.y).is_equal_approx(
			Background.layer_offset(-5000.0, style.grid_far_parallax, style.grid_far_cell), 0.001)
	assert_float(_node(background, "%Flash").position.y).is_equal(
			_node(background, "%Near").position.y)


func test_pulses_on_the_beat() -> void:
	var background: Background = _make()
	background.set_colors(Color(0.3, 0.85, 0.95), Color(0.8, 0.97, 1.0))
	background.set_beat(4.0)
	assert_float(_node(background, "%Grid").modulate.a).is_greater(1.0)
	assert_float(_node(background, "%Flash").modulate.a).is_equal(1.0)
	background.set_beat(4.5)
	assert_object(_node(background, "%Grid").modulate).is_equal(Color.WHITE)
	assert_float(_node(background, "%Flash").modulate.a).is_equal(0.0)


func test_other_nodes_flash_each_beat() -> void:
	var density: float = Neon.STYLE.grid_flash_density
	var first: Array[Vector2i] = Background.flash_nodes(4, 0, 5, 10, density)
	assert_array(first).is_equal(Background.flash_nodes(4, 0, 5, 10, density))
	assert_array(first).is_not_equal(Background.flash_nodes(5, 0, 5, 10, density))
	# Oran: 40 vuruşta 50 düğümün kabaca density kadarı parlar (seçim düzgün dağılıyor).
	var lit: int = 0
	for beat: int in 40:
		lit += Background.flash_nodes(beat, 0, 5, 10, density).size()
	assert_float(lit / (40.0 * 50.0)).is_between(density * 0.5, density * 1.5)
	# Katman bir satır kayınca desendeki aynı düğümler parlamayı sürdürür.
	var shifted: Array[Vector2i] = Background.flash_nodes(4, 1, 5, 9, density)
	for node: Vector2i in first:
		if node.y >= 1:
			assert_array(shifted).contains([node])


func test_run_paints_grid_in_sector_colors() -> void:
	var run: Run = auto_free(RUN_SCENE.instantiate()) as Run
	run.run_seed = 7
	add_child(run)
	var background: Background = run.get_node("%Background") as Background
	var palette: SectorPalette = SECTORS.def_at(1).palette
	assert_object(_node(background, "%Near").self_modulate).is_equal(palette.ambient)
	assert_object(_node(background, "%Far").self_modulate).is_equal(palette.ambient)


func test_wave_math_matches_banner_timing() -> void:
	var style: NeonStyle = Neon.STYLE
	assert_float(style.wave_progress(0.0)).is_equal(0.0)
	assert_float(style.wave_progress(style.wave_time * 0.5)).is_equal_approx(0.5, 0.0001)
	assert_float(style.wave_progress(style.wave_time * 2.0)).is_equal(1.0)
	assert_float(style.wave_front(0.0, -300.0, 900.0)).is_equal(900.0)
	assert_float(style.wave_front(1.0, -300.0, 900.0)).is_equal(-300.0)
	assert_float(style.wave_weight(500.0, 500.0)).is_equal(0.5)
	assert_float(style.wave_weight(500.0 + style.wave_blend, 500.0)).is_equal(1.0)
	assert_float(style.wave_weight(500.0 - style.wave_blend, 500.0)).is_equal(0.0)
	# Afiş (HUD) ön ona vardığında gelir: varış süresindeki ön, afişin hizasında.
	for ratio: float in [0.0, 0.3, 0.75, 1.0]:
		var progress: float = style.wave_progress(style.wave_reach_time(ratio))
		assert_float(style.wave_front(progress, 0.0, 2400.0)).is_equal_approx(ratio * 2400.0, 0.01)


func test_wave_splits_old_and_new_and_moves_up() -> void:
	Neon.set_quality(GameTypes.Quality.HIGH, get_tree())
	var background: Background = _make()
	var old_ambient: Color = SECTORS.def_at(1).palette.ambient
	var new_ambient: Color = SECTORS.def_at(2).palette.ambient
	background.set_colors(old_ambient, Color.WHITE)
	assert_bool(background.is_wave_active()).is_false()
	background.start_wave(Color.BLACK, new_ambient, Color.WHITE)
	assert_bool(background.is_wave_active()).is_true()
	for path: String in ["%Wash", "%Crest", "%WaveGrid", "%WaveFar"]:
		assert_bool(_node(background, path).visible).override_failure_message(path).is_true()
	var view_height: float = background.get_viewport().get_visible_rect().size.y
	assert_float(background.wave_front()).is_equal_approx(view_height, 0.01)
	# Ön yukarı yürür (ilerleyiş iki adımda aynı: ara değerleme kesrinden bağımsız).
	background.set_wave(0.5)
	background.set_wave(0.5)
	await get_tree().process_frame
	assert_float(background.wave_front()).is_equal_approx(view_height * 0.5, 0.01)
	assert_object(_node(background, "%Near").self_modulate).is_equal(old_ambient)
	assert_object(_node(background, "%WaveNear").self_modulate).is_equal(new_ambient)
	assert_float(_node(background, "%WaveNear").position.y).is_equal(
			_node(background, "%Near").position.y)
	background.end_wave()
	assert_bool(background.is_wave_active()).is_false()
	assert_float(background.wave_front()).is_equal(INF)
	for path: String in ["%Wash", "%Crest", "%WaveGrid"]:
		assert_bool(_node(background, path).visible).override_failure_message(path).is_false()


func test_wave_at_low_quality_is_flat_color_and_line() -> void:
	Neon.set_quality(GameTypes.Quality.LOW, get_tree())
	var background: Background = _make()
	background.start_wave(Color.BLACK, Color.CYAN, Color.WHITE)
	assert_bool(_node(background, "%Wash").visible).is_true()
	assert_bool(_node(background, "%Crest").visible).is_true()
	assert_bool(_node(background, "%Grid").visible).is_false()
	assert_bool(_node(background, "%WaveGrid").visible).is_false()
	# Ortada dalga sürerken kalite değişirse yeni ağ da kaliteye uyar.
	Neon.set_quality(GameTypes.Quality.MEDIUM, get_tree())
	assert_bool(_node(background, "%WaveGrid").visible).is_true()
	assert_bool(_node(background, "%WaveFar").visible).is_false()


func _make() -> Background:
	var background: Background = auto_free(BACKGROUND_SCENE.instantiate()) as Background
	add_child(background)
	return background


func _node(background: Background, path: String) -> Node2D:
	return background.get_node(path) as Node2D


## Kamera climb px yukarı çıkınca desenin ekranda aşağı kaydığı yol (satır sarılmasıyla birlikte).
func _moved(climb: float, parallax: float, cell: float) -> float:
	var start_y: float = -2000.0
	var end_y: float = start_y - climb
	return _pattern_y(end_y, parallax, cell) - _pattern_y(start_y, parallax, cell)


func _pattern_y(camera_y: float, parallax: float, cell: float) -> float:
	return Background.layer_offset(camera_y, parallax, cell) \
			+ Background.layer_row(camera_y, parallax, cell) * cell
