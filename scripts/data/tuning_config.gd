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
# Tırmanış hızı burada değil: sektörün içinde sabittir ve SectorDef'ten gelir (M2-08).
## Oyuncuyu aktif duvara çeken yan ivme. Yüksek değer, çevirmeden sonra daha çabuk hızlanır.
@export_range(50.0, 600.0, 5.0, "suffix:m/sn²") var gravity_accel: float = 300.0
## Duvardan duvara geçişteki en yüksek yan hız. Geçiş süresini bu ve ivme birlikte belirler.
@export_range(10.0, 120.0, 1.0, "suffix:m/sn") var max_side_speed: float = 64.0

@export_group("Adalet")
## Havadayken yapılan dokunuşun saklanma süresi. Oyuncu bu süre içinde duvara değerse
## çevirme kaybolmaz, uygulanır (dokunma tamponu). Geçişten (≈ 0,37 sn) uzun olduğu için geçişin
## herhangi bir anındaki dokunuş inişte uygulanır: hızlı çift dokunuş "git ve geri dön" olur
## (kullanıcı geri bildirimi, ADR-036; M1'de 0,12 sn idi).
@export_range(0.0, 0.6, 0.01, "suffix:sn") var input_buffer_time: float = 0.45
## Çarpışma kutusunun görsele oranı. Küçük değer daha affedicidir.
@export_range(0.4, 1.0, 0.05) var hurtbox_scale: float = 0.7
## Duvar biter bitmez (boşluk) çevirme bu süre daha yapılabilir; süre dolunca koridorun dışındaki
## oyuncu düşmüş sayılır (coyote süresi, GDD §4).
@export_range(0.0, 0.25, 0.01, "suffix:sn") var coyote_time: float = 0.1
## Kalkan bir darbeyi emdikten sonraki dokunulmazlık (GDD §7).
@export_range(0.2, 3.0, 0.1, "suffix:sn") var shield_grace: float = 1.0

@export_group("Baskı")
## Tur başında çöküş duvarının oyuncunun altındaki mesafesi ve en fazla mesafe (GDD §14).
@export_range(5.0, 60.0, 1.0, "suffix:m") var wall_start_distance: float = 20.0
@export_range(10.0, 80.0, 1.0, "suffix:m") var wall_max_distance: float = 30.0
## Duvarı iten ve çeken olaylar (GDD §14): Glimmer, kıl payı, kalkanla darbe (M2-16).
@export_range(0.0, 5.0, 0.5, "suffix:m") var glimmer_push: float = 1.0
@export_range(0.0, 10.0, 0.5, "suffix:m") var near_miss_push: float = 3.0
@export_range(0.0, 20.0, 0.5, "suffix:m") var shield_pull: float = 8.0

@export_group("Kıl payı")
## Kıl payı alanının çarpışma kutusundan her yandaki fazlası (GDD §15; başlangıç 40 px).
@export_range(0.2, 2.0, 0.1, "suffix:m") var graze_margin: float = 0.8
## Bu süre içinde gelen yeni kıl payı komboyu uzatır.
@export_range(0.5, 5.0, 0.1, "suffix:sn") var combo_window: float = 2.5
## Glimmer çarpanı ×2 ve ×3 olduğu kombo uzunlukları (ilk değerler).
@export_range(2, 10, 1) var combo_x2_at: int = 3
@export_range(3, 20, 1) var combo_x3_at: int = 6
## Kıl payı yavaş çekimi (M3-12, GDD §15): zincirin ilk halkasında ve çarpanın büyüdüğü halkada
## oyun ve müzik bu ölçeğe yavaşlar. 1 = kapalı.
@export_range(0.1, 1.0, 0.05) var slow_motion_scale: float = 0.5
## Yavaş çekimin gerçek zamanla toplam süresi (dönüş dahil). 0 = kapalı.
@export_range(0.0, 1.0, 0.01, "suffix:sn") var slow_motion_time: float = 0.25
## Sürenin sonunda ölçeğin yumuşakça 1'e döndüğü kısım.
@export_range(0.0, 0.5, 0.01, "suffix:sn") var slow_motion_return: float = 0.08

