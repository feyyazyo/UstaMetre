import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';

/// Büyük, rahat dokunulabilir sayısal giriş alanı.
///
/// Yalnızca rakam, virgül ve nokta kabul eder; Türkçe biçim (1.250,75)
/// motor tarafında [parseDecimal] ile çözülür.
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.controller,
    required this.label,
    this.suffix,
    this.errorText,
    this.integerOnly = false,
    this.allowNegative = false,
  });

  final TextEditingController controller;
  final String label;
  final String? suffix;
  final String? errorText;
  final bool integerOnly;

  /// Eksi işaretine izin verir (ör. profil reçetesindeki kesim payı).
  final bool allowNegative;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !integerOnly),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          integerOnly
              ? RegExp(r'[0-9]')
              : (allowNegative ? RegExp(r'[0-9.,\-]') : RegExp(r'[0-9.,]')),
        ),
      ],
      style: const TextStyle(fontSize: 20, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        errorText: errorText,
        errorMaxLines: 2,
      ),
    );
  }
}
