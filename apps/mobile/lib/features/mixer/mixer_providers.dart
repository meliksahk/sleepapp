import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'data/audio_probe.dart';
import 'data/local_sound_library_impl.dart';
import 'data/sound_picker.dart';
import 'domain/local_sound_library.dart';

/// İthal seslerin yaşadığı dizin: `<appSupport>/nocta_sounds`.
///
/// **Neden `getApplicationSupportDirectory`:**
/// - `getApplicationDocumentsDirectory` DEĞİL — bunlar kullanıcının "belgeleri"
///   değil, uygulama verisi (iOS'ta Files uygulamasında görünmemeli).
/// - **cache DİZİNİ KESİNLİKLE DEĞİL.** mix-to-video mp4'ü orada doğru yaşıyor
///   (tek kullanımlık), ama ithal ses tam tersidir: işletim sistemi disk
///   baskısında cache'i temizler ve kullanıcının gece miksindeki ses sebepsiz
///   kaybolur — yani çözmeye çalıştığımız problemin ta kendisi geri gelir.
Future<Directory> defaultSoundDirectory() async {
  final base = await getApplicationSupportDirectory();
  return Directory(p.join(base.path, 'nocta_sounds'));
}

final soundPickerProvider = Provider<SoundPicker>(
  (ref) => const FileDialogSoundPicker(),
);

final audioProbeProvider = Provider<AudioProbe>(
  (ref) => const JustAudioProbe(),
);

/// Testlerde override edilen tek kapı.
///
/// ⚠️ **Widget testlerinde override ŞART.** Aksi hâlde `path_provider` platform
/// kanalına uzanır ve gerçek uygulama kabuğunu kuran her test
/// `MissingPluginException` ile düşer.
final localSoundLibraryProvider = Provider<LocalSoundLibrary>(
  (ref) => LocalSoundLibraryImpl(
    dir: defaultSoundDirectory,
    picker: ref.watch(soundPickerProvider),
    probe: ref.watch(audioProbeProvider),
  ),
);

/// Kütüphanenin okunmuş hâli. `LocalSoundIndex` döner — "boş" ile "okunamadı"
/// arasındaki ayrım UI'a kadar TAŞINIR (bkz. `LocalSoundIndex`).
final localSoundsProvider = FutureProvider<LocalSoundIndex>(
  (ref) => ref.watch(localSoundLibraryProvider).list(),
);

/// Sheet başlığında gösterilen disk kullanımı. Kopyalama yaklaşımının bedelini
/// GÖRÜNÜR kılar — kullanıcı ne harcadığını bilmeden silmeye karar veremez.
final localSoundsTotalProvider = FutureProvider<int>(
  (ref) async {
    // Liste değişince toplam da tazelensin.
    await ref.watch(localSoundsProvider.future);
    return ref.watch(localSoundLibraryProvider).totalBytes();
  },
);
