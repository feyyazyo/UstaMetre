import 'package:decimal/decimal.dart';

/// Desteklenen uzunluk birimleri.
enum LengthUnit {
  millimeter('mm', '0.001'),
  centimeter('cm', '0.01'),
  meter('m', '1');

  const LengthUnit(this.symbol, this._toMeters);

  final String symbol;
  final String _toMeters;

  Decimal get toMetersFactor => Decimal.parse(_toMeters);
}

/// Kesin ondalık değerli uzunluk. Dahili olarak metre cinsinden tutulur.
final class Length implements Comparable<Length> {
  const Length._(this.meters);

  final Decimal meters;

  factory Length(Decimal value, LengthUnit unit) =>
      Length._(value * unit.toMetersFactor);

  factory Length.meters(Decimal value) => Length._(value);

  Decimal inUnit(LengthUnit unit) =>
      (meters / unit.toMetersFactor).toDecimal(scaleOnInfinitePrecision: 10);

  Length operator +(Length other) => Length._(meters + other.meters);

  /// İki kenarın çarpımı → alan.
  Area operator *(Length other) => Area.squareMeters(meters * other.meters);

  @override
  int compareTo(Length other) => meters.compareTo(other.meters);

  @override
  bool operator ==(Object other) => other is Length && other.meters == meters;

  @override
  int get hashCode => meters.hashCode;

  @override
  String toString() => '${meters.toString()} m';
}

/// Kesin ondalık değerli alan (m²).
final class Area implements Comparable<Area> {
  const Area._(this.squareMeters);

  final Decimal squareMeters;

  factory Area.squareMeters(Decimal value) => Area._(value);

  static final Area zero = Area._(Decimal.zero);

  Area operator +(Area other) => Area._(squareMeters + other.squareMeters);

  Area times(Decimal factor) => Area._(squareMeters * factor);

  /// Alan × yükseklik → hacim.
  Volume operator *(Length height) =>
      Volume.cubicMeters(squareMeters * height.meters);

  @override
  int compareTo(Area other) => squareMeters.compareTo(other.squareMeters);

  @override
  bool operator ==(Object other) =>
      other is Area && other.squareMeters == squareMeters;

  @override
  int get hashCode => squareMeters.hashCode;

  @override
  String toString() => '${squareMeters.toString()} m²';
}

/// Kesin ondalık değerli hacim (m³).
final class Volume implements Comparable<Volume> {
  const Volume._(this.cubicMeters);

  final Decimal cubicMeters;

  factory Volume.cubicMeters(Decimal value) => Volume._(value);

  Volume times(Decimal factor) => Volume._(cubicMeters * factor);

  @override
  int compareTo(Volume other) => cubicMeters.compareTo(other.cubicMeters);

  @override
  bool operator ==(Object other) =>
      other is Volume && other.cubicMeters == cubicMeters;

  @override
  int get hashCode => cubicMeters.hashCode;

  @override
  String toString() => '${cubicMeters.toString()} m³';
}
