// Android/iOS/desktop: speech_to_text 6.x
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'speech_service.dart';

class _SpeechServiceIO implements SpeechService {
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
    try {
      _available = await _stt.initialize(
        onError: (e) => debugPrint('STT error: $e'),
        onStatus: (s) => debugPrint('STT status: $s'),
      );
      if (_available) {
        final sys = await _stt.systemLocale();
        final locales = await _stt.locales();

        String? pick = sys?.localeId;
        pick ??= locales
            .where((l) => l.localeId.toLowerCase().startsWith('es'))
            .map((l) => l.localeId)
            .cast<String?>()
            .firstWhere((e) => e != null && e.isNotEmpty, orElse: () => null);

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
          if (hit.localeId.isNotEmpty) pick = hit.localeId;
        }

        _localeId = pick ?? 'en_US';
      }
    } catch (e) {
      debugPrint('STT init failed: $e');
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
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    final completer = Completer<String?>();
    String lastPartial = '';
    _listening = true;
    Timer? killer;

    try {
      final ok = await _stt.listen(
        localeId: localeId ?? _localeId,
        listenFor: autoTimeout,
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
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
          if (level != null) {
            final v = ((raw + 2.0) / 10.0).clamp(0.0, 1.0);
            level(v);
          }
        },
      );

      if (ok == false && !completer.isCompleted) completer.complete(null);

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

    final out = await completer.future;
    killer?.cancel();
    await stop();
    return out;
  }

  @override
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

SpeechService getSpeechService() => _SpeechServiceIO();
