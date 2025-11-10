// lib/platform/platform_interop_web.dart
// Implementación Web usando dart:html, aislada por import condicional.

import 'dart:html' as html;
import 'platform_interop.dart';

class _WebInterop implements PlatformInterop {
  html.EventListener? _speechListener;
  html.EventListener? _gpsListener;

  @override
  bool get isWeb => true;

  @override
  void addSpeechListener(void Function(String text) onText) {
    _speechListener = (e) {
      final ce = e is html.CustomEvent ? e : null;
      final detail = ce?.detail;
      String? text;
      if (detail is Map) {
        final t = detail['text'];
        if (t is String) text = t.trim();
      } else if (detail is String) {
        text = detail.trim();
      }
      if (text != null && text.isNotEmpty) {
        onText(text);
      }
    };
    html.window.addEventListener('bitacora:speech', _speechListener);
  }

  @override
  void addGpsListener(void Function(String payload) onPayload) {
    _gpsListener = (e) {
      final ce = e is html.CustomEvent ? e : null;
      final d = ce?.detail;
      String? payload;
      if (d is Map) {
        final t = d['text'];
        if (t is String && t.trim().isNotEmpty) {
          payload = t.trim();
        } else {
          final lat = (d['lat'] as num?)?.toDouble();
          final lon = (d['lon'] as num?)?.toDouble();
          final acc = (d['accuracy'] as num?)?.toDouble();
          if (lat != null && lon != null) {
            final buf = StringBuffer()
              ..write(lat.toStringAsFixed(6))
              ..write(', ')
              ..write(lon.toStringAsFixed(6));
            if (acc != null && acc > 0) {
              buf.write(' ±${acc.round()} m');
            }
            payload = buf.toString();
          }
        }
      } else if (d is String) {
        payload = d;
      }
      if (payload != null && payload.isNotEmpty) {
        onPayload(payload);
      }
    };
    html.window.addEventListener('bitacora:gps', _gpsListener);
  }

  @override
  void removeListeners() {
    if (_speechListener != null) {
      html.window.removeEventListener('bitacora:speech', _speechListener!);
      _speechListener = null;
    }
    if (_gpsListener != null) {
      html.window.removeEventListener('bitacora:gps', _gpsListener!);
      _gpsListener = null;
    }
  }

  @override
  void requestGps() {
    try {
      html.window.dispatchEvent(html.CustomEvent('bitacora:askGps'));
    } catch (_) {}
  }

  @override
  void toggleMic() {
    try {
      html.window.dispatchEvent(html.CustomEvent('bitacora:toggleMic'));
    } catch (_) {}
  }
}

PlatformInterop createPlatformInterop() => _WebInterop();
