extends GdUnitTestSuite
## Ana sahne silinince geride sinyal bağlantısı kalmaz (sızıntı yok). Godot, bir nesneye bağlı
## yöntem ve `self` kullanan lambda bağlantılarını nesne silinince kendisi koparır; `self`
## kullanmayan bir lambda ise hiçbir nesneye bağlı sayılmaz ve autoload sinyalinde asılı kalır.
## Sonraki turda silinmiş nesnenin yakaladığı değerlerle çalışır (hud_test'te
## "Cannot connect to 'frame_post_draw' … null::_log_event" hatası böyle çıkıyordu).

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
## Sahnenin kurulup turun başlaması için beklenen kare.
const SETTLE_FRAMES: int = 20


func after_test() -> void:
	GameManager.reset()


## Autoload'ların ve RenderingServer'ın her sinyalindeki bağlantı sayısı, ana sahne kurulup bir
## tur oynanıp silindikten sonra öncekiyle aynıdır.
func test_main_scene_leaves_no_signal_connections() -> void:
	var counts_before: Dictionary[String, int] = _connection_counts()
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await _frames(SETTLE_FRAMES)
	Events.play_requested.emit()
	await _frames(SETTLE_FRAMES)
	main.queue_free()
	await _frames(2)
	var leaks: Array[String] = []
	var counts_after: Dictionary[String, int] = _connection_counts()
	for key: String in counts_after:
		var extra: int = counts_after[key] - counts_before.get(key, 0)
		if extra > 0:
			leaks.append("%s +%d" % [key, extra])
	assert_array(leaks).override_failure_message("asılı kalan bağlantılar: %s" % [
		", ".join(leaks)]).is_empty()


func _connection_counts() -> Dictionary[String, int]:
	var counts: Dictionary[String, int] = {}
	var sources: Array[Object] = [RenderingServer]
	for node: Node in get_tree().root.get_children():
		if node != get_tree().current_scene and not node is GdUnitTestSuite:
			sources.append(node)
	for source: Object in sources:
		for info: Dictionary in source.get_signal_list():
			var signal_name: StringName = info["name"]
			counts["%s.%s" % [_label(source), signal_name]] = source.get_signal_connection_list(
					signal_name).size()
	return counts


func _label(source: Object) -> String:
	if source is Node:
		return String((source as Node).name)
	return source.get_class()


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame
