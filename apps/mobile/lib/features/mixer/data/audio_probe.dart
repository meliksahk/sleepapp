import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:just_audio/just_audio.dart';

import '../domain/local_sound.dart';

/// Bir dosyanın GERÇEKTEN çalınabilir olup olmadığını sınar.
///
/// ## Neden ayrı bir sınama — `MixerController.addAsset` neden yetmez
///
/// Cazip kestirme "kaydet, katman olarak ekle, tutmazsa geri al" olurdu. Çalışmaz:
/// `MixerController.addAsset` yükleme denemesini yalnızca `_player.voiceCount > 0`
/// iken yapar. Kullanıcı mikserde çal'a BASMADAN katalogtan ses eklerse (ki
/// katalog mikser açılır açılmaz erişilebilir) hiçbir doğrulama koşmaz ve bozuk
/// bir dosya kütüphaneye sessizce girer — kullanıcı onu gece çalmaya kalkınca
/// öğrenir.
///
/// ## Neden ENJEKTE EDİLEBİLİR — pazarlıksız
///
/// `flutter test` içinde just_audio'nun platform uygulaması YOKTUR. Üretim
/// sınayıcısını doğrudan çağıran bir test her dosya için `MissingPluginException`
/// alır; tipsiz bir `catch` bunu "bu dosya ses değil" diye sınıflandırır ve
/// mutlu-yol testlerinin TAMAMI kırmızı kalır. Bu yüzden hata sınıflandırması
/// TİPLİ ve sınayıcı `MixPlayer.playerFactory` deseniyle aynı biçimde enjekte
/// edilebilir.
abstract class AudioProbe {
  /// Çalınabiliyorsa sessizce döner; değilse [LocalSoundImportFailure] atar.
  Future<void> probe(String path);
}

/// Üretim: kısa ömürlü bir `AudioPlayer` açar, kaynağı çözdürür, kapatır.
class JustAudioProbe implements AudioProbe {
  const JustAudioProbe({this.playerFactory});

  /// Test/enstrümantasyon dikişi — `MixPlayer` ile aynı desen.
  final AudioPlayer Function()? playerFactory;

  @override
  Future<void> probe(String path) async {
    final player = (playerFactory ?? AudioPlayer.new)();
    try {
      // setAudioSource kaynağı GERÇEKTEN çözer (süre döner); biçim
      // desteklenmiyorsa burada atar. Çalmaya gerek yok.
      await player.setAudioSource(AudioSource.file(path));
    } on PlayerException catch (e) {
      debugPrint('nocta.localsound: çalınamadı ($path): ${e.code} ${e.message}');
      throw LocalSoundImportFailure.notAudio;
    } on PlayerInterruptedException catch (e) {
      debugPrint('nocta.localsound: sınama yarıda kesildi ($path): $e');
      throw LocalSoundImportFailure.unknown;
    } on MissingPluginException catch (e) {
      // Platform yok (test/masaüstü). "Ses değil" DEĞİL — bunu notAudio saymak
      // yukarıda anlatılan tuzağın ta kendisidir.
      debugPrint('nocta.localsound: ses eklentisi yok: $e');
      throw LocalSoundImportFailure.unknown;
    } finally {
      // Sızıntı kapısı: sınayıcı player'ı HER dalda kapanır. Kapanmazsa her
      // ithal denemesi bir decoder sızdırır ve cihaz sınırına sessizce dayanırız.
      await player.dispose();
    }
  }
}

/// Test sınayıcısı. Varsayılan: her dosya çalınabilir.
class FakeAudioProbe implements AudioProbe {
  FakeAudioProbe({this.failWith});

  LocalSoundImportFailure? failWith;
  final List<String> probed = <String>[];

  @override
  Future<void> probe(String path) async {
    probed.add(path);
    if (failWith != null) throw failWith!;
  }
}
