# UstaMetre

**Ölç. Hesapla. Fiyatlandır.**

Tüm meslek grupları için ölçüm, hesaplama ve fiyat teklifi hazırlama uygulaması.
Flutter ile geliştirilir, öncelikli platform Android'dir. Arayüz Türkçedir ve
uygulama çevrimdışı (offline-first) çalışacak şekilde tasarlanmıştır.

## Durum (Sprint 4)

| Alan | Durum |
|---|---|
| Proje iskeleti, tema, alt gezinme (5 ekran) | ✅ |
| Hızlı hesap: uzunluk, alan, hacim, metre tül, çevre, adet, manuel (tüm kategoriler) | ✅ |
| Ortak ek maliyet sistemi, indirim, KDV, KDV dahil/hariç gösterim | ✅ |
| Fiyat listesi (fiyat ve birim geçmişi) | ✅ Cihazda (SharedPreferences) |
| Mermer ve granit: çok parçalı tezgâh, kenar işlemleri, evye, montaj… | ✅ Özel hesap |
| PVC kapı ve pencere: pencere/kapı/balkon kapısı, cam, profil, aksesuar | ✅ Özel hesap (doğrulanmamış reçete **tahmini**) |
| **Hesap kaydetme** (üç hesap ekranından), sürüm geçmişi, kopyalama, onaylı silme | ✅ Cihazda (SQLite) |
| **Hesap geçmişi**: ada göre arama, meslek filtresi, tarih sıralaması, ayrıntı | ✅ |
| **Müşteriler**: ekle, düzenle, sil, ara; müşterinin projeleri ve hesapları | ✅ |
| **Projeler**: 6 durum, müşteri bağlantısı, birden fazla hesap, arama ve durum filtresi | ✅ |
| JSON yedekleme / geri yükleme | 🟡 Altyapı ve testler hazır; arayüzde **yok** (Ayarlar → Yedekleme "Yakında") |
| Diğer 11 kategorinin mesleğe özel hesapları | ⏳ Henüz yok (arayüzde "Genel hesap") |
| Teklif, PDF, paylaşım | ⏳ Bu sprintin kapsamı dışında |
| GitHub Actions: analyze, test, APK artifact | ✅ |

### Kayıtlar ve veri güvenliği (Sprint 4)

- **Veritabanı:** SQLite (`sqflite`), cihazda; internet gerekmez. Tablolar: `customers`,
  `projects`, `calculations`, `calculation_revisions`. Veritabanı işlemleri
  `lib/data/records_repository.dart` içindedir; ekranlar `RecordsController` üzerinden erişir.
- **Şema sürümleme:** Şema yalnızca sıralı geçişlerle kurulur (`AppDatabase.migrations`).
  Güncellemede yalnızca eksik adımlar çalışır, kayıtlar silinmez; yükseltmeden önce dosyanın
  yedeği alınır (`ustametre.db.v<eski>.bak`). Daha yeni şemalı bir veritabanı açılmaz ve
  silinmez.
- **Kayıt biçimi sürümü:** Her hesap sürümü `schema` alanı taşır; eski biçimler
  `migrateRevisionJson` ile adım adım taşınır. Okunamayan / daha yeni biçimli kayıtlar
  **silinmez**, "okunamayan kayıt" olarak bildirilir ve yedeğe ham hâliyle girer.
- **Kayıt anındaki değerler:** Girdiler (ölçüler, birimler, fire, birim fiyatlar, ek kalemler,
  indirim, KDV) ve sonuç (satırlar, kategori toplamları, KDV, genel toplam, açıklama adımları)
  kaydedildiği hâliyle saklanır. Sonuç geri yüklenirken **yeniden hesaplanmaz**; fiyat listesi
  veya hesap kuralları değişse de eski kayıt değişmez.
- **Düzenleme = yeni sürüm:** Kayıtlı hesap "Düzenle" ile kendi ekranında açılır; kaydedilince
  yeni sürüm eklenir, önceki sürümler korunur ve ayrıntı ekranından görülebilir. İstenirse
  "ayrı yeni hesap" olarak da kaydedilebilir. Ad / müşteri / proje değişikliği sürüm oluşturmaz.
- **Silme:** Hesap silme onay ister. Müşteri veya proje silindiğinde bağlı projeler ve hesaplar
  **silinmez**, yalnızca bağlantıları kaldırılır (`ON DELETE SET NULL` + açık güncelleme).

### Hesap kuralları

