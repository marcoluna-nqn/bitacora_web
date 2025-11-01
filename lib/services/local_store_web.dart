import "dart:convert";
import "dart:html" as html;
import "../models/table_state.dart";

class LocalStore {
  static const _key = "bitacora_state_v1";

  static Future<void> save(TableState state) async {
    html.window.localStorage[_key] = jsonEncode(state.toJson());
  }

  static Future<TableState?> load() async {
    final raw = html.window.localStorage[_key];
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return TableState.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    html.window.localStorage.remove(_key);
  }

  static Future<void> downloadBackup(TableState state,
      {String filename = "bitacora_backup.json"}) async {
    final data = utf8.encode(jsonEncode(state.toJson()));
    final blob = html.Blob([data], "application/json");
    final url = html.Url.createObjectUrlFromBlob(blob);
    final a = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = "none";
    html.document.body?.append(a);
    a.click();
    a.remove();
    html.Url.revokeObjectUrl(url);
  }

  static Future<TableState?> importBackup() async {
    final input = html.FileUploadInputElement()
      ..accept = ".json,application/json";
    input.click();
    await input.onChange.first;
    final file = input.files?.first;
    if (file == null) return null;
    final reader = html.FileReader()..readAsText(file);
    await reader.onLoad.first;
    final map = jsonDecode(reader.result as String) as Map<String, dynamic>;
    return TableState.fromJson(map);
  }
}
