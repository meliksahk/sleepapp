'use client';

import { useActionState, useState } from 'react';
import { Button, Input } from '@nocta/ui';
import { useT } from '@/shared/i18n/I18nProvider';
import { setRecipeAction, type RecipeState } from './actions';
import { MAX_LAYERS, LAYER_SOURCES, type LayerSource, type RecipeLayer } from './recipe-form';

const INITIAL: RecipeState = {};

/**
 * Ses tarifi editörü (docs/03 A1). Katman satırları: {id, tür, kazanç}.
 *
 * Şekil, mobil motorun tükettiği MixSpec ile aynı. "Ham JSON" sekmesi YOK — docs/03
 * onu "advanced" olarak öneriyor ama form yeterli olduğu sürece ham JSON, bozuk tarif
 * üretmenin en kolay yolu olurdu. (Sözleşme büyüyünce yeniden değerlendirilmeli.)
 */
export function RecipeForm({
  slug,
  initialLayers,
}: {
  slug: string;
  initialLayers: RecipeLayer[];
}) {
  const t = useT();
  const [state, action, pending] = useActionState(setRecipeAction, INITIAL);
  const [layers, setLayers] = useState<RecipeLayer[]>(initialLayers);

  const update = (i: number, patch: Partial<RecipeLayer>): void =>
    setLayers((prev) => prev.map((l, idx) => (idx === i ? { ...l, ...patch } : l)));

  const add = (): void =>
    setLayers((prev) =>
      prev.length >= MAX_LAYERS
        ? prev
        : [...prev, { id: `layer-${prev.length + 1}`, type: 'pink', gain: 0.5 }],
    );

  const remove = (i: number): void => setLayers((prev) => prev.filter((_, idx) => idx !== i));

  return (
    <form action={action} className="flex flex-col gap-4">
      <input type="hidden" name="slug" value={slug} />
      {/* Katmanlar JSON olarak: dinamik satırları düz FormData alanlarıyla ifade etmek
          ad çakışması ve sıra hataları üretirdi. */}
      <input type="hidden" name="layers" value={JSON.stringify(layers)} />

      {layers.length === 0 && (
        <p className="text-body text-ink-secondary">{t('content.noLayers')}</p>
      )}

      {layers.map((layer, i) => (
        <div key={i} className="flex flex-wrap items-end gap-3 border-b border-ink-faint/20 pb-3">
          <Input
            label={t('content.layerName')}
            value={layer.id}
            onChange={(e) => update(i, { id: e.target.value })}
          />
          <label className="flex flex-col gap-1">
            <span className="text-caption text-ink-secondary">{t('content.layerType')}</span>
            <select
              value={layer.type}
              onChange={(e) => update(i, { type: e.target.value as LayerSource })}
              className="min-h-11 rounded-chip border border-ink-faint/40 bg-bg-base px-3 text-body text-ink-primary"
            >
              {/* `noise` olarak adlandırıldı: `t` çeviri fonksiyonunu gölgelerdi. */}
              {LAYER_SOURCES.map((noise) => (
                <option key={noise} value={noise}>
                  {noise}
                </option>
              ))}
            </select>
          </label>
          <Input
            label={t('content.layerGain', { gain: layer.gain.toFixed(2) })}
            type="number"
            min="0"
            max="1"
            step="0.05"
            value={String(layer.gain)}
            onChange={(e) => update(i, { gain: Number(e.target.value) })}
          />
          <Button type="button" variant="ghost" onClick={() => remove(i)}>
            {t('content.layerRemove')}
          </Button>
        </div>
      ))}

      <div className="flex gap-3">
        <Button type="button" variant="ghost" onClick={add} disabled={layers.length >= MAX_LAYERS}>
          {t('content.layerAdd')}
        </Button>
        <Button type="submit" disabled={pending || layers.length === 0}>
          {pending ? t('common.saving') : t('content.recipeSubmit')}
        </Button>
      </div>

      {state.error !== undefined && (
        <p role="alert" className="text-body text-accent-ember">
          {t(state.error)}
        </p>
      )}
      {state.saved === true && (
        <p role="status" className="text-body text-accent-aurora">
          {t('content.recipeSaved')}
        </p>
      )}
    </form>
  );
}
