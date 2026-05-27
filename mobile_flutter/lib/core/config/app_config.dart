import 'dart:io';

import 'package:flutter/foundation.dart';

class AppConfig {
  /// `--dart-define=API_BASE=http://192.168.1.5:8080/api/v1` ile fiziksel cihaz / özel ortam.
  static const String _fromEnv = String.fromEnvironment('API_BASE', defaultValue: '');

  /// Canlı sunucu URL'si (Render.com)
  static const String _productionUrl =
      'https://studysync-56nq.onrender.com/api/v1';

  /// Spring Boot iskeleti: `/api/v1` önekli.
  /// - **Android emülatör (debug):** `10.0.2.2` = geliştirme makinenin `localhost`'u.
  /// - **Release build:** Render.com üzerindeki canlı sunucu.
  /// - **Kendi Android telefonun (USB ile yükleme):** USB sadece `flutter run` / ADB içindir; HTTP istekleri
  ///   telefonun ağından gider. `10.0.2.2` **fiziksel cihazda çalışmaz**. Aynı Wi‑Fi'de PC IP'si kullan:
  ///   `flutter run --dart-define=API_BASE=http://192.168.x.x:8080/api/v1`
  /// - iOS simülatör / masaüstü: `localhost` genelde yeterli.
  static String get baseUrl {
    // 1) Compile-time override varsa onu kullan
    if (_fromEnv.isNotEmpty) return _fromEnv;

    // Local test modu: Hata ayıklama modunda yerel sunucuya, aksi halde canlıya bağlanır
    if (kDebugMode) {
      // 10.0.2.2 is the localhost loopback alias for Android Emulator
      return Platform.isAndroid ? 'http://10.0.2.2:8080/api/v1' : 'http://localhost:8080/api/v1';
    }
    return _productionUrl;
  }
}
