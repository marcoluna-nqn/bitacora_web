import 'dart:io';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

final class MailShare {
  MailShare._();

  /// Intenta en orden:
  /// 1) flutter_email_sender con adjunto.
  /// 2) mailto: (sin adjunto, incluye ruta en el cuerpo).
  /// 3) share_plus con el archivo.
  static Future<void> sendFile({
    required String filePath,
    String? to,
    String? subject,
    String? body,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return;

    // 1) Email nativo con adjunto.
    try {
      final email = Email(
        recipients: to == null || to.isEmpty ? [] : [to],
        subject: subject ?? '',
        body: body ?? '',
        attachmentPaths: [filePath],
        isHTML: false,
      );
      await FlutterEmailSender.send(email);
      return;
    } catch (_) {
      // Ignoro, pruebo siguiente.
    }

    // 2) mailto: (no soporta adjuntos, agrego path en el cuerpo).
    try {
      final uri = Uri(
        scheme: 'mailto',
        path: to ?? '',
        queryParameters: {
          if (subject != null) 'subject': subject,
          'body': _joinBody(body, '\n\nAdjunto: $filePath'),
        },
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {
      // Ignoro, pruebo siguiente.
    }

    // 3) share_plus del archivo.
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        text: body ?? '',
        subject: subject,
      );
    } catch (_) {
      // No hay más fallback razonable.
    }
  }

  static String _joinBody(String? a, String b) {
    if (a == null || a.isEmpty) return b;
    return '$a$b';
    // Sin saltos extra para mantenerlo limpio.
  }
}
