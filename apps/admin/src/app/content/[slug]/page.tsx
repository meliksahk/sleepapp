import Link from 'next/link';
import { AppShell } from '@/shared/ui/AppShell';
import { apiGet } from '@/shared/api/server-client';
import { LogoutButton } from '@/features/auth/LogoutButton';
import { RecipeForm } from '@/features/content/RecipeForm';
import { MetaForm } from '@/features/content/MetaForm';
import { toFormLayers } from '@/features/content/recipe-form';
import { canWriteContent } from '@/features/content/can-write';
import { statusLabel } from '@/features/content/status-label';
import { translator } from '@/shared/i18n/dictionaries';
import { getLocale } from '@/shared/i18n/locale';
import type { AdminSoundscape } from '@/features/content/types';

interface Detail extends AdminSoundscape {
  recipe: unknown;
}

/** Soundscape düzenleme (docs/03 A1): ses tarifi editörü. */
export default async function SoundscapeDetailPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const locale = await getLocale();
  const t = translator(locale);
  const { slug } = await params;
  // Paralel: ikisi de bağımsız okuma, biri diğerini beklemesin.
  const [detail, me] = await Promise.all([
    apiGet<Detail>(`/v1/admin/soundscapes/${slug}`),
    apiGet<{ roles: string[] }>('/v1/admin/me'),
  ]);
  const canWrite = canWriteContent(me.roles);

  return (
    <AppShell actions={<LogoutButton />}>
      <Link href="/content" className="text-caption text-ink-secondary">
        ← {t('content.backToList')}
      </Link>
      <h2 className="mt-2 text-h2 font-display">{detail.title}</h2>
      <p className="mt-1 mb-6 text-body text-ink-secondary">
        {detail.slug} · {statusLabel(locale, detail.status)}
      </p>

      {canWrite && (
        <section className="mb-8">
          <h3 className="mb-3 text-body font-display">{t('content.metaHeading')}</h3>
          <MetaForm slug={detail.slug} title={detail.title} affinity={detail.archetypeAffinity} />
        </section>
      )}

      <h3 className="mb-3 text-body font-display">{t('content.recipeHeading')}</h3>
      {canWrite ? (
        <RecipeForm slug={detail.slug} initialLayers={toFormLayers(detail.recipe)} />
      ) : (
        <p className="text-body text-ink-secondary">{t('content.recipeNoPermission')}</p>
      )}
    </AppShell>
  );
}
