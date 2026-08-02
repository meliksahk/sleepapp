import 'dart:io';

import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

/// Desteklenen ses uzantıları.
///
/// Jenerik "her dosya" modu DEĞİL, açık bir liste — iki kazancı var: seçicide
/// kullanıcı zaten çalamayacağımız dosyaları GÖRMEZ (hata göstermekten iyidir),
/// ve uzantı diskte korunduğu için ExoPlayer/AVFoundation biçim sezerken ona
/// güvenebilir.
const List<String> kSupportedAudioExtensions = <String>[
  'mp3',
  'm4a',
  'aac',
  'wav',
  'ogg',
  'opus',
  'flac',
];

/// Kullanıcının seçtiği dosya — henüz BİZE ait değil, yalnızca okunabilir bir yol.
class PickedSound {
  const PickedSound({
    required this.path,
    required this.displayName,
    required this.sizeBytes,
  });

  final String path;
  final String displayName;
  final int sizeBytes;
}

/// Dosya seçme yeteneği — **arayüz, çünkü testler eklentiye ASLA dokunmamalı.**
///
/// `flutter test` içinde platform kanalı yoktur; üretim uygulamasını doğrudan
/// çağıran bir test `MissingPluginException` alır. Bu arayüz, ithal akışının
/// tamamının (sıra, kapılar, geri alma) eklentisiz test edilmesini sağlar.
abstract class SoundPicker {
  /// Kullanıcı vazgeçerse **null** — bu bir hata değildir.
  /// Seçici açılamazsa [SoundPickerException] atar.
  Future<PickedSound?> pick();
}

class SoundPickerException implements Exception {
  const SoundPickerException(this.message);
  final String message;
  @override
  String toString() => 'SoundPickerException: $message';
}

/// Üretim uygulaması — Android'de Storage Access Framework, iOS'ta
/// UIDocumentPickerViewController.
///
/// **İzin gerektirmez ve istemez.** SAF'ın `ACTION_OPEN_DOCUMENT` akışında
/// kullanıcının seçim yapması iznin KENDİSİDİR; `READ_MEDIA_AUDIO` /
/// `READ_EXTERNAL_STORAGE` eklemek gereksiz olurdu ve mağaza incelemesinde
/// gerekçe isteyen bir izin olurdu. Eklentinin kendi manifesti de boştur
/// (doğrulandı); `android_manifest_test` bu izinlerin GİRMEDİĞİNİ kilitler.
class FileDialogSoundPicker implements SoundPicker {
  const FileDialogSoundPicker();

  @override
  Future<PickedSound?> pick() async {
    final String? path;
    try {
      path = await FlutterFileDialog.pickFile(
        params: const OpenFileDialogParams(
          fileExtensionsFilter: kSupportedAudioExtensions,
          mimeTypesFilter: <String>['audio/*'],
          // OFFLINE-FIRST KAPISI: bulut sağlayıcıların (Drive, Dropbox) sanal
          // dosyaları elenir. Onlar indirilmeyi bekleyen URI'lerdir; gece
          // uçak modunda çalmayan bir katman üretirlerdi.
          localOnly: true,
          // Eklenti dosyayı önce uygulama cache'ine kopyalar ve o yolu döndürür.
          // BEDELİ: 50 MB'lık dosyada anlık ~2× disk (cache kopyası + bizimki).
          // Karşılığında elimizde SAF izninden bağımsız, doğrudan okunabilir bir
          // yol olur; cache kopyasını biz kendi kopyamızı aldıktan sonra sileriz.
          copyFileToCacheDir: true,
        ),
      );
    } on MissingPluginException catch (e) {
      // PlatformException'dan ÖNCE: ayrı bir tip ama sıralamayı açıkça
      // sabitliyoruz ki ileride biri yer değiştirdiğinde sessizce yutulmasın.
      throw SoundPickerException('eklenti yok: ${e.message}');
    } on PlatformException catch (e) {
      throw SoundPickerException('${e.code}: ${e.message}');
    }

    if (path == null) return null; // kullanıcı vazgeçti

    final file = File(path);
    if (!file.existsSync()) {
      throw const SoundPickerException('seçilen dosya okunamadı');
    }

    return PickedSound(
      path: path,
      displayName: _baseName(path),
      sizeBytes: file.lengthSync(),
    );
  }

  /// Yol ayracına göre son parça. `p.basename` yerine elle: gelen yol PLATFORM
  /// yolu olmayabilir (eklenti Android'de POSIX döner, testler Windows'ta koşar),
  /// ikisini de kesmek istiyoruz.
  static String _baseName(String path) {
    final cut = path.lastIndexOf(RegExp(r'[/\\]'));
    return cut < 0 ? path : path.substring(cut + 1);
  }
}

/// Testlerin kullandığı seçici. Üretim yolunu hiç çalıştırmadan tüm akışı sürer.
class FakeSoundPicker implements SoundPicker {
  FakeSoundPicker({this.result, this.throws});

  PickedSound? result;
  Object? throws;
  int callCount = 0;

  @override
  Future<PickedSound?> pick() async {
    callCount++;
    if (throws != null) throw throws!;
    return result;
  }
}
