import { DashboardPage } from '@/features/dashboard/DashboardPage';

// app katmanı yalnızca kompozisyon (feature-sliced, docs/03): route → feature dilimi.
export default function Page() {
  return <DashboardPage />;
}
