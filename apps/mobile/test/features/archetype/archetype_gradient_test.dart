import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/features/archetype/archetype_gradient.dart';

/// Archetype slug → gradyan eşlemesi (#178). Viral kancalar (gece raporu, mix-to-video,
/// kimlik kartı) kullanıcının KENDİ gradyanını gösterir; bu eşleme onun tek kaynağı.
void main() {
  test('ÇEKİRDEK: her archetype KENDİ gradyanını alır', () {
    expect(archetypeGradientForSlug('deep-ocean'), NoctaArchetypeGradient.deepOcean);
    expect(archetypeGradientForSlug('overthinker'), NoctaArchetypeGradient.overthinker);
    expect(archetypeGradientForSlug('delta-drifter'), NoctaArchetypeGradient.deltaDrifter);
    expect(archetypeGradientForSlug('dawn-chaser'), NoctaArchetypeGradient.dawnChaser);
  });

  test('ÇEKİRDEK: farklı arketipler FARKLI gradyan (kimlik gerçekten değişiyor)', () {
    // Eski hata: iki viral kanca sabit overthinker'ı kodluyordu → hepsi aynıydı.
    expect(
      archetypeGradientForSlug('deep-ocean') == archetypeGradientForSlug('dawn-chaser'),
      isFalse,
    );
  });

  test('bilinmeyen slug jenerik varsayılana düşer (yeni archetype eklenince çökmez)', () {
    expect(archetypeGradientForSlug('brand-new-archetype'), NoctaArchetypeGradient.overthinker);
  });

  test('null slug (kullanıcı henüz test yapmadı) varsayılana düşer', () {
    expect(archetypeGradientForSlug(null), NoctaArchetypeGradient.overthinker);
  });
}
