/// Kalem, parça ve fiyat listesi kayıtları için benzersiz kimlik üretir.
abstract interface class IdGenerator {
  String next();
}

/// Zaman damgası + sayaç tabanlı, cihaz içinde benzersiz kimlik.
final class TimestampIdGenerator implements IdGenerator {
  TimestampIdGenerator([this.prefix = 'id']);

  final String prefix;
  int _counter = 0;

  @override
  String next() =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
}

/// Testler için öngörülebilir kimlikler: `p1`, `p2`, …
final class SequentialIdGenerator implements IdGenerator {
  SequentialIdGenerator([this.prefix = 'id']);

  final String prefix;
  int _counter = 0;

  @override
  String next() => '$prefix${++_counter}';
}
