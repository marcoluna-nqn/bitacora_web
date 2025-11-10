import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/table_state.dart';
import 'save_file.dart';

class LocalStore {
  static const String key = 'gridnote:current';

  static Future<void> save(TableState s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, s.toJsonString());
  }

  static Future<TableState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    return TableState.fromJsonString(raw);
  }

  static Future<void> downloadBackup(TableState s) async {
    final name =
        'bitacora_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    await saveBytes(name, utf8.encode(s.toJsonString()));
  }

  static Future<TableState?> importBackup() async {
    if (kIsWeb) {
      final raw = await pickTextFileWeb();
      if (raw == null) return null;
      return TableState.fromJsonString(raw);
    } else {
      final uri = Uri(
        scheme: 'mailto',
        queryParameters: {
          'subject': 'Importar backup - Instrucciones',
          'body':
              'En esta versión, importar backup está disponible en Web. En móvil/desktop usá Exportar y reenviá el archivo.'
        },
      );
      await launchUrl(uri);
      return null;
    }
  }
}
