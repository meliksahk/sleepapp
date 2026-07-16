import Link from 'next/link';
import { StatCard, Button } from '@nocta/ui';
import { AppShell } from '@/shared/ui/AppShell';
import { apiGet } from '@/shared/api/server-client';
import { LogoutButton } from '@/features/auth/LogoutButton';
import { shareRateLabel, shareRateHint } from './share-rate';
import { AuditFeed, type AuditEntry } from './AuditFeed';

interface Overview {
  soundscapes: { draft: number; scheduled: number; published: number };
  waitlist: number;
  shareFunnel: { completed: number; shared: number; rate: number | null };
}

/**
 * Dashboard (docs/03). Rakamlar CANLI — ama yalnızca bugün DOĞRU hesaplanabilenler.
 *
 * D7 retention kohort analizi ister; deneme→ücretli billing'e (F6) bağlı. İkisi için
 * uydurma sayı göstermektense yer tutucu kalıyor: YANLIŞ bir metrik, OLMAYAN bir
 * metrikten daha kötüdür — insan ona güvenip karar verir.
 *
 * "Son etkinlik" #126'da KALDIRILMIŞTI (audit_log yoktu → hiç dolmayacak boş bir söz);
 * #134'te iz gelince GERİ EKLENDİ — bu kez gerçek veriyle.
 */
export async function DashboardPage() {
  // Paralel: iki bağımsız okuma, biri diğerini beklemesin.
  const [o, audit] = await Promise.all([
    apiGet<Overview>('/v1/admin/overview'),
    apiGet<AuditEntry[]>('/v1/admin/audit'),
  ]);
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
        {/* Viral kancanın sağlığı (CLAUDE.md §1.1: "viral kancalar süs değil
            çekirdek özelliktir"). Ürünün bahsi buysa ölçülmeli. */}
        <StatCard
          label="Kart paylaşım oranı"
          value={shareRateLabel(o.shareFunnel.rate)}
          hint={shareRateHint(o.shareFunnel.completed, o.shareFunnel.shared)}
        />
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
        <h3 className="mb-3 text-body font-display">Son etkinlik</h3>
        <AuditFeed entries={audit} />
      </section>

      <section className="mt-8">
        <h3 className="text-body font-display">Henüz ölçülmeyenler</h3>
        <p className="mt-1 text-body text-ink-secondary">
          D7 retention kohort analizi gerektiriyor (A3). Deneme→ücretli ödeme entegrasyonuna bağlı
          (F6).
        </p>
      </section>
    </AppShell>
  );
}
