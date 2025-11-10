// lib/platform/platform_interop.dart
// Adaptador de interop Web con imports condicionales. En mobile/desktop es stub.

import 'platform_interop_stub.dart'
if (dart.library.html) 'platform_interop_web.dart';

abstract class PlatformInterop {
  bool get isWeb;

  /// Suscribe callback a eventos de voz.
  void addSpeechListener(void Function(String text) onText);

  /// Suscribe callback a eventos de GPS (recibe payload ya formateado).
  void addGpsListener(void Function(String payload) onPayload);

  /// Limpia todos los listeners.
  void removeListeners();

  /// Dispara solicitud de GPS en Web (equivalente a 'bitacora:askGps').
  void requestGps();

  /// Alterna dictado en Web (equivalente a 'bitacora:toggleMic').
  void toggleMic();
}

PlatformInterop createPlatformInterop();
