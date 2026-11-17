# UstaMetre

**Ölç. Hesapla. Fiyatlandır.**

Tüm meslek grupları için ölçüm, hesaplama ve fiyat teklifi hazırlama uygulaması.
Flutter ile geliştirilir, öncelikli platform Android'dir. Arayüz Türkçedir ve
uygulama çevrimdışı (offline-first) çalışacak şekilde tasarlanmıştır.

## Durum (Sprint 1)

| Alan | Durum |
|---|---|
| Proje iskeleti, tema, alt gezinme (5 ekran) | ✅ |
| Ana sayfa ve 4 kısayol (Yeni Hesaplama, Yeni Proje, Yeni Teklif, Müşteriler) | ✅ (kısayollar ilgili ekranlara gider) |
| 12 meslek kategorisi | 🟡 Mimari olarak tanımlı, hesaplamalar **henüz yok** (arayüzde "Yakında") |
| Hesaplama motoru temeli (kesin ondalık para/ölçü, dikdörtgen alan hesaplayıcı) | ✅ Birim testli, arayüze henüz bağlı değil |
| Proje / teklif / müşteri kaydı, yerel veritabanı | ⏳ Sonraki sprintler |
| GitHub Actions: analyze, test, APK artifact | ✅ |

## Klasör yapısı

```
lib/
├── main.dart                 # Giriş noktası
├── app/                      # MaterialApp ve alt gezinme kabuğu
├── core/
│   ├── constants/            # Türkçe arayüz metinleri
│   └── theme/                # Renk paleti ve tema
├── domain/                   # Saf Dart iş modelleri (meslek kategorileri)
├── engine/                   # Saf Dart hesaplama motoru (Flutter'a bağımlı DEĞİL)
│   ├── calculator.dart       # Calculator<I, O> sözleşmesi
│   ├── money.dart            # Kuruş hassasiyetli para (BigInt)
│   ├── measurement.dart      # Uzunluk / alan (Decimal)
│   ├── number_parser.dart    # "1.250,75" gibi Türkçe sayı girişi
│   └── calculators/          # Somut hesaplayıcılar
├── features/                 # Ekranlar (özellik bazlı)
│   ├── home/  calculations/  projects/  quotes/  customers/  settings/
└── shared/widgets/           # Ortak arayüz bileşenleri
test/
├── engine/                   # Motor birim testleri
├── architecture/             # Katman sınırı testleri
└── widgets/                  # Widget testleri
```

### Temel kurallar

- **Motor arayüzden bağımsızdır:** `lib/engine` ve `lib/domain` Flutter içe
  aktarmaz. Bu kural `test/architecture/layer_boundaries_test.dart` ile
  otomatik denetlenir.
- **Kayan nokta yok:** Para `Money` (tam sayı kuruş), ölçüler `Decimal` ile
  tutulur. Motor kodunda `double` kullanımı test ile engellenir.
- **Dürüst durum:** Bir kategori yalnızca hesaplamaları arayüze bağlanıp test
  edildiğinde `ModuleStatus.available` yapılır.
- **Ücretli servis / yapay zekâ API'si yok;** veriler cihazda kalır.

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
