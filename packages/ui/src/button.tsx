import type { ButtonHTMLAttributes } from 'react';

export type ButtonVariant = 'primary' | 'ghost' | 'danger';

const VARIANTS: Record<ButtonVariant, string> = {
  primary: 'bg-accent-aurora text-bg-base',
  ghost: 'bg-transparent text-ink-primary hover:bg-bg-overlay',
  danger: 'bg-danger text-bg-base',
};

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
}

/** Token'lı temel buton. İş mantığı yok (docs/03 §1.1). */
export function Button({
  variant = 'primary',
  className = '',
  type = 'button',
  ...props
}: ButtonProps) {
  const base =
    'rounded-button px-4 py-2 text-body font-medium transition disabled:opacity-50 disabled:pointer-events-none';
  return <button type={type} className={`${base} ${VARIANTS[variant]} ${className}`} {...props} />;
}
