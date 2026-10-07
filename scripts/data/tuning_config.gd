class_name TuningConfig
extends Resource
## Oyun hissinin ayar değerleri (architecture.md §10). Geçerli değerler
## data/tuning/default_tuning.tres dosyasındadır; buradaki varsayılanlar yalnızca başlangıçtır.
##
## Birimler tasarım belgesiyle aynıdır: mesafe metre, hız m/sn, süre saniye. Kod piksele
## to_px() ile çevirir. Her alanın aralığı ve birimi, canlı ayar panelinin (M1-11)
## kaydırıcılarını kendiliğinden kurmak için kullanılır.

## Dünya birimi: 1 m = 50 px (architecture.md §3). Ayarlanan bir değer değildir.
const PX_PER_M: float = 50.0

@export_group("Hareket")
## Sabit tırmanış hızı. M1'de geçicidir; M2-06'da sektörlerden (SectorDef) gelir. S1 = 12 m/sn.
@export_range(4.0, 30.0, 0.5, "suffix:m/sn") var climb_speed: float = 12.0
## Oyuncuyu aktif duvara çeken yan ivme. Yüksek değer, çevirmeden sonra daha çabuk hızlanır.
@export_range(50.0, 600.0, 5.0, "suffix:m/sn²") var gravity_accel: float = 300.0
## Duvardan duvara geçişteki en yüksek yan hız. Geçiş süresini bu ve ivme birlikte belirler.
@export_range(10.0, 120.0, 1.0, "suffix:m/sn") var max_side_speed: float = 64.0

@export_group("Adalet")
## Havadayken yapılan dokunuşun saklanma süresi. Oyuncu bu süre içinde duvara değerse
## çevirme kaybolmaz, uygulanır (dokunma tamponu).
@export_range(0.0, 0.3, 0.01, "suffix:sn") var input_buffer_time: float = 0.12
## Çarpışma kutusunun görsele oranı. Küçük değer daha affedicidir.
@export_range(0.4, 1.0, 0.05) var hurtbox_scale: float = 0.7

@export_group("Kamera ve dünya")
## Kameranın oyuncunun üstünde gösterdiği mesafe; her cihazda aynıdır (sabit ileri görüş kuralı).
@export_range(10.0, 40.0, 0.5, "suffix:m") var lookahead: float = 28.0
## İki duvar arasındaki mesafe. Taban genişliğe (1080 px = 21,6 m) sığmalıdır.
@export_range(12.0, 21.6, 0.2, "suffix:m") var corridor_width: float = 18.0


## Metreyi (ya da m/sn, m/sn²) piksele çevirir.
static func to_px(meters: float) -> float:
	return meters * PX_PER_M
