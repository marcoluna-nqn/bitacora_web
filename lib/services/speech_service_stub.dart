import 'package:flutter/widgets.dart';
import 'speech_port.dart';

class _SpeechStub implements SpeechPort {
  @override
  String? get currentLocale => null;
  @override
  bool get isAvailable => false;
  @override
  bool get isListening => false;

  @override
  Future<bool> init({String? preferredLocale}) async => false;

  @override
  Future<String?> listenOnce({
    String? localeId,
    ValueChanged<String>? partial,
    ValueChanged<double>? level,
    Duration autoTimeout = const Duration(seconds: 60),
  }) async => null;

  @override
  Future<void> fillControllerOnce(
      TextEditingController controller, {
        String? localeId,
        Duration autoTimeout = const Duration(seconds: 60),
      }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

/// Fábrica por defecto cuando no hay impl específica disponible.
SpeechPort createSpeechImpl() => _SpeechStub();
