import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';

/// Archetype slug → kimlik gradyanı — **tek kaynak** (#178).
///
/// Viral kancalar kullanıcının KENDİ arketip gradyanını göstermeli: gece raporu kartı
/// (#2), mix-to-video export (#3), kimlik kartı. Önceden bu üç yer bağımsızdı ve ikisi
/// sabit `overthinker` gradyanı kodluyordu → her kullanıcının paylaştığı içerik kimliğinden
/// bağımsız aynı görünüyordu, "sleep identity" markasını baltalıyordu.
///
/// Bilinmeyen / null slug → jenerik varsayılan: yeni bir archetype eklenince UI çökmez,
/// kullanıcı henüz test yapmadıysa (slug null) nötr bir gradyan görür.
LinearGradient archetypeGradientForSlug(String? slug) {
  switch (slug) {
    case 'deep-ocean':
      return NoctaArchetypeGradient.deepOcean;
    case 'overthinker':
      return NoctaArchetypeGradient.overthinker;
    case 'delta-drifter':
      return NoctaArchetypeGradient.deltaDrifter;
    case 'dawn-chaser':
      return NoctaArchetypeGradient.dawnChaser;
    default:
      return NoctaArchetypeGradient.overthinker;
  }
}
