import { StatCard, EmptyState, Button, DataTable, type Column } from '@nocta/ui';
import { AppShell } from '@/shared/ui/AppShell';

interface ActivityRow {
  id: string;
  action: string;
  actor: string;
  when: string;
}
const activityColumns: Column<ActivityRow>[] = [
  { key: 'action', header: 'İşlem' },
  { key: 'actor', header: 'Aktör' },
  { key: 'when', header: 'Zaman' },
];
// Yer tutucu — A3'te audit_log API'sine bağlanacak.
const activityRows: ActivityRow[] = [];

/** Dashboard dikey dilimi (feature-sliced, docs/03). Metrikler A3'te canlı veriye bağlanır. */
export function DashboardPage() {
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

      <section className="mt-8">
        <h3 className="mb-3 text-body font-display">Son etkinlik</h3>
        <DataTable columns={activityColumns} rows={activityRows} emptyTitle="Henüz etkinlik yok" />
      </section>
    </AppShell>
  );
}
