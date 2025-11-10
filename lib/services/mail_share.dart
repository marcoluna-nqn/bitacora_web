// Enviar por correo con adjunto (.xlsx) usando flutter_email_sender.
// Fallback: mailto: (sin adjunto en Web) y Share.shareXFiles en móvil.

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;

Future<void> sendMailWithFile({
  required String filePath,
  required String subject,
  String body = '',
}) async {
  // 1) Nativo (Android / iOS)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      final email = Email(
        body: body,
        subject: subject,
        recipients: const [],
        attachmentPaths: filePath.isNotEmpty ? [filePath] : null,
        isHTML: false,
      );
      await FlutterEmailSender.send(email);
      return;
    } catch (_) {
      // sigue a fallback
    }
  }

  // 2) mailto: (abre cliente; en Web no adjunta)
  final mailto = Uri(
    scheme: 'mailto',
    queryParameters: {
      'subject': subject,
      'body': body,
    },
  );
  try {
    if (await canLaunchUrl(mailto)) {
      await launchUrl(mailto, mode: LaunchMode.externalApplication);
    }
  } catch (_) {
    // sigue a share
  }

  // 3) Share como último recurso (no disponible con archivo en Web)
  if (!kIsWeb && filePath.isNotEmpty) {
    try {
      final name = p.basename(filePath);
      await Share.shareXFiles(
        [
          XFile(
            filePath,
            name: name,
            mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          )
        ],
        text: subject,
      );
    } catch (_) {
      // silencioso
    }
  }
}
