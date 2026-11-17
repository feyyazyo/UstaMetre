/// Bir meslek kategorisinin geliştirme durumu.
///
/// Arayüz, henüz hazır olmayan hesaplamaları tamamlanmış gibi göstermemek
/// için bu durumu kullanır.
enum ModuleStatus {
  /// Mimari olarak tanımlı, hesaplamaları henüz uygulanmadı.
  planned('Yakında'),

  /// Hesaplamaları uygulandı ve test edildi.
  available('Hazır');

  const ModuleStatus(this.label);

  final String label;
}

/// Meslek kategorisi. Saf Dart'tır; ikon eşlemesi arayüz katmanında yapılır.
final class TradeCategory {
  const TradeCategory({
    required this.id,
    required this.name,
    required this.description,
    this.status = ModuleStatus.planned,
    this.calculatorIds = const [],
  });

  /// Kalıcı kimlik (kayıtlarda ve ikon eşlemesinde kullanılır).
  final String id;
  final String name;
  final String description;
  final ModuleStatus status;

  /// Bu kategoriye bağlı hesaplayıcıların kimlikleri (bkz. `Calculator.id`).
  final List<String> calculatorIds;

  bool get isAvailable => status == ModuleStatus.available;
}

/// İlk sürümde desteklenecek meslek kategorileri.
///
/// Sprint 1 itibarıyla tüm kategoriler [ModuleStatus.planned] durumundadır.
/// Bir kategorinin hesaplamaları arayüze bağlanıp test edildiğinde durumu
/// [ModuleStatus.available] yapılmalıdır.
abstract final class TradeCategories {
  static const List<TradeCategory> all = [
    TradeCategory(
      id: 'marble_granite',
      name: 'Mermer ve granit',
      description: 'Tezgâh, basamak, denizlik ve plaka hesapları',
    ),
    TradeCategory(
      id: 'ceramic_tile',
      name: 'Seramik ve fayans',
      description: 'Zemin, duvar, derz ve fire hesapları',
    ),
    TradeCategory(
      id: 'furniture_carpentry',
      name: 'Mobilya ve marangoz',
      description: 'Dolap, panel ve kenar bandı hesapları',
    ),
    TradeCategory(
      id: 'glass_aluminium',
      name: 'Cam ve alüminyum',
      description: 'Cam alanı, profil ve doğrama hesapları',
    ),
    TradeCategory(
      id: 'iron_joinery',
      name: 'Demir ve doğrama',
      description: 'Profil metrajı, korkuluk ve kapı hesapları',
    ),
    TradeCategory(
      id: 'paint',
      name: 'Boya ve badana',
      description: 'Duvar/tavan alanı ve boya sarfiyatı',
    ),
    TradeCategory(
      id: 'construction_renovation',
      name: 'İnşaat ve tadilat',
      description: 'Beton, sıva, duvar ve malzeme metrajı',
    ),
    TradeCategory(
      id: 'electrical',
      name: 'Elektrik',
      description: 'Kablo metrajı, priz ve armatür keşfi',
    ),
    TradeCategory(
      id: 'plumbing',
      name: 'Su tesisatı',
      description: 'Boru metrajı, bağlantı ve armatür keşfi',
    ),
    TradeCategory(
      id: 'drywall_decoration',
      name: 'Alçıpan ve dekorasyon',
      description: 'Levha, profil ve asma tavan hesapları',
    ),
    TradeCategory(
      id: 'roof_insulation',
      name: 'Çatı ve izolasyon',
      description: 'Çatı alanı, eğim ve yalıtım malzemesi',
    ),
    TradeCategory(
      id: 'custom_manual',
      name: 'Özel ölçü ve manuel hesaplama',
      description: 'Serbest ölçü, alan ve birim fiyat hesabı',
    ),
  ];
}
