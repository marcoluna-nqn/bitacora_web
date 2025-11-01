// Selector de efectos de sonido.
import 'sound_bank_stub.dart'
if (dart.library.html) 'sound_bank_web.dart';

abstract class SoundBank {
  Future<void> click();
  Future<void> dispose();
}

SoundBank getSoundBank();
