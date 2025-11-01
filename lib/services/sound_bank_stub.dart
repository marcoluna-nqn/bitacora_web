import 'sound_bank.dart';

class _SB implements SoundBank {
  @override
  Future<void> click() async {}

  @override
  Future<void> dispose() async {}
}

SoundBank getSoundBank() => _SB();
