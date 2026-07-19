import 'app/flavor.dart';
import 'bootstrap.dart';

/// PROD girişi.
///
/// **AĞ KATMANI KAPALI (`apiBaseUrl: ''`).** Bu bilinçli ve geçici.
///
/// Burada `https://api.nocta.app` yazıyordu. O alan bizim değil: DNS
/// doğrulandığında `nocta.app` A kaydının Vercel'e, `api.nocta.app`'in ise
/// SAHİPSİZ bir herokudns CNAME'ine gittiği görüldü. Yani kurulan her prod APK,
/// cihaz parmak izini ve anonim oturum token'larını üçüncü bir tarafın istediği
/// an devralabileceği bir hosta yolluyordu (CLAUDE.md §6 ihlali).
///
/// Adres boş bırakıldığında `NoctaApiClient` hiçbir soket açmaz; uygulama APK'ya
/// gömülü içerik kütüphanesiyle (`assets/content/library.json`) ve tamamen
/// on-device ses motoruyla çalışır.
///
/// **AÇMAK İÇİN:** aşağıdaki `apiBaseUrl` alanına gerçekten sahip olduğumuz
/// adresi yaz. Tek satır; başka hiçbir yerde değişiklik gerekmez.
void main() {
  bootstrap(
    const FlavorConfig(
      flavor: Flavor.prod,
      name: 'PROD',
      apiBaseUrl: '',
    ),
  );
}
