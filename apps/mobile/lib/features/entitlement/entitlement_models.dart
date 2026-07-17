/// Kullanıcının premium yetkilendirmesi (docs/02 §183). API `GET /v1/me/entitlement`
/// yanıtının mobil görünümü. Bugün sunucu stub'ı herkese premium döner (B1); gerçek
/// IAP (docs/10) bağlandığında bu tip değişmez — yalnızca sunucu değeri değişir.
class Entitlement {
  const Entitlement({required this.tier, required this.premium});

  /// free | plus | lifetime.
  final String tier;

  /// Premium kapısı — istemci gating'i buna bakar (plus/lifetime → true).
  /// Sunucudan TÜRETİLMİŞ gelir; istemci `tier`den yeniden hesaplamaz ki "premium ne
  /// demek" tek yerde (sunucuda) kalsın.
  final bool premium;

  factory Entitlement.fromJson(Map<String, dynamic> json) => Entitlement(
        tier: json['tier'] as String,
        premium: json['premium'] as bool,
      );
}
