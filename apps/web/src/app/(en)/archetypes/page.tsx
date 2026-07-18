import type { Metadata } from 'next';
import { ArchetypesIndexView } from '@/components/ArchetypesIndexView';
import { buildArchetypesMetadata } from '@/lib/page-metadata';

export const metadata: Metadata = buildArchetypesMetadata('en');

export default function ArchetypesIndexPage() {
  return <ArchetypesIndexView locale="en" />;
}
