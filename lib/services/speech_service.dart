// lib/services/speech_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  SpeechService._();
  static final SpeechService I = SpeechService._();

  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _inited = false;
  bool _available = false;
  bool _listening = false;
  String? _localeId;

  bool get isAvailable => _available;
  bool get isListening => _listening;
  String? get currentLocale => _localeId;

  /// Inicializa STT y elige un locale (sistema → español → preferred → en_US).
  Future<bool> init({String? preferredLocale}) async {
    if (_inited) return _available;

    // En Web no pedimos permiso con permission_handler (el browser lo maneja).
    if (!kIsWeb) {
      try {
        final mic = await Permission.microphone.request();
        if (!mic.isGranted) {
          _inited = true;
          _available = false;
          return false;
        }
      } catch (_) {
        // Si el plugin no está disponible en alguna plataforma, continuamos.
      }
    }

    try {
      _available = await _stt.initialize(
        onError: (e) => debugPrint('STT error: $e'),
        onStatus: (s) => debugPrint('STT status: $s'),
      );

      if (_available) {
        final sys = await _stt.systemLocale();
        final locales = await _stt.locales();

        String? pick;

        // 1) locale del sistema
        if (sys?.localeId != null && sys!.localeId.isNotEmpty) {
          pick = sys.localeId;
        }

        // 2) español cualquiera
        pick ??= locales
            .where((l) => l.localeId.toLowerCase().startsWith('es'))
            .map((l) => l.localeId)
            .cast<String?>()
            .firstOrNull;

        // 3) preferido exacto si está
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

        // 4) fallback final
        pick ??= 'en_US';

        _localeId = pick;
        debugPrint('STT locale seleccionado: $_localeId');
      }
    } catch (e) {
      debugPrint('STT init failed: $e');
      _available = false;
    } finally {
      _inited = true;
    }
    return _available;
  }

  /// Escucha una sola vez. Devuelve el texto final (o parcial si hay timeout).
  Future<String?> listenOnce({
    String? localeId,
    ValueChanged<String>? partial,
    ValueChanged<double>? level, // nivel 0..1 para UI
    Duration autoTimeout = const Duration(seconds: 60),
  }) async {
    // Pasamos hint de locale al init para elegir mejor variante.
    if (!await init(preferredLocale: localeId ?? _localeId)) return null;

    if (_listening) {
      await stop();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    Future<String?> run(String? loc) async {
      final completer = Completer<String?>();
      String lastPartial = '';
      _listening = true;
      Timer? killer;

      try {
        final ok = await _stt.listen(
          localeId: loc,
          // API 6.x: parámetros directos (no SpeechListenOptions)
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          onDevice: false,
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

        if (ok == false && !completer.isCompleted) {
          completer.complete(null);
        }

        // Timeout externo (cierra con parcial si lo hay).
        killer = Timer(autoTimeout, () async {
          if (!completer.isCompleted) {
            completer.complete(lastPartial.isEmpty ? null : lastPartial);
          }
          await stop();
        });
      } on PlatformException catch (e) {
        debugPrint('STT listen error: $e');
        if (!completer.isCompleted) completer.complete(null);
      }

      final result = await completer.future;
      killer?.cancel();
      await stop();
      return result;
    }

    // 1) con locale elegido
    final first = await run(localeId ?? _localeId);
    if (first != null && first.isNotEmpty) return first;

    // 2) sin locale (deja que el servicio decida)
    if ((localeId ?? _localeId) != null) {
      debugPrint('STT retry con locale = null');
      final second = await run(null);
      if (second != null && second.isNotEmpty) return second;
    }

    // 3) último recurso: en_US
    return await run('en_US');
  }

  /// Rellena un TextEditingController con dictado en vivo (parciales) y final.
  Future<void> fillControllerOnce(
      TextEditingController controller, {
        String? localeId,
        Duration autoTimeout = const Duration(seconds: 60),
      }) async {
    await listenOnce(
      localeId: localeId,
      autoTimeout: autoTimeout,
      partial: (txt) {
        controller.text = txt;
        controller.selection = TextSelection.collapsed(offset: txt.length);
      },
    );
  }

  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {
      // no-op
    } finally {
      _listening = false;
    }
  }

  Future<void> cancel() async {
    try {
      await _stt.cancel();
    } catch (_) {
      // no-op
    } finally {
      _listening = false;
    }
  }
}

extension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
