import type { Metadata } from 'next';
import { ArchetypesIndexView } from '@/components/ArchetypesIndexView';
import { buildArchetypesMetadata } from '@/lib/page-metadata';

export const metadata: Metadata = buildArchetypesMetadata('tr');

export default function TrArchetypesIndexPage() {
  return <ArchetypesIndexView locale="tr" />;
}
