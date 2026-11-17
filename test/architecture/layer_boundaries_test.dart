import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ustametre/domain/trade_category.dart';

/// Hesaplama motoru ve domain katmanı arayüzden bağımsız kalmalıdır.
void main() {
  test('engine ve domain katmanları Flutter içe aktarmaz', () {
    final forbidden = RegExp(
      r'''import\s+['"](package:(flutter|material_ui|cupertino_ui)/|dart:ui)''',
    );
    final offenders = <String>[];
    for (final dir in ['lib/engine', 'lib/domain']) {
      for (final entity in Directory(dir).listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          if (forbidden.hasMatch(entity.readAsStringSync())) {
            offenders.add(entity.path);
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: 'UI bağımlılığı bulunan dosyalar');
  });

  test('engine kodu double kullanmaz', () {
    final doubleUse = RegExp(r'\bdouble\b');
    final offenders = <String>[];
    for (final entity in Directory('lib/engine').listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final code = entity
            .readAsLinesSync()
            .map((line) => line.split('//').first)
            .join('\n');
        if (doubleUse.hasMatch(code)) {
          offenders.add(entity.path);
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('13 meslek kategorisi tanımlı, kimlikler benzersiz', () {
    final ids = TradeCategories.all.map((c) => c.id).toList();
    expect(ids, hasLength(13));
    expect(ids.toSet(), hasLength(13));
  });

  test('Sprint 3: yalnızca mermer ve PVC özel hesaplı olarak işaretli', () {
    // Bir kategorinin özel hesapları arayüze bağlanıp test edildiğinde bu
    // test güncellenmelidir.
    expect(TradeCategories.all.where((c) => c.isAvailable).map((c) => c.id), [
      'marble_granite',
      'pvc_joinery',
    ]);
  });
}
