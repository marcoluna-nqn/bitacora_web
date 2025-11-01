// lib/services/speech_impl_io.dart
// Android/iOS/desktop usando speech_to_text 6.x

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart'
    show TextEditingController, ValueChanged, TextSelection;
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'speech_port.dart';

class SpeechServiceIoImpl implements SpeechPort {
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _inited = false;
  bool _available = false;
  bool _listening = false;
  String? _localeId;

  @override
  String? get currentLocale => _localeId;
  @override
  bool get isAvailable => _available;
  @override
  bool get isListening => _listening;

  @override
  Future<bool> init({String? preferredLocale}) async {
    if (_inited) return _available;

    // Permiso de micrófono (silencioso si la plataforma no lo requiere).
    try {
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) {
        _inited = true;
        _available = false;
        return false;
      }
    } catch (_) {}

    try {
      _available = await _stt.initialize(
        onError: (e) {}, // sin spam en consola
        onStatus: (s) {},
      );

      if (_available) {
        final sys = await _stt.systemLocale();
        final locales = await _stt.locales();

        String? pick =
        (sys?.localeId?.isNotEmpty ?? false) ? sys!.localeId : null;

        // Español si existe
        pick ??= (() {
          final l = locales.firstWhere(
                (x) => x.localeId.toLowerCase().startsWith('es'),
            orElse: () => stt.LocaleName('', ''),
          );
          return l.localeId.isEmpty ? null : l.localeId;
        })();

        // Preferido exacto si está
        if (preferredLocale != null) {
          final variants = {
            preferredLocale,
            preferredLocale.replaceAll('_', '-'),
            preferredLocale.replaceAll('-', '_'),
          };
          final hit = locales.firstWhere(
                (l) => variants.contains(l.localeId),
            orElse: () => stt.LocaleName('', ''),
          );
          if (hit.localeId.isNotEmpty) pick ??= hit.localeId;
        }

        _localeId = pick ?? 'en_US';
      }
    } catch (_) {
      _available = false;
    } finally {
      _inited = true;
    }
    return _available;
  }

  @override
  Future<String?> listenOnce({
    String? localeId,
    ValueChanged<String>? partial,
    ValueChanged<double>? level,
    Duration autoTimeout = const Duration(seconds: 60),
  }) async {
    if (!await init(preferredLocale: localeId ?? _localeId)) return null;

    if (_listening) {
      await stop();
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }

    Future<String?> run(String? loc) async {
      final completer = Completer<String?>();
      String lastPartial = '';
      _listening = true;
      Timer? killer;

      try {
        final ok = await _stt.listen(
          localeId: loc,
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          onDevice: false,
          listenFor: autoTimeout,
          onResult: (res) {
            final txt = res.recognizedWords.trim();
            if (txt.isNotEmpty) {
              lastPartial = txt;
              partial?.call(txt);
            }
            if (res.finalResult && !completer.isCompleted) {
              completer.complete(txt);
            }
          },
          onSoundLevelChange: (raw) {
            final v = ((raw + 2.0) / 10.0).clamp(0.0, 1.0);
            level?.call(v);
          },
        );

        if (ok == false && !completer.isCompleted) completer.complete(null);

        killer = Timer(autoTimeout, () async {
          if (!completer.isCompleted) {
            completer.complete(lastPartial.isEmpty ? null : lastPartial);
          }
          await stop();
        });
      } on PlatformException {
        if (!completer.isCompleted) completer.complete(null);
      }

      final out = await completer.future;
      killer?.cancel();
      await stop();
      return out;
    }

    final a = await run(localeId ?? _localeId);
    if (a != null && a.isNotEmpty) return a;

    if ((localeId ?? _localeId) != null) {
      final b = await run(null);
      if (b != null && b.isNotEmpty) return b;
    }
    return await run('en_US');
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
    try {
      await _stt.stop();
    } catch (_) {} finally {
      _listening = false;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _stt.cancel();
    } catch (_) {} finally {
      _listening = false;
    }
  }
}

// Fábrica requerida por el facade condicional.
SpeechPort createSpeechImpl() => SpeechServiceIoImpl();
