extends GdUnitTestSuite
## Parçacık patlamaları (M3-11, architecture.md §9): yayıcılar baştan kurulur ve halkayla yeniden
## kullanılır (düğüm oluşmaz), patlama verilen yerde ve yönde çıkar, düşük kalitede parçacık
## azalır, çevre rengi yalnızca kıvılcımı boyar.

var _quality: GameTypes.Quality


func before_test() -> void:
	_quality = Neon.quality


func after_test() -> void:
	Neon.set_quality(_quality, get_tree())


func test_bursts_reuse_a_fixed_ring_of_emitters() -> void:
	var effects: Effects = _add_effects()
	var emitters: Array[CPUParticles2D] = effects.emitters()
	var count: int = effects.get_child_count()
	assert_int(emitters.size()).is_equal(
			Effects.SPARK_EMITTERS + Effects.GLIMMER_EMITTERS + Effects.DEATH_EMITTERS)
	for i: int in Effects.SPARK_EMITTERS + 1:
		effects.landing_spark(Vector2(-450.0, -100.0 * i), -1.0)
	for i: int in 5:
		effects.glimmer_burst(Vector2(0.0, -50.0 * i))
		effects.death_burst(Vector2(10.0 * i, 0.0))
	await get_tree().physics_frame
	assert_int(effects.get_child_count()).is_equal(count)
	assert_array(effects.emitters()).contains_exactly(emitters)
	# Halka başa döndü: ilk kıvılcım yayıcısı son kıvılcımın yerinde.
	assert_vector(emitters[0].global_position).is_equal(
			Vector2(-450.0, -100.0 * Effects.SPARK_EMITTERS))
	assert_vector(emitters[emitters.size() - 1].global_position).is_equal(Vector2(40.0, 0.0))
	for emitter: CPUParticles2D in emitters:
		assert_bool(emitter.emitting).is_true()
		assert_bool(emitter.local_coords).is_false()


func test_spark_flies_into_the_corridor() -> void:
	var effects: Effects = _add_effects()
	var sparks: Array[CPUParticles2D] = effects.emitters()
	effects.landing_spark(Vector2(-450.0, 0.0), -1.0)
	effects.landing_spark(Vector2(450.0, 0.0), 1.0)
	assert_vector(sparks[0].direction).is_equal(Vector2.RIGHT)
	assert_vector(sparks[1].direction).is_equal(Vector2.LEFT)


func test_low_quality_has_fewer_particles() -> void:
	var effects: Effects = _add_effects()
	Neon.set_quality(GameTypes.Quality.HIGH, get_tree())
	var high: Array[int] = _amounts(effects)
	assert_int(high[0]).is_equal(Neon.STYLE.landing_spark.amount)
	Neon.set_quality(GameTypes.Quality.LOW, get_tree())
	var low: Array[int] = _amounts(effects)
	for i: int in high.size():
		assert_int(low[i]).is_less(high[i])
		assert_int(low[i]).is_greater_equal(1)
	assert_int(effects.get_child_count()).is_equal(high.size())


func test_ambient_colors_only_the_sparks() -> void:
	var effects: Effects = _add_effects()
	var ambient: Color = Color(0.9, 0.4, 1.0)
	effects.set_ambient(ambient)
	var emitters: Array[CPUParticles2D] = effects.emitters()
	assert_that(emitters[0].color_ramp.colors[1]).is_equal(ambient)
	assert_that(emitters[Effects.SPARK_EMITTERS].color_ramp.colors[1]).is_equal(
			Neon.STYLE.glimmer_color)
	assert_that(emitters[emitters.size() - 1].color_ramp.colors[1]).is_equal(
			Neon.STYLE.player_color)


func _add_effects() -> Effects:
	var effects: Effects = auto_free(Effects.new()) as Effects
	add_child(effects)
	return effects


func _amounts(effects: Effects) -> Array[int]:
	var result: Array[int] = []
	for emitter: CPUParticles2D in effects.emitters():
		result.append(emitter.amount)
	return result
