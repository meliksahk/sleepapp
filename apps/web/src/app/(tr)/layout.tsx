import type { Metadata } from 'next';
import '../globals.css';
import { RootShell } from '@/components/RootShell';
import { buildRootMetadata } from '@/lib/page-metadata';

/**
 * TR kök layout — `<html lang="tr">`. `(tr)` grubunun altındaki tek segment `tr/`
 * olduğu için URL'ler `/tr`, `/tr/test`, `/tr/a/{slug}` olur.
 */
export const metadata: Metadata = buildRootMetadata('tr');

export default function TrRootLayout({ children }: { children: React.ReactNode }) {
  return <RootShell locale="tr">{children}</RootShell>;
}
