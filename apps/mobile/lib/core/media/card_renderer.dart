/// Widget → PNG baytları (paylaşılabilir görsel).
///
/// **NEDEN VAR:** üç viral kanca (kimlik kartı, gece raporu, mix-to-video) da
/// "widget'ı görsele çevir"e dayanıyor (docs/04 §103) ve bu yol depoda hiç yoktu —
/// sıfır `RepaintBoundary`, sıfır golden test. Lansman öncesi stratejinin tamamı buna
/// bağlı.
///
/// ## Neden widget'ı ağaçta gizlemiyoruz (denendi, İKİ KEZ patladı)
///
/// İlk denemeler kartı ekranda gizli tutup `RepaintBoundary`'sini yakalamaktı:
///
/// 1. `Offstage` → **boyamayı ATLAR** → `toImage()` şu assert'le düşer:
///    `'!debugNeedsPaint': is not true`. (Aynı sebeple `Opacity(0)` da olmaz.)
/// 2. Ekran dışına `Positioned(left: -4000)` → Flutter görünür alanın tamamen
///    dışındaki çocukları boyamıyor → **aynı assert**.
///
/// Yani "gizli ama boyanan widget" diye bir şey yok: gizlemenin her yolu boyamayı
/// kesiyor — ki `toImage`'in ihtiyacı tam olarak boyanmış olması.
///
/// **Çözüm:** widget'ı ağaçtan BAĞIMSIZ, kendi render hattında çiz. Kart hiçbir zaman
/// ekranda olmaz, olması da gerekmez — o bir ÇIKTI, ekran değil. Ek fayda: çıktı
/// gerçek ekran boyutundan tamamen bağımsız (paylaşılan görsel her cihazda aynı).
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Instagram story boyutu (docs/04 §103). Kare varyant sonra.
const Size shareCardSize = Size(1080, 1920);

/// Render süresi bütçesi — docs/04 §105 M1 çıkış kriteri: **< 300ms**.
const Duration shareCardRenderBudget = Duration(milliseconds: 300);

/// Render sonucu: baytlar + gerçekte ne kadar sürdüğü.
///
/// Süreyi DÖNDÜRMEK zorunlu: çıkış kriteri "kart render'ı < 300ms" diyor ama bugüne
/// dek **ölçülemiyordu bile**. Ölçülmeyen bütçe, bütçe değil temennidir.
class RenderedCard {
  const RenderedCard({required this.pngBytes, required this.elapsed});

  final Uint8List pngBytes;
  final Duration elapsed;

  /// M1 çıkış kriterini karşılıyor mu (docs/04 §105).
  bool get withinBudget => elapsed <= shareCardRenderBudget;
}

/// [widget]'ı [size] boyutunda, ekrandan bağımsız olarak PNG'ye çevirir.
///
/// [pixelRatio] 1.0 → [size] birebir piksel boyutu verir (1080×1920).
///
/// Hata durumunda **FIRLATIR** — sessizce null dönmek, kullanıcıya "paylaş"a basınca
/// hiçbir şey olmayan bir buton bırakırdı. Çağıran kartsız paylaşıma düşebilir.
Future<RenderedCard> renderWidgetToPng(
  Widget widget, {
  Size size = shareCardSize,
  double pixelRatio = 1.0,
}) async {
  final sw = Stopwatch()..start();
  final bytes = await _renderWidget(widget, size, pixelRatio, ui.ImageByteFormat.png);
  sw.stop();
  return RenderedCard(pngBytes: bytes, elapsed: sw.elapsed);
}

/// [widget]'ı ham RGBA8888 baytlarına çevirir (width*height*4).
///
/// **NEDEN AYRI:** mix-to-video kareleri video kodlayıcıya beslenir, dosyaya yazılmaz.
/// Her kareyi PNG'ye SIKIŞTIRIP native tarafta AÇMAK saf israf olurdu — saniyede 30
/// kez, kare başına 8 MB. Kodlayıcının istediği zaten ham piksel.
Future<Uint8List> renderWidgetToRgba(
  Widget widget, {
  required Size size,
  double pixelRatio = 1.0,
}) =>
    _renderWidget(widget, size, pixelRatio, ui.ImageByteFormat.rawRgba);

Future<Uint8List> _renderWidget(
  Widget widget,
  Size size,
  double pixelRatio,
  ui.ImageByteFormat format,
) async {
  final view = WidgetsBinding.instance.platformDispatcher.implicitView;
  if (view == null) {
    throw StateError('Kart render edilemedi: platform view yok.');
  }

  final boundary = RenderRepaintBoundary();
  final renderView = RenderView(
    view: view,
    child: RenderPositionedBox(alignment: Alignment.center, child: boundary),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(size),
      physicalConstraints: BoxConstraints.tight(size * pixelRatio),
      devicePixelRatio: pixelRatio,
    ),
  );

  final pipelineOwner = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();

  final buildOwner = BuildOwner(focusManager: FocusManager());
  final element = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    // Kök `Directionality` şart: ağaçta MaterialApp yok, miras alınacak yön de yok.
    child: Directionality(textDirection: TextDirection.ltr, child: widget),
  ).attachToRenderTree(buildOwner);

  try {
    buildOwner
      ..buildScope(element)
      ..finalizeTree();
    pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();

    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: format);
      if (data == null) {
        throw StateError('Kart render edilemedi: kodlama boş döndü.');
      }
      return data.buffer.asUint8List();
    } finally {
      // GPU belleği: bırakılmazsa her paylaşımda bir görsel sızar.
      image.dispose();
    }
  } finally {
    pipelineOwner.rootNode = null;
  }
}
