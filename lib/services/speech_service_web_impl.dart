// Web: Web Speech API (SpeechRecognition / webkitSpeechRecognition).
import 'dart:async';
import 'dart:html' as html;
import 'package:js/js_util.dart' as jsu;
import 'package:flutter/widgets.dart';
import 'speech_service.dart';

class _SpeechServiceWeb implements SpeechService {
  bool _supported = false;
  bool _listening = false;
  String? _locale;

  @override
  String? get currentLocale => _locale;
  @override
  bool get isAvailable => _supported;
  @override
  bool get isListening => _listening;

  @override
  Future<bool> init({String? preferredLocale}) async {
    _supported = _hasRecognizerCtor();
    if (!_supported) return false;
    _locale = _norm(preferredLocale) ?? 'es-AR';
    return true;
  }

  @override
  Future<String?> listenOnce({
    String? localeId,
    ValueChanged<String>? partial,
    ValueChanged<double>? level,
    Duration autoTimeout = const Duration(seconds: 60),
  }) async {
    final ok = await init(preferredLocale: localeId ?? _locale);
    if (!ok) return null;

    final lang = _norm(localeId) ?? _locale ?? 'es-AR';
    final ctor = _getRecognizerCtor();
    final rec = jsu.callConstructor(ctor, []);

    jsu.setProperty(rec, 'lang', lang);
    jsu.setProperty(rec, 'continuous', false);
    jsu.setProperty(rec, 'interimResults', true);
    jsu.setProperty(rec, 'maxAlternatives', 1);

    final done = Completer<String?>();
    String lastPartial = '';
    _listening = true;

    Timer? killer = Timer(autoTimeout, () {
      jsu.callMethod(rec, 'stop', const []);
    });

    jsu.setProperty(rec, 'onresult', jsu.allowInterop((event) {
      try {
        final results = jsu.getProperty(event, 'results');
        final len = jsu.getProperty(results, 'length') as int;
        if (len <= 0) return;
        final last = jsu.getProperty(results, len - 1);
        final alt0 = jsu.getProperty(last, 0);
        final txt = (jsu.getProperty(alt0, 'transcript') as String?) ?? '';
        final t = txt.trim();
        if (t.isNotEmpty) {
          lastPartial = t;
          partial?.call(t);
        }
        final isFinal = (jsu.getProperty(last, 'isFinal') == true);
        if (isFinal && !done.isCompleted) done.complete(t);
      } catch (_) {}
    }));

    void finish() {
      killer?.cancel();
      if (!done.isCompleted) {
        done.complete(lastPartial.isEmpty ? null : lastPartial);
      }
      _listening = false;
    }

    jsu.setProperty(rec, 'onend', jsu.allowInterop((_) => finish()));
    jsu.setProperty(rec, 'onerror', jsu.allowInterop((_) => finish()));

    jsu.callMethod(rec, 'start', const []);
    return await done.future;
  }

  @override
  Future<void> fillControllerOnce(
      TextEditingController controller, {
        String? localeId,
        Duration autoTimeout = const Duration(seconds: 60),
      }) async {
    final txt = await listenOnce(
      localeId: localeId,
      autoTimeout: autoTimeout,
      partial: (s) {
        controller.text = s;
        controller.selection = TextSelection.collapsed(offset: s.length);
      },
    );
    if (txt != null) {
      controller.text = txt;
      controller.selection = TextSelection.collapsed(offset: txt.length);
    }
  }

  @override
  Future<void> stop() async {
    _listening = false;
  }

  @override
  Future<void> cancel() async {
    _listening = false;
  }

  bool _hasRecognizerCtor() {
    final w = html.window;
    final a = jsu.getProperty(w, 'SpeechRecognition');
    final b = jsu.getProperty(w, 'webkitSpeechRecognition');
    return a != null || b != null;
  }

  dynamic _getRecognizerCtor() {
    final w = html.window;
    return jsu.getProperty(w, 'SpeechRecognition') ??
        jsu.getProperty(w, 'webkitSpeechRecognition');
  }

  String? _norm(String? loc) =>
      (loc == null || loc.isEmpty) ? null : loc.replaceAll('_', '-');
}

SpeechService getSpeechService() => _SpeechServiceWeb();
