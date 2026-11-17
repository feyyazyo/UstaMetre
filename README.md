# UstaMetre

**Ölç. Hesapla. Fiyatlandır.**

Tüm meslek grupları için ölçüm, hesaplama ve fiyat teklifi hazırlama uygulaması.
Flutter ile geliştirilir, öncelikli platform Android'dir. Arayüz Türkçedir ve
uygulama çevrimdışı (offline-first) çalışacak şekilde tasarlanmıştır.

## Durum (Sprint 3)

| Alan | Durum |
|---|---|
| Proje iskeleti, tema, alt gezinme (5 ekran) | ✅ |
| Hızlı hesap: uzunluk, alan, hacim, metre tül, çevre, adet, manuel (tüm kategoriler) | ✅ |
| Ortak ek maliyet sistemi: ekle, düzenle, sil, kopyala, kendi kalemini oluştur, fiyat listesine kaydet | ✅ Tüm hesap ekranlarında |
| İndirim (yüzde / tutar), değiştirilebilir KDV, KDV dahil/hariç gösterim | ✅ |
| Fiyat listesi: malzeme, işçilik, aksesuar, nakliye, diğer; fiyat ve birim geçmişi | ✅ Cihazda saklanır |
| Mermer ve granit: çok parçalı tezgâh, kenar seçimli sakal/pah/rodaj/kenar işleme, evye, ocak, delikler, nakliye, montaj | ✅ Özel hesap |
| PVC kapı ve pencere: pencere, kapı, balkon kapısı; cam, profil (manuel / reçete), aksesuar, sineklik, montaj, nakliye | ✅ Özel hesap (profil reçetesi doğrulanmadıkça **tahmini**) |
| Diğer 11 kategorinin mesleğe özel hesapları | ⏳ Henüz yok (arayüzde "Genel hesap") |
| Hesap sonuçlarını kaydetme, proje / teklif / müşteri, PDF teklif | ⏳ Sonraki sprintler (veri yapısı hazır: `CalculationResult.toJson`) |
| GitHub Actions: analyze, test, APK artifact | ✅ |

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
├── domain/                   # Saf Dart iş modelleri (meslek kategorileri)
├── engine/                   # Saf Dart hesaplama motoru (Flutter'a bağımlı DEĞİL)
│   ├── money.dart, measurement.dart, number_parser.dart, number_format.dart
│   ├── pricing.dart          # Satır, indirim, KDV, özet
│   ├── price_steps.dart      # "Nasıl hesaplandı?" fiyat adımları
│   ├── calculation_result.dart  # Sonuç + JSON (PDF teklife hazır)
│   ├── costing/              # CostItem, CostSheet, PriceList (geçmişli)
│   └── calculators/          # Genel ölçü, mermer (hızlı + proje), PVC doğrama
├── data/                     # Offline depolama ve katalog (fiyat listesi, reçeteler)
├── features/
│   ├── calculations/         # Hızlı hesap, kategori seçimi, marble/, pvc/
│   ├── costing/              # Ortak ek maliyet editörü, fiyatlandırma seçenekleri
│   ├── price_list/           # Fiyat listesi ekranı
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
