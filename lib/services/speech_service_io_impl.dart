import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'speech_port.dart';

class SpeechService implements SpeechPort {
  SpeechService._();
  static final SpeechService I = SpeechService._();

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _available = false;
  bool _isListening = false;
  String? _currentLocale;
  String? _lastPartial;

  @override
  String? get currentLocale => _currentLocale;

  @override
  bool get isAvailable => _available;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> init({String? preferredLocale}) async {
    try {
      _available = await _speech.initialize(
        onError: (_) {
          _isListening = false;
        },
        onStatus: (s) {
          if (s == 'notListening' || s == 'done') _isListening = false;
        },
      );
      if (!_available) return false;

      final locales = await _speech.locales();
      String? pick = preferredLocale;
      if (preferredLocale != null) {
        final exact = locales.firstWhere(
              (l) => l.localeId.toLowerCase() == preferredLocale.toLowerCase(),
          orElse: () => stt.LocaleName(preferredLocale, preferredLocale),
        );
        pick = exact.localeId;
      } else {
        pick = (await _speech.systemLocale())?.localeId;
      }
      _currentLocale = pick;
      return true;
    } catch (_) {
      _available = false;
      return false;
    }
  }

  @override
  Future<String?> listenOnce({
    String? localeId,
    ValueChanged<String>? partial,
    ValueChanged<double>? level,
    Duration autoTimeout = const Duration(seconds: 60),
  }) async {
    if (!_available) return null;

    if (_isListening) {
      try { await _speech.cancel(); } catch (_) {}
      _isListening = false;
    }

    _isListening = true;
    _lastPartial = null;
    final completer = Completer<String?>();
    Timer? to;

    void finish([String? value]) async {
      if (to != null && to!.isActive) to!.cancel();
      try { await _speech.stop(); } catch (_) {}
      _isListening = false;
      if (!completer.isCompleted) completer.complete(value);
    }

    try {
      to = Timer(autoTimeout, () => finish(_lastPartial));

      await _speech.listen(
        localeId: localeId ?? _currentLocale,
        onResult: (r) {
          final text = r.recognizedWords.trim();
          if (text.isNotEmpty) {
            _lastPartial = text;
            partial?.call(text);
          }
          if (r.finalResult) finish(text.isNotEmpty ? text : _lastPartial);
        },
        listenMode: stt.ListenMode.dictation,
        onSoundLevelChange: (lv) {
          // En móvil suele venir 0..1 o 0..50; normalizamos.
          final norm = (lv / 50.0).clamp(0.0, 1.0);
          level?.call(norm);
        },
        cancelOnError: true,
        partialResults: true,
      );
    } catch (_) {
      finish(_lastPartial);
    }

    final res = await completer.future;
    return res?.isNotEmpty == true ? res : null;
  }

  @override
  Future<void> fillControllerOnce(
      TextEditingController controller, {
        String? localeId,
        Duration autoTimeout = const Duration(seconds: 60),
      }) async {
    final text = await listenOnce(
      localeId: localeId,
      autoTimeout: autoTimeout,
    );
    if (text == null || text.trim().isEmpty) return;
    final has = controller.text.trim().isNotEmpty;
    controller.text = has ? '${controller.text} $text' : text;
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
  }

  @override
  Future<void> stop() async {
    try { await _speech.stop(); } catch (_) {}
    _isListening = false;
  }

  @override
  Future<void> cancel() async {
    try { await _speech.cancel(); } catch (_) {}
    _isListening = false;
  }
}
