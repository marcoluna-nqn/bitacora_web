// Web: implementación SpeechPort usando Web Speech API (SpeechRecognition / webkitSpeechRecognition).
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/widgets.dart';
import 'package:js/js_util.dart' as jsu;

import 'speech_port.dart';

class SpeechServiceWebImpl implements SpeechPort {
  bool _supported = false;
  bool _listening = false;
  String? _locale;

  // Referencia al recognizer activo para poder frenarlo antes de un nuevo start().
  dynamic _rec;

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
    ValueChanged<double>? level, // no hay nivel en Web Speech → ignorado
    Duration autoTimeout = const Duration(seconds: 60),
  }) async {
    final ok = await init(preferredLocale: localeId ?? _locale);
    if (!ok) return null;

    // Si ya hay una sesión, frenarla (evita InvalidStateError).
    await _safeStop();

    final lang = _norm(localeId) ?? _locale ?? 'es-AR';
    final ctor = _getRecognizerCtor();
    final rec = jsu.callConstructor(ctor, []);
    _rec = rec;

    jsu.setProperty(rec, 'lang', lang);
    jsu.setProperty(rec, 'continuous', false);
    jsu.setProperty(rec, 'interimResults', true);
    jsu.setProperty(rec, 'maxAlternatives', 1);

    final done = Completer<String?>();
    String lastPartial = '';
    _listening = true;

    // Timeout duro: si no hubo final, cerramos con el último parcial.
    Timer? killer = Timer(autoTimeout, () {
      try {
        jsu.callMethod(rec, 'stop', const []);
      } catch (_) {}
    });

    // onresult: tomar último result (interino o final).
    jsu.setProperty(rec, 'onresult', jsu.allowInterop((event) {
      try {
        final results = jsu.getProperty(event, 'results');
        final len = jsu.getProperty(results, 'length') as int;
        if (len <= 0) return;
        final last = jsu.getProperty(results, len - 1);
        final alt0 = jsu.getProperty(last, 0);
        final txt = (jsu.getProperty(alt0, 'transcript') as String? ?? '').trim();
        if (txt.isNotEmpty) {
          lastPartial = txt;
          partial?.call(txt);
        }
        final isFinal = (jsu.getProperty(last, 'isFinal') == true);
        if (isFinal && !done.isCompleted) {
          done.complete(txt);
        }
      } catch (_) {
        // Ignorar variaciones de eventos entre navegadores.
      }
    }));

    void finish() {
      killer?.cancel();
      _listening = false;
      _rec = null;
      if (!done.isCompleted) {
        done.complete(lastPartial.isEmpty ? null : lastPartial);
      }
    }

    // onend/onerror: cerrar de forma uniforme (sin castear el evento).
    jsu.setProperty(rec, 'onend', jsu.allowInterop((_) => finish()));
    jsu.setProperty(rec, 'onerror', jsu.allowInterop((_) => finish()));

    // start: requiere gesto de usuario (ya lo invocás desde un botón).
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
  Future<void> stop() => _safeStop();

  @override
  Future<void> cancel() => _safeStop();

  Future<void> _safeStop() async {
    if (_rec != null) {
      try {
        jsu.callMethod(_rec, 'stop', const []);
      } catch (_) {}
      // Pequeño delay para permitir que dispare onend y libere el estado.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      _rec = null;
    }
    _listening = false;
  }

  // --- helpers Web Speech
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

// Fábrica que consume el facade en Web.
SpeechPort createSpeechImpl() => SpeechServiceWebImpl();
