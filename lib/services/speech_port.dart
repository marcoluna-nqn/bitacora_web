// Interfaz común para voz (Web / IO).
import 'dart:async';
import 'package:flutter/material.dart';

abstract class SpeechPort {
  String? get currentLocale;
  bool get isAvailable;
  bool get isListening;

  Future<bool> init({String? preferredLocale});
  Future<String?> listenOnce({
    String? localeId,
    ValueChanged<String>? partial,
    ValueChanged<double>? level,
    Duration autoTimeout = const Duration(seconds: 60),
  });

  Future<void> fillControllerOnce(
      TextEditingController controller, {
        String? localeId,
        Duration autoTimeout = const Duration(seconds: 60),
      });

  Future<void> stop();
  Future<void> cancel();
}
