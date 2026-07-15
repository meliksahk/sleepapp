import { StatCard, EmptyState, Button } from '@nocta/ui';
import { AppShell } from '@/components/AppShell';

export default function DashboardPage() {
  return (
    <AppShell>
      <h2 className="text-h2 font-display">Overview</h2>
      <p className="mt-1 mb-5 text-body text-ink-secondary">
        Metrik panosu A3&apos;te canlı veriye bağlanacak (şimdilik yer tutucu).
      </p>

      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <StatCard label="D7 retention" value="—" hint="A3'te" />
        <StatCard label="Kart paylaşım oranı" value="—" hint="A3'te" />
        <StatCard label="Bekleme listesi" value="—" hint="A2'de" />
        <StatCard label="Deneme→ücretli" value="—" hint="F6'da" />
      </div>

      <section className="mt-8">
        <h3 className="text-body font-display">Soundscapes</h3>
        <div className="mt-3">
          <EmptyState
            title="Henüz içerik yok"
            description="İçerik CMS'i A1'de gelince ilk soundscape burada oluşturulacak."
            action={<Button disabled>Yeni soundscape</Button>}
          />
        </div>
      </section>
    </AppShell>
  );
}
