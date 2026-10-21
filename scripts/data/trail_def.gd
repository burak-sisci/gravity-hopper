class_name TrailDef
extends Resource
## Kozmetik iz (M4-08, GDD §11, architecture.md §10): renk geçişi, kalınlık, parlama ve boy.
##
## Yalnızca izi değiştirir; oyuncunun çekirdeği her izde beyazdır. Oynanışı etkilemez, günlük
## meydan okumada da geçerlidir. Nasıl açıldığı unlock'ta: satın alınan izin fiyatı cost,
## kıl payı başarımının hedefi goal. Renkler tehlike kırmızısından ve Glimmer yeşilinden uzak
## durur (test).

## Kayıttaki anahtar (kaydın "trails" bölümü) ve kodun kullandığı ad.
@export var id: StringName
## Adın çeviri anahtarı (TRAIL_…; mağaza M5).
@export var name_key: String = ""
## Başarım izinin koşul metni (çeviri anahtarı; %d yerine goal yazılır). Satın alınan izde boş.
@export var desc_key: String = ""
## İzin nasıl açıldığı.
@export var unlock: GameTypes.TrailUnlock = GameTypes.TrailUnlock.PURCHASE
## Fiyat (Glimmer; yalnızca PURCHASE).
@export var cost: int = 0
## Başarım hedefi (NEAR_MISSES: toplam kıl payı).
@export var goal: int = 0
## Baştan kuyruğa renk geçişi, eşit aralıklı; kuyruk saydama söner. Boşsa varsayılan iz:
## oyuncunun beyazından sektörün çevre rengine.
@export var colors: PackedColorArray = PackedColorArray()
## Parlamanın rengi; saydamsa sektörün çevre rengi.
@export var glow_color: Color = Color.TRANSPARENT
## Kalınlık çarpanı (NeonStyle.trail_width'e göre).
@export_range(0.5, 2.0, 0.05) var width_scale: float = 1.0
## Parlama katmanlarının kalınlık çarpanı.
@export_range(0.5, 2.0, 0.05) var glow_scale: float = 1.0
## Boy çarpanı (izin süresi); sektörün hızıyla uzama bunun üstüne gelir.
@export_range(0.5, 2.0, 0.05) var length_scale: float = 1.0


## Sektörün çevre rengini izleyen (varsayılan) iz mi.
func follows_ambient() -> bool:
	return colors.is_empty()
