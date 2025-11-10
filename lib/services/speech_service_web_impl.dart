// Web: usa speech_to_text_web bajo el hood.
// Evita doble-start y maneja timeout/partials.

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'speech_port.dart';

class SpeechService implements SpeechPort {
  SpeechService._();
  static final SpeechService I = SpeechService._();

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _available = false;
  bool _isListening = false;
  bool _busy = false;
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
      // init (con onError defensivo para web)
      _available = await _speech.initialize(
        onError: (e) {
          _isListening = false;
          _busy = false;
        },
        onStatus: (s) {
          if (s == 'notListening' || s == 'done') {
            _isListening = false;
            _busy = false;
          }
        },
      );

      if (!_available) return false;

      // Selección de locale más cercana
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
    if (!kIsWeb) return null; // este archivo es solo web
    if (!_available) return null;

    // Evitar superposición
    if (_isListening || _busy) {
      try { await _speech.cancel(); } catch (_) {}
      _isListening = false;
      _busy = false;
    }

    _busy = true;
    _isListening = true;
    _lastPartial = null;

    final completer = Completer<String?>();
    Timer? to;

    void finish([String? value]) async {
      if (to != null && to!.isActive) to!.cancel();
      if (_isListening) {
        try { await _speech.stop(); } catch (_) {}
      }
      _isListening = false;
      _busy = false;
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
          // Normaliza a 0..1 (el plugin puede dar 0..50 aprox en web)
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
    _busy = false;
  }

  @override
  Future<void> cancel() async {
    try { await _speech.cancel(); } catch (_) {}
    _isListening = false;
    _busy = false;
  }
}
