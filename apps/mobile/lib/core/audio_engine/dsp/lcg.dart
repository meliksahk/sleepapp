/// Deterministik sözde-rastgele üreteç (LCG).
///
/// `Random` yerine kullanılır çünkü golden testlerin **Dart sürümünden bağımsız**
/// olarak tekrarlanabilir olması gerekir.
///
/// **Neden ayrı dosyada, neden kopyalanmadı:** `noise.dart` içinde private (`_Lcg`)
/// duruyordu; imza sesi (`nocta_signature.dart`) de aynı üretece ihtiyaç duyunca
/// tek seçenek ya kopyalamak ya taşımaktı. Kopya, iki üretecin ileride sessizce
/// AYRIŞMASI demekti — o an her iki golden test de "geçer" ama artık aynı şeyi
/// ölçmezler. Tek kaynak: burası.
class Lcg {
  Lcg(int seed) : _state = (seed & 0x7fffffff) | 1;

  int _state;

  int _next() {
    _state = (_state * 1103515245 + 12345) & 0x7fffffff;
    return _state;
  }

  /// [-1, 1) aralığında uniform örnek.
  double nextBipolar() => (_next() / 0x7fffffff) * 2.0 - 1.0;

  /// [a, b) aralığında uniform örnek.
  double nextRange(double a, double b) => a + (b - a) * ((nextBipolar() + 1) / 2);
}