- Ölçüler seçilen birimden (mm/cm/m) metreye kesin olarak çevrilir; `double` kullanılmaz.
- Satır tutarı = miktar × birim fiyat, kuruşa yarım yukarı yuvarlanır.
- Sıra: **ara toplam → indirim → KDV matrahı → KDV → genel toplam**; her adım
  kuruşa yuvarlanır ve `ara toplam − indirim + KDV = genel toplam` kuruşu kuruşuna tutar.
- KDV dahil gösterimde satırlar KDV eklenmiş gösterilir; bağlayıcı olan genel toplamdır.
- Fire, malzeme ve işçilik bağımsızdır:
  - Mermer: fire yalnızca malzemeye (m²); tezgâh işçiliği ve kenar işlemleri net ölçüden.
  - PVC: profil firesi yalnızca profile, cam firesi yalnızca cama.
  - Adet hesabında fireli miktar yukarı tam sayıya yuvarlanır.
- Kenar işlemleri: her parçada her işlem için kenar seçilir (ön/arka = uzunluk,
  sol/sağ = derinlik); metre tül = seçilen kenarların uzunlukları × adet toplamı.

### Tahmini hesaplar (bilinçli olarak kesin gösterilmez)

- **Profil reçetesi:** Kesim formülleri (kasa, kanat, orta kayıt, çıta…) açılım türüne
  ve üretici sistemine göre değişir. Reçete kullanıcı tarafından "doğrulandı" olarak
  işaretlenmedikçe profil satırları "(tahmini)" etiketlenir ve uyarı gösterilir.
- **Cam alanı:** Ölçülen cam alanı girilmezse dış ölçü alanı kullanılır ve sonuç
  "yaklaşık" uyarısıyla gösterilir.

### Fiyat listesi ve eski hesaplar

- Fiyat veya birim değiştiğinde eski kayıt silinmez, geçmişe eklenir (`PricePoint`).
- Listeden hesaba eklenen kalem fiyatı **kopyalar** ve kaynağını (`PriceSource`:
  kayıt kimliği + fiyat tarihi) tutar. Liste sonradan değişse de hesaplanmış kalemin
  tutarı değişmez.
- Veriler cihazda (SharedPreferences, JSON, sürüm bilgili) saklanır; okunamayan kayıt
  silinmez, yedeklenir.

## Klasör yapısı

```
lib/
├── main.dart                 # Giriş: cihazdaki kataloğu yükler
├── app/                      # MaterialApp ve alt gezinme kabuğu
├── core/                     # Türkçe metinler, renkler, tema
├── domain/                   # Saf Dart iş modelleri (kategoriler, records/: müşteri, proje, hesap)
├── engine/                   # Saf Dart hesaplama motoru (Flutter'a bağımlı DEĞİL)
│   ├── money.dart, measurement.dart, number_parser.dart, number_format.dart
│   ├── pricing.dart          # Satır, indirim, KDV, özet
│   ├── price_steps.dart      # "Nasıl hesaplandı?" fiyat adımları
│   ├── calculation_result.dart  # Sonuç + JSON (PDF teklife hazır)
│   ├── costing/              # CostItem, CostSheet, PriceList (geçmişli)
│   └── calculators/          # Genel ölçü, mermer (hızlı + proje), PVC doğrama
├── data/                     # Offline depolama: katalog (SharedPreferences),
│   │                         # kayıtlar (SQLite: db/app_database.dart, records_repository.dart)
├── features/
│   ├── calculations/         # Hızlı hesap, kategori seçimi, marble/, pvc/
│   ├── costing/              # Ortak ek maliyet editörü, fiyatlandırma seçenekleri
│   ├── price_list/           # Fiyat listesi ekranı
│   ├── records/              # Kaydetme, hesap geçmişi, ayrıntı/sürümler, editörler
│   └── home/ projects/ quotes/ customers/ settings/
└── shared/                   # Ortak widget'lar, giriş ayrıştırma
test/
├── engine/  data/  features/  architecture/  widgets/
└── helpers.dart
```

## Geliştirme

Gereksinim: Flutter 3.50 (Dart 3.14), Java 17, Android SDK.

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

> Not: Release derlemesi şimdilik debug anahtarıyla imzalanır. Play Store'a
> yüklemeden önce imzalama anahtarı yapılandırılmalı (anahtar dosyaları depoya
> eklenmemelidir).

## CI

`.github/workflows/android.yml` her push ve pull request'te Flutter'ı kurar,
bağımlılıkları yükler, `flutter analyze` ve `flutter test` çalıştırır, release
APK derler ve APK'yı Actions artifact olarak yükler.
