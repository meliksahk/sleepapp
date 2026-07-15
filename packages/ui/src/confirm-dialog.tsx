import { Button } from './button';

export interface ConfirmDialogProps {
  open: boolean;
  title: string;
  description?: string;
  confirmLabel?: string;
  cancelLabel?: string;
  danger?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

/**
 * Onay diyaloğu — tehlikeli işlemler (yayından kaldırma, silme) her zaman bunu
 * kullanır (docs/03 §1.3). Sunum bileşeni; işi çağıran tarafın.
 */
export function ConfirmDialog({
  open,
  title,
  description,
  confirmLabel = 'Onayla',
  cancelLabel = 'Vazgeç',
  danger = false,
  onConfirm,
  onCancel,
}: ConfirmDialogProps) {
  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-bg-base/70 p-4">
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className="w-full max-w-md rounded-sheet bg-bg-overlay p-6"
      >
        <h2 className="text-h2 font-display text-ink-primary">{title}</h2>
        {description ? <p className="mt-2 text-body text-ink-secondary">{description}</p> : null}
        <div className="mt-6 flex justify-end gap-2">
          <Button variant="ghost" onClick={onCancel}>
            {cancelLabel}
          </Button>
          <Button variant={danger ? 'danger' : 'primary'} onClick={onConfirm}>
            {confirmLabel}
          </Button>
        </div>
      </div>
    </div>
  );
}
