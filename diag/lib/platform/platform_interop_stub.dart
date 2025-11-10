// lib/platform/platform_interop_stub.dart
// Implementación nula para mobile/desktop. No hace nada.

import 'platform_interop.dart';

class _StubInterop implements PlatformInterop {
  @override
  bool get isWeb => false;

  @override
  void addSpeechListener(void Function(String) onText) {}

  @override
  void addGpsListener(void Function(String) onPayload) {}

  @override
  void removeListeners() {}

  @override
  void requestGps() {}

  @override
  void toggleMic() {}
}

PlatformInterop createPlatformInterop() => _StubInterop();