@export_group("Toplama")
## Oyuncunun Glimmer toplama alanının yarıçapı (gövdeden büyük: affedici toplama, M2-13).
@export_range(0.5, 4.0, 0.1, "suffix:m") var pickup_radius: float = 1.5

@export_group("Kamera ve dünya")
## Kameranın oyuncunun üstünde gösterdiği mesafe; her cihazda aynıdır (sabit ileri görüş kuralı).
## Üst sınır, en kısa ekranda (16:9, 38,4 m) oyuncunun altında pay kalacak şekilde seçildi.
@export_range(10.0, 34.0, 0.5, "suffix:m") var lookahead: float = 28.0
## İki duvar arasındaki mesafe. Taban genişliğe (1080 px = 21,6 m) sığmalıdır.
@export_range(12.0, 21.6, 0.2, "suffix:m") var corridor_width: float = 18.0
## Tur başında ilk desen parçasına kadar boş mesafe. Vuruş ızgarası bozulmasın diye yukarı,
## tam vuruşa yuvarlanır (S1'de 25 m → 4 vuruş = 28,8 m).
@export_range(5.0, 60.0, 1.0, "suffix:m") var run_start_gap: float = 25.0
## Yeni sektörün başındaki engelsiz "nefes alma" süresi (GDD §12: 2–3 sn). Yeni sektörün hızıyla
## ölçülür ve tam vuruşa yukarı yuvarlanır.
@export_range(0.0, 5.0, 0.1, "suffix:sn") var sector_breath: float = 2.5

@export_group("Zorluk")
## Sektör içi hedef zorluğun çevresinde seçim genişliği (zorluk birimi). Küçük değer hedefe yakın
## parçaları seçer; büyük değer daha karışık bir akış verir (M2-10).
@export_range(0.3, 3.0, 0.1) var difficulty_spread: float = 0.5
## Son kaç parça yeniden seçilmez. Sektör sonunda sığan başka parça yoksa kural esner.
@export_range(0, 6, 1) var no_repeat_count: int = 3

@export_group("Oyun hissi")
## Ölümde dünyanın donduğu süre (vuruş, lazer, dalga, iz); ardından kamera sarsılır (GDD §19).
## Yeniden başlama süresinin içindedir, turu uzatmaz.
@export_range(0.0, 0.3, 0.01, "suffix:sn") var death_freeze: float = 0.1
## Ölümün ve kalkan kırılmasının kameraya verdiği sarsıntı (travma, 0–1).
@export_range(0.0, 1.0, 0.05) var death_trauma: float = 0.8
@export_range(0.0, 1.0, 0.05) var shield_trauma: float = 0.5
## Tam travmadaki en büyük yatay kayma. Sarsıntı travmanın karesiyle büyür.
@export_range(0.0, 2.0, 0.1, "suffix:m") var shake_offset: float = 1.0
## Travmanın saniyede sönen miktarı.
@export_range(0.5, 5.0, 0.1, "suffix:/sn") var shake_decay: float = 1.5
## Sarsıntının gürültü hızı: yüksek değer daha sık titrer.
@export_range(5.0, 40.0, 1.0, "suffix:Hz") var shake_frequency: float = 20.0

@export_group("Ekonomi")
## Sektör tamamlama bonusu: turda geçilen her sektör için bu × sektör numarası Glimmer
## (GDD §9.1; S1 ve S2'yi geçen tur 25 + 50 alır).
@export_range(0, 100, 5, "suffix:Glimmer") var sector_bonus: int = 25


## Metreyi (ya da m/sn, m/sn²) piksele çevirir.
static func to_px(meters: float) -> float:
	return meters * PX_PER_M
