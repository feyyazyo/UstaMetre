/// Hesaplama motorunun temel sözleşmesi.
///
/// Motor katmanı (`lib/engine/`) Flutter'a bağımlı değildir; yalnızca saf Dart
/// kullanır. Böylece arayüzden bağımsız olarak test edilebilir ve ileride
/// başka platformlarda yeniden kullanılabilir.
abstract interface class Calculator<I, O> {
  /// Hesaplayıcının benzersiz kimliği (ör. `manual.rectangle_area`).
  String get id;

  /// Girdiyi doğrular ve sonucu üretir. Geçersiz girdide
  /// [CalculationException] fırlatır.
  O calculate(I input);
}

/// Hesaplama girdisi geçersiz olduğunda fırlatılır. [message] kullanıcıya
/// gösterilebilecek Türkçe bir açıklamadır.
final class CalculationException implements Exception {
  const CalculationException(this.message);

  final String message;

  @override
  String toString() => 'CalculationException: $message';
}
