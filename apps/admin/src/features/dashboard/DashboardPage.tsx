import Link from 'next/link';
import { StatCard, Button } from '@nocta/ui';
import { AppShell } from '@/shared/ui/AppShell';
import { apiGet } from '@/shared/api/server-client';
import { LogoutButton } from '@/features/auth/LogoutButton';

interface Overview {
  soundscapes: { draft: number; scheduled: number; published: number };
  waitlist: number;
}

/**
 * Dashboard (docs/03). Rakamlar CANLI — ama yalnızca bugün DOĞRU hesaplanabilenler.
 *
 * D7 retention kohort analizi ister; deneme→ücretli billing'e (F6) bağlı. İkisi için
 * uydurma sayı göstermektense yer tutucu kalıyor: YANLIŞ bir metrik, OLMAYAN bir
 * metrikten daha kötüdür — insan ona güvenip karar verir.
 *
 * "Son etkinlik" tablosu kaldırıldı: `audit_log` yok, dolayısıyla o tablo hiçbir
 * zaman dolmayacak boş bir söz veriyordu. Geldiğinde eklenir.
 */
export async function DashboardPage() {
  const o = await apiGet<Overview>('/v1/admin/overview');
  const total = o.soundscapes.published + o.soundscapes.draft + o.soundscapes.scheduled;

  return (
    <AppShell actions={<LogoutButton />}>
      <h2 className="text-h2 font-display">Overview</h2>
      <p className="mt-1 mb-5 text-body text-ink-secondary">
        Canlı rakamlar. Henüz ölçülemeyenler aşağıda açıkça belirtilmiştir.
      </p>

      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <StatCard
          label="Yayında"
          value={String(o.soundscapes.published)}
          hint="kullanıcıların gördüğü"
        />
        <StatCard label="Taslak" value={String(o.soundscapes.draft)} hint="yayınlanmamış" />
        <StatCard label="Bekleme listesi" value={String(o.waitlist)} hint="ön-lansman kaydı" />
        {/* Sahte sayı YOK: ölçülemeyeni ölçülüyormuş gibi göstermek, insanın ona
            güvenip yanlış karar vermesi demektir. */}
        <StatCard label="Deneme→ücretli" value="—" hint="ödeme F6'da" />
      </div>

      <section className="mt-8">
        <h3 className="text-body font-display">Soundscapes</h3>
        <p className="mt-1 mb-3 text-body text-ink-secondary">
          {total} kayıt · {o.soundscapes.scheduled} planlı
        </p>
        <Link href="/content">
          <Button>İçeriği yönet</Button>
        </Link>
      </section>

      <section className="mt-8">
        <h3 className="text-body font-display">Henüz ölçülmeyenler</h3>
        <p className="mt-1 text-body text-ink-secondary">
          D7 retention ve kart paylaşım oranı analitik olaylardan hesaplanacak (A3). Deneme→ücretli
          ödeme entegrasyonuna bağlı (F6). Son etkinlik akışı için audit_log gerekiyor.
        </p>
      </section>
    </AppShell>
  );
}
