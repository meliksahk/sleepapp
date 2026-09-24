import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// just_audio çalma listesi yüzeyi. `MixPlayer`'ın sonsuz uzatma yolu bunu
/// kullanır: ilk parçadan sonraki parçaları listeye ekler, çalınanları çıkarır.
///
/// Testlerin sahte player'ları bu karışımı alır (`with FakePlaylistPlayer`);
/// eklenen ve çıkarılan kaynaklar kaydedilir, çaların sıradaki parçaya geçişi
/// [emitCurrentIndex] ile taklit edilir. Geçiş taklit edilmezse besleyici
/// yalnız ikinci parçayı ekler ve bekler; sonsuz uzatmayla ilgilenmeyen testler
/// için davranış eskisinin aynısıdır.
mixin FakePlaylistPlayer {
  /// `addAudioSource` ile eklenen kaynaklar, sırasıyla.
  final List<AudioSource> appendedSources = <AudioSource>[];

  /// `removeAudioSourceAt` çağrılarının indeksleri, sırasıyla.
  final List<int> removedIndices = <int>[];

  final StreamController<int?> _currentIndex = StreamController<int?>.broadcast();

  Stream<int?> get currentIndexStream => _currentIndex.stream;

  Future<void> addAudioSource(AudioSource audioSource) async {
    appendedSources.add(audioSource);
  }

  Future<void> removeAudioSourceAt(int index) async {
    removedIndices.add(index);
  }

  /// Çaların çalma listesinde [index]'e geçtiğini bildirir.
  void emitCurrentIndex(int? index) => _currentIndex.add(index);
}
