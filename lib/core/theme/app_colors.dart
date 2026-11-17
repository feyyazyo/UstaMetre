import 'package:material_ui/material_ui.dart';

/// UstaMetre marka renk paleti.
abstract final class AppColors {
  static const Color background = Color(0xFF111318);
  static const Color card = Color(0xFF1B2028);
  static const Color gold = Color(0xFFD6A84F);
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFA0A6B0);

  /// Altın vurgunun üzerindeki yazı rengi (yüksek kontrast için koyu).
  static const Color onGold = Color(0xFF111318);

  /// Kart kenarlıkları ve ayırıcılar için ince ton.
  static const Color outline = Color(0xFF2A303A);
}
