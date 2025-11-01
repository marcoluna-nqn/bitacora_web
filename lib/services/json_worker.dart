// lib/services/json_worker.dart
// Parser JSON no bloqueante (web-safe). Evita colgar la UI al importar backups grandes.

import 'dart:async' show Future, Completer, StreamSubscription;
import 'dart:convert' as convert;

class JsonWorker {
  // Si más adelante streameamos progreso, dejamos preparado el sub:
  StreamSubscription<dynamic>? _sub;

  JsonWorker();

  /// Parseo único de un JSON grande sin bloquear el primer frame.
  /// Devuelve el Map decodificado o lanza si el JSON es inválido.
  Future<Map<String, dynamic>> parseOnce(String text) {
    final completer = Completer<Map<String, dynamic>>();

    // Dejamos que el event loop respire antes de parsear.
    Future<void>(() {
      try {
        final decoded = convert.jsonDecode(text);
        if (decoded is Map<String, dynamic>) {
          if (!completer.isCompleted) completer.complete(decoded);
        } else {
          if (!completer.isCompleted) {
            completer.completeError(
              FormatException(
                  'El JSON raíz debe ser un objeto (Map<String,dynamic>).'),
            );
          }
        }
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });

    return completer.future;
  }

  /// Limpia recursos si se usan streams en el futuro.
  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
